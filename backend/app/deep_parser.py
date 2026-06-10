import httpx
import asyncio
import re
import time
from bs4 import BeautifulSoup
from dataclasses import dataclass, field
from typing import List, Optional
from datetime import datetime

@dataclass
class SupplierContacts:
    inn: Optional[str] = None
    phones: List[str] = field(default_factory=list)
    emails: List[str] = field(default_factory=list)
    address: Optional[str] = None

class DeepParser:
    def __init__(self):
        self.client = httpx.AsyncClient(
            headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"},
            timeout=10.0,
            follow_redirects=True
        )
        self.rate_limit = 1.0 # sec

    async def parse_url(self, url: str) -> SupplierContacts:
        """
        Parses a supplier website to extract contacts and INN.
        """
        try:
            # Simple rate limiting simulation
            await asyncio.sleep(self.rate_limit)
            
            response = await self.client.get(url)
            if response.status_code != 200:
                return SupplierContacts()

            soup = BeautifulSoup(response.text, 'html.parser')
            text = soup.get_text(separator=' ', strip=True)

            return SupplierContacts(
                inn=self._extract_inn(text),
                phones=self._extract_phones(text),
                emails=self._extract_emails(text),
                address=self._extract_address(soup)
            )
        except Exception as e:
            print(f"Deep parsing error for {url}: {e}")
            return SupplierContacts()

    def _extract_inn(self, text: str) -> Optional[str]:
        # Regex for 10 or 12 digits
        match = re.search(r"\b(\d{10}|\d{12})\b", text)
        return match.group(1) if match else None

    def _extract_phones(self, text: str) -> List[str]:
        # Basic RU phone regex
        pattern = r"(?:\+7|8|7)[\s\-]?(?:\(\d{3}\)|\d{3})[\s\-]?(?:\d{3}[\s\-]?\d{2}[\s\-]?\d{2})"
        matches = re.findall(pattern, text)
        return list(set(matches))[:3] # Unique top 3

    def _extract_emails(self, text: str) -> List[str]:
        pattern = r"[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+"
        matches = re.findall(pattern, text)
        return list(set(matches))[:3]

    def _extract_address(self, soup: BeautifulSoup) -> Optional[str]:
        # Look for keywords in common tags
        keywords = ["адрес", "address", "г.", "ул.", "проспект", "шоссе"]
        
        # Heuristic: search for elements containing these words
        for tag in ['p', 'span', 'div', 'footer']:
            elements = soup.find_all(tag, string=re.compile('|'.join(keywords), re.IGNORECASE))
            for el in elements:
                if 10 < len(el.text) < 200: # Realistic length
                    return el.text.strip()
        return None

    async def close(self):
        await self.client.aclose()
