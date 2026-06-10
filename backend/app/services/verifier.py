import httpx
import os
from dataclasses import dataclass
from datetime import datetime, date
from typing import Optional, List

@dataclass
class VerificationResult:
    inn: str
    full_name: str
    short_name: str
    status: str          # "Действующее" / "Ликвидировано" / "В процессе ликвидации"
    reg_date: date
    address: str
    director_name: str
    ogrn: str
    is_risky: bool       # True если моложе 1 года или ликвидируется
    risk_reasons: List[str]

async def verify_by_inn(inn: str) -> Optional[VerificationResult]:
    """
    Verifies a company by INN. Tries DaData API first if credentials are set,
    otherwise falls back to the FNS API.
    """
    dadata_key = os.getenv("DADATA_API_KEY")
    if dadata_key and dadata_key != "your_dadata_key_here":
        res = await verify_by_dadata(inn, dadata_key)
        if res:
            return res
            
    return await verify_by_fns_api(inn)

async def verify_by_dadata(inn: str, api_key: str) -> Optional[VerificationResult]:
    url = "https://suggestions.dadata.ru/suggestions/api/4_1/rs/findById/party"
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": f"Token {api_key}"
    }
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.post(
                url,
                json={"query": inn},
                headers=headers
            )
            if response.status_code != 200:
                return None
            
            data = response.json()
            suggestions = data.get("suggestions", [])
            if not suggestions:
                return None
                
            party = suggestions[0].get("data", {})
            if not party:
                return None
                
            full_name = party.get("name", {}).get("full_with_opf", "") or party.get("name", {}).get("full", "")
            short_name = party.get("name", {}).get("short_with_opf", "") or party.get("name", {}).get("short", "")
            
            dadata_status = party.get("state", {}).get("status", "")
            status_map = {
                "ACTIVE": "Действующее",
                "LIQUIDATING": "В процессе ликвидации",
                "LIQUIDATED": "Ликвидировано",
                "REORGANIZING": "В процессе реорганизации"
            }
            status = status_map.get(dadata_status, "Действующее")
            
            # Registration date (milliseconds timestamp)
            reg_date_ts = party.get("state", {}).get("registration_date")
            reg_date_obj = date.today()
            if reg_date_ts:
                try:
                    reg_date_obj = datetime.fromtimestamp(reg_date_ts / 1000.0).date()
                except:
                    pass
                    
            address = party.get("address", {}).get("value", "")
            director_name = party.get("management", {}).get("name", "")
            ogrn = party.get("ogrn", "")
            
            # Risk assessment
            is_risky = False
            risk_reasons = []
            
            if status != "Действующее":
                is_risky = True
                risk_reasons.append(f"Статус компании: {status}")
                
            days_active = (date.today() - reg_date_obj).days
            if days_active < 365:
                is_risky = True
                risk_reasons.append("Компания зарегистрирована менее года назад")
                
            return VerificationResult(
                inn=inn,
                full_name=full_name,
                short_name=short_name,
                status=status,
                reg_date=reg_date_obj,
                address=address,
                director_name=director_name,
                ogrn=ogrn,
                is_risky=is_risky,
                risk_reasons=risk_reasons
            )
    except Exception as e:
        print(f"DaData verification error: {e}")
        return None

async def verify_by_fns_api(inn: str) -> Optional[VerificationResult]:
    url = f"https://api-fns.ru/api/egr?req={inn}&key=demo"
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.get(url)
            if response.status_code != 200:
                return None
            data = response.json()
            
            if not data or "items" not in data or len(data["items"]) == 0:
                return None
                
            item = data["items"][0]
            ul = item.get("ЮЛ", {})
            if not ul:
                return None
                
            full_name = ul.get("НаимПолнЮЛ", "")
            short_name = ul.get("НаимСокрЮЛ", "")
            status = ul.get("Статус", "Действующее")
            
            reg_date_str = ul.get("ДатаОГРН") or ul.get("ДатаРег")
            reg_date_obj = date.today()
            if reg_date_str:
                try:
                    reg_date_obj = datetime.strptime(reg_date_str, "%Y-%m-%d").date()
                except:
                    pass
                    
            address = ul.get("Адрес", {}).get("АдресПолн", "")
            
            director_name = ""
            ruk = ul.get("Руководитель", {})
            if ruk:
                director_name = f"{ruk.get('Фамилия', '')} {ruk.get('Имя', '')} {ruk.get('Отчество', '')}".strip()
                
            ogrn = ul.get("ОГРН", "")

            # Risk assessment
            is_risky = False
            risk_reasons = []
            
            if status != "Действующее":
                is_risky = True
                risk_reasons.append(f"Статус компании: {status}")
                
            days_active = (date.today() - reg_date_obj).days
            if days_active < 365:
                is_risky = True
                risk_reasons.append("Компания зарегистрирована менее года назад")
                
            return VerificationResult(
                inn=inn,
                full_name=full_name,
                short_name=short_name,
                status=status,
                reg_date=reg_date_obj,
                address=address,
                director_name=director_name,
                ogrn=ogrn,
                is_risky=is_risky,
                risk_reasons=risk_reasons
            )
            
    except Exception as e:
        print(f"FNS Verification error: {e}")
        return None
