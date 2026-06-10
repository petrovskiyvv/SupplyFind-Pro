import httpx
import asyncio
import os
from typing import Optional, Dict, Any
from .config import settings

class DaDataVerifier:
    def __init__(self):
        self.api_key = os.getenv("DADATA_API_KEY", "your_dadata_key_here")
        self.secret_key = os.getenv("DADATA_SECRET_KEY", "your_dadata_secret_here")
        self.base_url = "https://suggestions.dadata.ru/suggestions/api/4_1/rs/findById/party"
        self.headers = {
            "Content-Type": "application/json",
            "Accept": "application/json",
            "Authorization": f"Token {self.api_key}"
        }

    async def verify_inn(self, inn: str) -> Optional[Dict[str, Any]]:
        """
        Verifies a company by INN using DaData API.
        Returns official name, status, OGRN, and address.
        """
        if not inn:
            return None
            
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    self.base_url,
                    json={"query": inn},
                    headers=self.headers,
                    timeout=5.0
                )
                
                if response.status_code != 200:
                    return None
                    
                data = response.json()
                suggestions = data.get("suggestions", [])
                
                if not suggestions:
                    return None
                    
                party = suggestions[0]["data"]
                return {
                    "official_name": party.get("name", {}).get("full_with_opf"),
                    "status": party.get("state", {}).get("status"), # ACTIVE, LIQUIDATED etc
                    "ogrn": party.get("ogrn"),
                    "legal_address": party.get("address", {}).get("value"),
                    "management": party.get("management", {}).get("name"),
                    "is_verified": party.get("state", {}).get("status") == "ACTIVE"
                }
        except Exception as e:
            print(f"DaData verification error: {e}")
            return None
