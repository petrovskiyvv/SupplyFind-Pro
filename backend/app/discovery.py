import asyncio
import re
import random
from sqlalchemy.orm import Session
from . import models
from .config import settings
from .services.deep_parser import DeepParser
from .services.verifier import verify_by_inn
from .services.scoring import calculate_score
from tavily import TavilyClient

CATEGORY_PROMPTS = {
  "Dairy": "молокозавод поставщик молочной продукции оптом {city} сыр масло молоко официальный сайт прайс ИНН -инстаграм -вконтакте",
  "Vegetables": "овощная база фермерское хозяйство поставщик овощей {city} оптовые поставки прямые контакты склад -агрегатор -каталог",
  "Meat": "мясокомбинат птицефабрика поставщик мяса оптом {city} говядина свинина курица сертификат ветсвидетельство -авито -hh",
  "Bakery": "хлебозавод пекарня поставщик хлебобулочных изделий оптом {city} официальный сайт прайс доставка юрлицо"
}

BLACKLIST_DOMAINS = [
  "kontur.ru", "rusprofile.ru", "egrul.ru", "2gis.ru",
  "avito.ru", "hh.ru", "superjob.ru", "yandex.ru",
  "ozon.ru", "wildberries.ru", "zoon.ru", "flamp.ru",
  "list.ru", "spravker.ru", "orgpage.ru", "cataloxy.ru",
  "instagram.com", "vk.com", "facebook.com", "t.me",
  "ok.ru", "tiktok.com", "youtube.com", "linkedin.com",
  "rosstat.gov.ru", "nalog.gov.ru", "zachestnyibiznes.ru"
]

class DiscoveryService:
    def __init__(self, db: Session):
        self.db = db
        self.tavily_client = TavilyClient(api_key=settings.TAVILY_API_KEY)
        self.deep_parser = DeepParser()
        
    async def discover_suppliers(self, category: str, city: str):
        prompt_template = CATEGORY_PROMPTS.get(category, f"{category} поставщик оптовый официальный сайт {city} -агрегатор -каталог -отзывы прайс доставка")
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

            supplier_data = {
                "name": legal_info.get("legal_name") or self._clean_company_name(res.get('title')),
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
                (models.Supplier.website == url) | (models.Supplier.inn == supplier_data["inn"] if supplier_data["inn"] else False)
            ).first()
            
            if not existing:
                supplier = models.Supplier(**supplier_data)
                self.db.add(supplier)
                new_suppliers.append(supplier)
        
        self.db.commit()
        for s in new_suppliers:
            self.db.refresh(s)
            
        return new_suppliers

    async def _get_scored_results(self, query: str, category: str, city: str):
        search_results = self.tavily_client.search(query=query, search_depth="advanced", max_results=15)
        results_list = search_results.get('results', [])
        
        scored_results = []
        for res in results_list:
            url = res.get('url', '').lower()
            
            if any(domain in url for domain in BLACKLIST_DOMAINS):
                continue
            
            score = 0
            commercial_keywords = ['opt', 'zakup', 'torg', 'food', 'snab', 'agro']
            if any(kw in url for kw in commercial_keywords):
                score += 2
            
            if len(url.replace('https://', '').replace('http://', '').split('/')[0]) < 10:
                score -= 2

            if score >= 0:
                res['score'] = score
                scored_results.append(res)
                
        return scored_results

    def _clean_company_name(self, raw_name: str) -> str:
        if not raw_name: return "Неизвестный поставщик"
        junk = [
            r"официальный сайт", r"купить оптом", r"цена", r"инн", 
            r"каталог", r"поставщик", r"производитель", r"москва", r"спб", r"рф"
        ]
        name = raw_name.lower()
        for pattern in junk:
            name = re.sub(pattern, "", name)
        
        name = re.sub(r"[^a-zA-Zа-яА-Я0-9\s\"«»]", " ", name)
        name = " ".join(name.split())
        return name.strip().title()
