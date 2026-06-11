import httpx
import asyncio
import re
import os
import json
from bs4 import BeautifulSoup
from typing import List, Dict, Optional

# Legal form regex for extracting company names
_LEGAL_FORMS = r"(?:ООО|ОАО|ЗАО|ПАО|АО|ИП|КФХ|ТД|ГК|НПО|ФГУП|МУП)"
_LEGAL_FORM_RE = re.compile(
    rf"(?:{_LEGAL_FORMS})\s*[«\"\"'']([^»\"\"'']+)[»\"\"'']",
    re.IGNORECASE
)
_LEGAL_FORM_PLAIN_RE = re.compile(
    rf"({_LEGAL_FORMS})\s+([А-ЯЁA-Z][а-яёa-z\-А-ЯA-Z0-9\s]{{1,40}})",
    re.IGNORECASE
)


def _extract_company_name_from_text(text: str) -> Optional[str]:
    """Extract company name from arbitrary text using legal form patterns."""
    if not text:
        return None
    m = _LEGAL_FORM_RE.search(text)
    if m:
        return m.group(0).strip()
    m = _LEGAL_FORM_PLAIN_RE.search(text)
    if m:
        return f"{m.group(1)} {m.group(2).strip()}"
    return None


class DeepParser:
    def __init__(self):
        self.client = httpx.AsyncClient(
            headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"},
            timeout=10.0,
            follow_redirects=True,
            verify=False
        )
        self.rate_limit = 1.0 # sec

    async def parse_supplier_site(self, base_url: str) -> dict:
        """
        Parses a supplier website to extract contact and business details.
        Tries Firecrawl with LLM first if keys are available, falls back to BS4.
        """
        firecrawl_key = os.getenv("FIRECRAWL_API_KEY")
        deepseek_key = os.getenv("DEEPSEEK_API_KEY")
        
        if firecrawl_key and firecrawl_key != "your_firecrawl_key_here":
            firecrawl_data = await self.parse_with_firecrawl(base_url, firecrawl_key)
            if firecrawl_data and firecrawl_data.get("markdown"):
                markdown = firecrawl_data["markdown"]
                
                # If LLM key is available, extract via LLM
                if deepseek_key and deepseek_key != "your_deepseek_key_here":
                    llm_data = await self.extract_contacts_via_llm(markdown, deepseek_key)
                    if llm_data:
                        emails = llm_data.get("emails", [])
                        return {
                            "company_name": llm_data.get("company_name") or _extract_company_name_from_text(markdown),
                            "inn": llm_data.get("inn"),
                            "phones": llm_data.get("phones", []),
                            "emails": emails,
                            "personal_email": self._is_personal_email(emails),
                            "has_pickup": llm_data.get("has_pickup", False),
                            "has_delivery": llm_data.get("has_delivery", False),
                            "has_certificate": llm_data.get("has_certificate", False),
                            "cert_types": llm_data.get("cert_types", []),
                            "is_manufacturer": llm_data.get("is_manufacturer", False),
                            "payment_delay_days": llm_data.get("payment_delay_days", 0),
                            "min_order_kg": llm_data.get("min_order_kg"),
                            "min_order_rub": llm_data.get("min_order_rub"),
                            "price_list_urls": llm_data.get("price_list_urls", [])
                        }
                
                # Fallback: parse markdown using regex
                result = self._parse_text_via_regex(markdown, base_url)
                result["company_name"] = _extract_company_name_from_text(markdown)
                return result
                
        # Default fallback
        return await self._parse_via_bs4(base_url)

    async def parse_with_firecrawl(self, url: str, api_key: str) -> Optional[dict]:
        scrape_url = "https://api.firecrawl.dev/v1/scrape"
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }
        json_data = {
            "url": url,
            "formats": ["markdown"]
        }
        try:
            response = await self.client.post(scrape_url, json=json_data, headers=headers, timeout=20.0)
            if response.status_code == 200:
                res_json = response.json()
                if res_json.get("success"):
                    return res_json.get("data")
        except Exception as e:
            print(f"Firecrawl parsing error for {url}: {e}")
        return None

    async def extract_contacts_via_llm(self, text: str, api_key: str) -> Optional[dict]:
        url = "https://api.deepseek.com/v1/chat/completions"
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }
        prompt = f"""
Извлеки контактную информацию поставщика HoReCa из следующего текста страницы (формат Markdown).
Верни строго валидный JSON с ключами:
- inn (строка, 10 или 12 цифр, или null)
- ogrn (строка, 13 или 15 цифр, или null)
- phones (список строк, телефоны в формате +7...)
- emails (список строк, email адреса)
- address (строка, почтовый/фактический адрес, или null)
- has_certificate (boolean, есть ли упоминания сертификатов качества, ГОСТ, Халяль, ISO)
- cert_types (список строк, типы найденных сертификатов, например ["ГОСТ", "Халяль"])
- is_manufacturer (boolean, собственное производство/завод/фабрика)
- has_delivery (boolean, есть ли доставка)
- has_pickup (boolean, есть ли самовывоз)
- payment_delay_days (число дней отсрочки платежа, если упоминается, иначе 0)
- min_order_kg (минимальный заказ в кг, если упоминается, иначе null)
- min_order_rub (минимальная сумма заказа в рублях, если упоминается, иначе null)
- price_list_urls (список ссылок на прайс-листы или файлы .pdf/.xlsx)

Текст страницы:
\"\"\"{text[:6000]}\"\"\"
"""
        json_data = {
            "model": "deepseek-chat",
            "messages": [
                {"role": "user", "content": prompt}
            ],
            "response_format": {"type": "json_object"},
            "temperature": 0.1
        }
        try:
            response = await self.client.post(url, json=json_data, headers=headers, timeout=20.0)
            if response.status_code == 200:
                res = response.json()
                content = res["choices"][0]["message"]["content"]
                return json.loads(content)
        except Exception as e:
            print(f"LLM extraction error: {e}")
        return None

    def _parse_text_via_regex(self, text: str, base_url: str) -> dict:
        parsed_data = {
            "phones": set(),
            "emails": set(),
            "personal_email": False,
            "inn": None,
            "payment_delay_days": 0,
            "min_order_kg": None,
            "min_order_rub": None,
            "has_pickup": False,
            "has_delivery": False,
            "has_certificate": False,
            "cert_types": set(),
            "is_manufacturer": False,
            "price_list_urls": set()
        }

        text_lower = text.lower()

        # Phones
        phone_pattern = r"(?:\+7|8)[\s\-]?\(?\d{3}\)?[\s\-]?\d{3}[\s\-]?\d{2}[\s\-]?\d{2}"
        for match in re.findall(phone_pattern, text):
            clean_phone = re.sub(r"[^\d+]", "", match)
            if clean_phone.startswith('8'): 
                clean_phone = '+7' + clean_phone[1:]
            parsed_data["phones"].add(clean_phone)

        # Emails
        email_pattern = r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"
        for email in re.findall(email_pattern, text):
            email = email.lower()
            if any(email.endswith(ext) for ext in ['.png', '.jpg', '.jpeg', '.gif', '.css', '.js']):
                continue
            parsed_data["emails"].add(email)

        # INN
        inn_match = re.search(r"(?i)(?:инн|inn)[\s:]*(\d{10}|\d{12})\b", text)
        if not inn_match:
            inn_match = re.search(r"\b(\d{10}|\d{12})\b", text)
        if inn_match:
            parsed_data["inn"] = inn_match.group(1)

        # Markers
        delay_match = re.search(r"отсрочк[а-я]*\s+(\d+)\s+дн", text_lower)
        if delay_match: 
            parsed_data["payment_delay_days"] = int(delay_match.group(1))
        
        min_kg_match = re.search(r"от\s+(\d+)\s+кг", text_lower)
        if min_kg_match: 
            parsed_data["min_order_kg"] = float(min_kg_match.group(1))
        
        min_rub_match = re.search(r"от\s+(\d+)\s+руб", text_lower)
        if min_rub_match: 
            parsed_data["min_order_rub"] = float(min_rub_match.group(1))
        
        if "самовывоз" in text_lower: 
            parsed_data["has_pickup"] = True
        if "доставка" in text_lower: 
            parsed_data["has_delivery"] = True
        if "сертификат" in text_lower: 
            parsed_data["has_certificate"] = True
        if "гост" in text_lower: 
            parsed_data["cert_types"].add("ГОСТ")
        if "iso" in text_lower: 
            parsed_data["cert_types"].add("ISO")
        if "халяль" in text_lower: 
            parsed_data["cert_types"].add("Халяль")
        if "собственное производств" in text_lower: 
            parsed_data["is_manufacturer"] = True

        # Find potential price links in Markdown e.g. [Link](url)
        price_links = re.findall(r"\[.*?\]\((.*?)\)", text)
        for link in price_links:
            link_lower = link.lower()
            if "price" in link_lower or "прайс" in link_lower or link_lower.endswith(".pdf") or link_lower.endswith(".xlsx"):
                full_link = link
                if not full_link.startswith('http'):
                    full_link = f"{base_url.rstrip('/')}/{full_link.lstrip('/')}"
                parsed_data["price_list_urls"].add(full_link)

        final_emails = list(parsed_data["emails"])
        return {
            "inn": parsed_data["inn"],
            "phones": list(parsed_data["phones"]),
            "emails": final_emails,
            "personal_email": self._is_personal_email(final_emails),
            "has_pickup": parsed_data["has_pickup"],
            "has_delivery": parsed_data["has_delivery"],
            "has_certificate": parsed_data["has_certificate"],
            "cert_types": list(parsed_data["cert_types"]),
            "is_manufacturer": parsed_data["is_manufacturer"],
            "payment_delay_days": parsed_data["payment_delay_days"],
            "min_order_kg": parsed_data["min_order_kg"],
            "min_order_rub": parsed_data["min_order_rub"],
            "price_list_urls": list(parsed_data["price_list_urls"])
        }

    async def _parse_via_bs4(self, base_url: str) -> dict:
        PAGES_TO_CHECK = [
            "", "/contacts", "/contact", "/о-компании", "/about",
            "/dostavka", "/delivery", "/oplata", "/payment",
            "/price", "/prays", "/optovikam", "/wholesale"
        ]
        
        parsed_data = {
            "phones": set(),
            "emails": set(),
            "personal_email": False,
            "inn": None,
            "company_name": None,
            "payment_delay_days": 0,
            "min_order_kg": None,
            "min_order_rub": None,
            "has_pickup": False,
            "has_delivery": False,
            "has_certificate": False,
            "cert_types": set(),
            "is_manufacturer": False,
            "is_order_based": False,
            "price_list_urls": set()
        }

        base_url = base_url.rstrip('/')

        for page in PAGES_TO_CHECK:
            url = f"{base_url}{page}"
            try:
                await asyncio.sleep(self.rate_limit)
                response = await self.client.get(url)
                if response.status_code != 200:
                    continue

                soup = BeautifulSoup(response.text, 'html.parser')
                text = soup.get_text(separator=' ', strip=True)
                
                # 0. Company name extraction (from first page or /about)
                if not parsed_data["company_name"]:
                    # Try og:site_name meta tag
                    og_name = soup.find("meta", property="og:site_name")
                    if og_name and og_name.get("content"):
                        cn = og_name["content"].strip()
                        if len(cn) > 2:
                            parsed_data["company_name"] = cn

                    # Try HTML <title>
                    if not parsed_data["company_name"] and soup.title and soup.title.string:
                        title_text = soup.title.string.strip()
                        extracted = _extract_company_name_from_text(title_text)
                        if extracted:
                            parsed_data["company_name"] = extracted

                    # Try body text for legal forms
                    if not parsed_data["company_name"]:
                        extracted = _extract_company_name_from_text(text[:3000])
                        if extracted:
                            parsed_data["company_name"] = extracted

                # 1. Phones
                phone_pattern = r"(?:\+7|8)[\s\-]?\(?\d{3}\)?[\s\-]?\d{3}[\s\-]?\d{2}[\s\-]?\d{2}"
                for match in re.findall(phone_pattern, text):
                    clean_phone = re.sub(r"[^\d+]", "", match)
                    if clean_phone.startswith('8'): 
                        clean_phone = '+7' + clean_phone[1:]
                    parsed_data["phones"].add(clean_phone)

                # 2. Emails
                email_pattern = r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"
                for email in re.findall(email_pattern, text):
                    email = email.lower()
                    if any(email.endswith(ext) for ext in ['.png', '.jpg', '.jpeg', '.gif', '.css', '.js']):
                        continue
                    parsed_data["emails"].add(email)

                # 3. INN
                if not parsed_data["inn"]:
                    inn_match = re.search(r"(?i)(?:инн|inn)[\s:]*(\d{10}|\d{12})\b", text)
                    if not inn_match:
                        inn_match = re.search(r"\b(\d{10}|\d{12})\b", text)
                    if inn_match:
                        parsed_data["inn"] = inn_match.group(1)

                # 4. Markers
                text_lower = text.lower()
                
                delay_match = re.search(r"отсрочк[а-я]*\s+(\d+)\s+дн", text_lower)
                if delay_match: 
                    parsed_data["payment_delay_days"] = int(delay_match.group(1))
                
                min_kg_match = re.search(r"от\s+(\d+)\s+кг", text_lower)
                if min_kg_match: 
                    parsed_data["min_order_kg"] = float(min_kg_match.group(1))
                
                min_rub_match = re.search(r"от\s+(\d+)\s+руб", text_lower)
                if min_rub_match: 
                    parsed_data["min_order_rub"] = float(min_rub_match.group(1))
                
                if "самовывоз" in text_lower: 
                    parsed_data["has_pickup"] = True
                if "доставка" in text_lower: 
                    parsed_data["has_delivery"] = True
                if "сертификат" in text_lower: 
                    parsed_data["has_certificate"] = True
                if "гост" in text_lower: 
                    parsed_data["cert_types"].add("ГОСТ")
                if "iso" in text_lower: 
                    parsed_data["cert_types"].add("ISO")
                if "халяль" in text_lower: 
                    parsed_data["cert_types"].add("Халяль")
                if "собственное производств" in text_lower: 
                    parsed_data["is_manufacturer"] = True

                # 5. Price lists
                for a in soup.find_all('a', href=True):
                    href = a['href'].lower()
                    if "price" in href or "прайс" in href or href.endswith(".pdf") or href.endswith(".xlsx"):
                        full_link = a['href']
                        if not full_link.startswith('http'):
                            full_link = f"{base_url}/{full_link.lstrip('/')}"
                        parsed_data["price_list_urls"].add(full_link)

            except Exception:
                continue

        final_emails = list(parsed_data["emails"])
        return {
            "company_name": parsed_data["company_name"],
            "inn": parsed_data["inn"],
            "phones": list(parsed_data["phones"]),
            "emails": final_emails,
            "personal_email": self._is_personal_email(final_emails),
            "has_pickup": parsed_data["has_pickup"],
            "has_delivery": parsed_data["has_delivery"],
            "has_certificate": parsed_data["has_certificate"],
            "cert_types": list(parsed_data["cert_types"]),
            "is_manufacturer": parsed_data["is_manufacturer"],
            "payment_delay_days": parsed_data["payment_delay_days"],
            "min_order_kg": parsed_data["min_order_kg"],
            "min_order_rub": parsed_data["min_order_rub"],
            "price_list_urls": list(parsed_data["price_list_urls"])
        }

    def _is_personal_email(self, emails: List[str]) -> bool:
        if len(emails) == 1:
            if any(ext in emails[0] for ext in ['@mail.ru', '@yandex.ru', '@gmail.com', '@bk.ru', '@inbox.ru']):
                return True
        return False

    async def close(self):
        await self.client.aclose()
