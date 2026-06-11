import asyncio
import re
import random
from urllib.parse import urlparse
from sqlalchemy.orm import Session
from . import models
from .config import settings
from .services.deep_parser import DeepParser
from .services.verifier import verify_by_inn
from .services.scoring import calculate_score
from tavily import TavilyClient
import logging

logger = logging.getLogger(__name__)

CATEGORY_PROMPTS = {
    "Dairy": "молокозавод поставщик молочной продукции оптом {city} сыр масло молоко официальный сайт прайс ИНН",
    "Vegetables": "овощная база фермерское хозяйство поставщик овощей {city} оптовые поставки прямые контакты склад",
    "Meat": "мясокомбинат птицефабрика поставщик мяса оптом {city} говядина свинина курица сертификат ветсвидетельство",
    "Bakery": "хлебозавод пекарня поставщик хлебобулочных изделий оптом {city} официальный сайт прайс доставка юрлицо"
}

# ── Blacklists ─────────────────────────────────────────────────────────

# Domains to completely reject — these are never suppliers
BLACKLIST_DOMAINS = [
    # Business registries & analytics
    "kontur.ru", "rusprofile.ru", "egrul.ru", "zachestnyibiznes.ru",
    "kontragent.vbr.ru", "list-org.com", "audit-it.ru", "sbis.ru",
    "checko.ru", "kartoteka.ru", "orgpage.ru", "companium.ru",
    # Job boards
    "hh.ru", "superjob.ru", "rabota.ru", "trudvsem.ru",
    # Classifieds & marketplaces
    "avito.ru", "ozon.ru", "wildberries.ru", "yandex.ru", "sbermarket.ru",
    # Maps & reviews
    "2gis.ru", "zoon.ru", "flamp.ru", "spravker.ru", "yell.ru",
    "tripadvisor.ru", "otzovik.com", "irecommend.ru",
    # Social media
    "instagram.com", "vk.com", "facebook.com", "t.me",
    "ok.ru", "tiktok.com", "youtube.com", "linkedin.com",
    # Government
    "rosstat.gov.ru", "nalog.gov.ru", "fns.gov.ru",
    # Generic catalogs / meta-aggregators
    "cataloxy.ru", "satu.kz", "tiu.ru", "pulscen.ru", "all.biz",
    "regforum.ru", "b2b-center.ru",
    # Technical / file-only
    "vniims.info",
]

# Domains that are B2B aggregators — they list multiple suppliers, not a single one
AGGREGATOR_DOMAINS = [
    "optsbyt.ru", "foodsuppliers.ru", "foodcity.ru", "supl.biz",
    "productcenter.ru", "optomarket.su", "agro24.ru", "b2btrade.ru",
    "optom.one", "zakupki.gov.ru", "flagma.ru", "optlist.ru",
    "wholesaler.ru", "postavshhiki.ru", "postavki.com",
    "opttorg-horeca.ru", "dostavka-produktov.com", "alligator.market",
    "seldon.ru", "expocentr.ru", "agroserver.ru", "edaopt.ru",
]

# URL path patterns that indicate aggregator catalogue pages
AGGREGATOR_PATH_PATTERNS = [
    r"/companies/", r"/catalog(?:ue)?/", r"/byers/", r"/sellers/",
    r"/postawschiki/", r"/vendors/", r"/rating/", r"\?page=",
    r"/search\b", r"/category/", r"/rubric/",
]

# ── Company name extraction helpers ────────────────────────────────────

# Legal form prefixes/suffixes (Russian)
_LEGAL_FORMS = r"(?:ООО|ОАО|ЗАО|ПАО|АО|ИП|КФХ|ТД|ГК|НПО|ФГУП|МУП)"
_LEGAL_FORM_RE = re.compile(
    rf"(?:{_LEGAL_FORMS})\s*[«\"\"'']([^»\"\"'']+)[»\"\"'']",
    re.IGNORECASE
)
_LEGAL_FORM_PLAIN_RE = re.compile(
    rf"({_LEGAL_FORMS})\s+([А-ЯЁA-Z][а-яёa-z\-А-ЯA-Z0-9\s]{{1,40}})",
    re.IGNORECASE
)

# Junk words to strip from title-derived names
_JUNK_WORDS = [
    r"официальный сайт", r"купить оптом", r"цены?", r"инн", r"каталог",
    r"поставщик\w*", r"производител\w*", r"москв\w*", r"спб\w*",
    r"санкт[- ]петербург\w*", r"россия", r"рф", r"pdf", r"доставк\w*",
    r"оптов\w*", r"страниц\w*\s*\d*", r"от\s+компании", r"адрес",
    r"реквизит\w*", r"полное\s+название", r"код\w*\s+статистик\w*",
    r"напрямую", r"дистрибь\w+", r"продукци\w*", r"молочн\w*",
    r"молоко", r"мяс\w*", r"овощ\w*", r"хлеб\w*", r"свежесть",
    r"качеств\w*", r"центр\w*", r"фуд\s*сити", r"\d+\s*ов\b",
]


def _is_blacklisted(url: str) -> bool:
    """Check if URL belongs to a blacklisted domain."""
    domain = urlparse(url).hostname or ""
    domain = domain.lstrip("www.")
    return any(bl in domain for bl in BLACKLIST_DOMAINS)


def _is_aggregator(url: str) -> bool:
    """Detect aggregator sites by domain or URL path patterns."""
    parsed = urlparse(url)
    domain = (parsed.hostname or "").lstrip("www.")

    if any(ag in domain for ag in AGGREGATOR_DOMAINS):
        return True

    path = parsed.path + ("?" + parsed.query if parsed.query else "")
    for pattern in AGGREGATOR_PATH_PATTERNS:
        if re.search(pattern, path, re.IGNORECASE):
            return True

    return False


def _extract_company_from_title(title: str) -> str | None:
    """Try to extract a real company name from Tavily title using legal form patterns."""
    if not title:
        return None

    # Pattern 1: ООО «Название» or ООО "Название"
    m = _LEGAL_FORM_RE.search(title)
    if m:
        return m.group(0).strip()

    # Pattern 2: ООО Название (without quotes)
    m = _LEGAL_FORM_PLAIN_RE.search(title)
    if m:
        return f"{m.group(1)} {m.group(2).strip()}"

    return None


def _extract_company_from_domain(url: str) -> str:
    """Derive a readable company name from the domain."""
    parsed = urlparse(url)
    domain = (parsed.hostname or "").lstrip("www.")
    name = domain.split(".")[0]
    # Capitalize and clean
    name = re.sub(r"[-_]", " ", name)
    return name.strip().title()


def _clean_company_name(raw_name: str | None) -> str:
    """Deep-clean a raw search title into something resembling a company name."""
    if not raw_name:
        return "Неизвестный поставщик"

    # First, try to find a legal form in the title
    extracted = _extract_company_from_title(raw_name)
    if extracted:
        return extracted.strip()

    # Otherwise, strip junk words
    name = raw_name
    for junk in _JUNK_WORDS:
        name = re.sub(junk, "", name, flags=re.IGNORECASE)

    # Clean up punctuation, multiple spaces
    name = re.sub(r"[^a-zA-Zа-яА-ЯёЁ0-9\s\-«»\"'\.]", " ", name)
    name = re.sub(r"\s{2,}", " ", name).strip()

    # If nothing meaningful remains (< 3 chars), return None
    if len(name) < 3:
        return None

    return name.strip().title()


# ── Discovery Service ──────────────────────────────────────────────────

class DiscoveryService:
    def __init__(self, db: Session):
        self.db = db
        self.tavily_client = TavilyClient(api_key=settings.TAVILY_API_KEY)
        self.deep_parser = DeepParser()

    async def discover_suppliers(self, category: str, city: str):
        prompt_template = CATEGORY_PROMPTS.get(
            category,
            f"{category} поставщик оптовый официальный сайт {{city}} прайс доставка"
        )
        query1 = prompt_template.replace("{city}", city)
        results = await self._get_scored_results(query1, category, city)

        if len(results) < 3:
            query2 = f"завод производитель {category} {city} оптом контакты прайс"
            results2 = await self._get_scored_results(query2, category, city)
            existing_urls = {r['url'] for r in results}
            for r in results2:
                if r['url'] not in existing_urls:
                    results.append(r)

        new_suppliers = []
        for res in results[:10]:
            url = res.get('url')

            # Deep Parsing
            contacts = await self.deep_parser.parse_supplier_site(url)

            # Verification
            legal_info = {}
            if contacts.get("inn"):
                v_res = await verify_by_inn(contacts["inn"])
                if v_res:
                    legal_info = {
                        "legal_name": v_res.full_name,
                        "status": v_res.status,
                        "ogrn": v_res.ogrn,
                        "legal_address": v_res.address,
                        "director_name": v_res.director_name,
                        "reg_date": v_res.reg_date,
                        "is_verified": v_res.status == "Действующее",
                        "is_risky": v_res.is_risky,
                        "risk_reasons": v_res.risk_reasons
                    }

            if legal_info.get("status") == "Ликвидировано":
                continue

            # ── Name resolution priority ──────────────────────────────
            # 1. Legal name from ФНС verification (most reliable)
            # 2. Company name extracted from HTML <title> / <meta> of site
            # 3. Company name found in Tavily title (legal form pattern)
            # 4. Name derived from domain
            # 5. Cleaned Tavily title (last resort)
            supplier_name = (
                legal_info.get("legal_name")
                or contacts.get("company_name")
                or _extract_company_from_title(res.get("title"))
                or _extract_company_from_domain(url)
            )
            # Final cleanup
            if not supplier_name or len(supplier_name) < 3:
                supplier_name = _clean_company_name(res.get("title"))
            if not supplier_name or len(supplier_name) < 3:
                supplier_name = _extract_company_from_domain(url)

            supplier_data = {
                "name": supplier_name,
                "description": res.get('content', '')[:500],
                "website": url,
                "contact_email": ", ".join(contacts.get("emails", [])) if contacts.get("emails") else "",
                "contact_phone": ", ".join(contacts.get("phones", [])) if contacts.get("phones") else "",
                "category": category,
                "city": city,
                "inn": contacts.get("inn"),
                "ogrn": legal_info.get("ogrn"),
                "legal_address": legal_info.get("legal_address") or contacts.get("address"),
                "is_verified": legal_info.get("is_verified", False),
                "is_risky": legal_info.get("is_risky", False),
                "risk_reasons": legal_info.get("risk_reasons", []),
                "director_name": legal_info.get("director_name"),
                "reg_date": legal_info.get("reg_date"),
                "phones": contacts.get("phones", []),
                "emails": contacts.get("emails", []),
                "personal_email": contacts.get("personal_email", False),
                "has_certificate": contacts.get("has_certificate", False),
                "cert_types": contacts.get("cert_types", []),
                "is_manufacturer": contacts.get("is_manufacturer", False),
                "has_delivery": contacts.get("has_delivery", False),
                "has_pickup": contacts.get("has_pickup", False),
                "payment_delay_days": contacts.get("payment_delay_days", 0),
                "min_order_kg": contacts.get("min_order_kg"),
                "min_order_rub": contacts.get("min_order_rub"),
                "price_list_urls": contacts.get("price_list_urls", []),
                "legal_status": legal_info.get("status", "Неизвестно"),
                "source_type": "tavily"
            }

            # Score calculation
            score, explanation = calculate_score(supplier_data)
            supplier_data["score"] = score
            supplier_data["score_explanation"] = explanation

            existing = self.db.query(models.Supplier).filter(
                (models.Supplier.website == url)
                | (
                    models.Supplier.inn == supplier_data["inn"]
                    if supplier_data["inn"]
                    else False
                )
            ).first()

            if not existing:
                supplier = models.Supplier(**supplier_data)
                self.db.add(supplier)
                new_suppliers.append(supplier)
            else:
                logger.info(f"Skipping duplicate: {url}")

        self.db.commit()
        for s in new_suppliers:
            self.db.refresh(s)

        return new_suppliers

    async def _get_scored_results(self, query: str, category: str, city: str):
        search_results = self.tavily_client.search(
            query=query, search_depth="advanced", max_results=20
        )
        results_list = search_results.get('results', [])

        scored_results = []
        for res in results_list:
            url = res.get('url', '')
            url_lower = url.lower()

            # ── Filter 1: Hard blacklist ──
            if _is_blacklisted(url_lower):
                logger.debug(f"Blacklisted: {url}")
                continue

            # ── Filter 2: Aggregator detection ──
            if _is_aggregator(url_lower):
                logger.debug(f"Aggregator rejected: {url}")
                continue

            # ── Scoring ──
            score = 0
            # Positive: commercial keywords in domain
            commercial_keywords = ['opt', 'zakup', 'torg', 'food', 'snab', 'agro',
                                   'moloko', 'myaso', 'ferma', 'zavod', 'fabrik',
                                   'kombina']
            if any(kw in url_lower for kw in commercial_keywords):
                score += 3

            # Positive: title contains legal form (ООО, АО, etc.)
            title = res.get('title', '')
            if re.search(rf"\b{_LEGAL_FORMS}\b", title, re.IGNORECASE):
                score += 4

            # Positive: short clean domain (likely own company site)
            domain = urlparse(url).hostname or ""
            domain_name = domain.lstrip("www.").split(".")[0]
            if 4 <= len(domain_name) <= 20:
                score += 1

            # Negative: very short domain (likely generic)
            if len(domain_name) < 4:
                score -= 2

            # Negative: content mentions "каталог компаний", "рейтинг поставщиков"
            content = res.get('content', '').lower()
            aggregator_phrases = [
                "каталог компаний", "рейтинг поставщиков", "все поставщики",
                "список компаний", "найти поставщика", "база поставщиков",
                "отзывы о компании", "добавить компанию",
            ]
            if any(ph in content for ph in aggregator_phrases):
                score -= 5

            if score >= 0:
                res['_score'] = score
                scored_results.append(res)

        # Sort by score descending
        scored_results.sort(key=lambda x: x.get('_score', 0), reverse=True)
        return scored_results
