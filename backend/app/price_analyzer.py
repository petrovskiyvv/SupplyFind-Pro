import pdfplumber
import openpyxl
import re
from typing import List, Dict, Any, Optional
from decimal import Decimal, InvalidOperation
from datetime import datetime


PRICE_RE = re.compile(r"(\d[\d\s]*(?:[.,]\d+)?)")
UNIT_MAP = {
    "шт": "шт", "штук": "шт", "piece": "шт",
    "кг": "кг", "kg": "кг", "килог": "кг",
    "г": "г", "гр": "г", "грамм": "г",
    "л": "л", "лит": "л", "litr": "л",
    "уп": "уп", "упак": "уп", "pack": "уп",
    "м": "м", "метр": "м",
    "т": "т", "тонн": "т",
}
HEADER_SKIP = {"наименование", "товар", "цена", "прайс", "артикул",
               "код", "ед.изм", "name", "price", "qty", "ед", "unit",
               "номер", "№", "кол-во", "количество", "сумма", "итого"}


def _detect_unit(text: str) -> str:
    lower = text.lower()
    for kw, unit in UNIT_MAP.items():
        if kw in lower:
            return unit
    return "кг"


def _to_decimal(val: Any) -> Optional[Decimal]:
    """Try to convert any value to a positive Decimal."""
    if val is None:
        return None
    if isinstance(val, (int, float)):
        try:
            d = Decimal(str(val))
            return d if d > 0 else None
        except InvalidOperation:
            return None
    s = str(val).strip()
    # Remove currency symbols, spaces used as thousands sep
    s = re.sub(r"[^\d.,]", "", s)
    s = s.replace(" ", "").replace(",", ".")
    # Handle multiple dots (e.g. "1.500.000" → keep last portion)
    parts = s.split(".")
    if len(parts) > 2:
        s = parts[0] + "." + parts[-1]
    try:
        d = Decimal(s)
        return d if d > 0 else None
    except InvalidOperation:
        return None


def _is_header_row(cells: List[str]) -> bool:
    row_words = set()
    for c in cells:
        for word in c.lower().split():
            row_words.add(word.strip(".,:-"))
    hits = row_words & HEADER_SKIP
    return len(hits) >= 2


class PriceAnalyzer:

    # ------------------------------------------------------------------ #
    #  Public methods                                                       #
    # ------------------------------------------------------------------ #

    def analyze_pdf(self, file_path: str) -> List[Dict[str, Any]]:
        """Extract price data from PDF — tries tables first, then plain text."""
        items = []
        try:
            with pdfplumber.open(file_path) as pdf:
                for page in pdf.pages:
                    # 1) Try structured table
                    table = page.extract_table()
                    if table:
                        for row in table:
                            item = self._parse_row([str(c) if c is not None else "" for c in row])
                            if item:
                                items.append(item)
                    else:
                        # 2) Fall back to raw text lines
                        text = page.extract_text() or ""
                        for line in text.splitlines():
                            item = self._parse_text_line(line)
                            if item:
                                items.append(item)
        except Exception as e:
            print(f"PDF analysis error: {e}")
        return self._deduplicate(items)

    def analyze_excel(self, file_path: str) -> List[Dict[str, Any]]:
        """Extract price data from Excel (all sheets)."""
        items = []
        try:
            wb = openpyxl.load_workbook(file_path, data_only=True)
            for sheet in wb.worksheets:
                for row in sheet.iter_rows(values_only=True):
                    if all(c is None for c in row):
                        continue
                    cells = [c for c in row]  # keep Nones for position
                    item = self._parse_row(cells)
                    if item:
                        items.append(item)
        except Exception as e:
            print(f"Excel analysis error: {e}")
        return self._deduplicate(items)

    def get_summary(self, items: List[Dict[str, Any]]) -> Dict[str, Any]:
        if not items:
            return {}
        prices = [float(i["price"]) for i in items]
        return {
            "min": min(prices),
            "max": max(prices),
            "avg": round(sum(prices) / len(prices), 2),
            "count": len(items),
        }

    # ------------------------------------------------------------------ #
    #  Internal helpers                                                    #
    # ------------------------------------------------------------------ #

    def _parse_row(self, row: List[Any]) -> Optional[Dict[str, Any]]:
        if not row:
            return None

        str_cells = [str(c).strip() if c is not None else "" for c in row]
        non_empty = [c for c in str_cells if c]
        if len(non_empty) < 1:
            return None

        # Skip obviously empty or header rows
        if _is_header_row(non_empty):
            return None

        unit = _detect_unit(" ".join(non_empty))

        price_candidates: List[tuple] = []  # (col_idx, Decimal)
        name_candidates: List[tuple] = []   # (col_idx, str)

        for i, cell in enumerate(row):
            cs = str_cells[i]
            if not cs:
                continue

            # Serial number heuristic: skip first cell if it's a small integer
            if i == 0 and cs.isdigit() and int(cs) < 5000:
                # Could still be a price — only skip if very small
                if int(cs) < 100:
                    continue

            dec = _to_decimal(cell)
            if dec is not None and dec < 1_000_000:
                price_candidates.append((i, dec))

            # Name candidate: contains letters, length > 2
            if isinstance(cell, str) and len(cs) > 2 and re.search(r"[а-яА-Яa-zA-Z]", cs):
                name_candidates.append((i, cs))
            elif not isinstance(cell, (int, float)) and len(cs) > 2 and re.search(r"[а-яА-Яa-zA-Z]", cs):
                name_candidates.append((i, cs))

        if not price_candidates or not name_candidates:
            return None

        # Choose the longest name
        name_candidates.sort(key=lambda x: len(x[1]), reverse=True)
        name_idx, product_name = name_candidates[0]

        # Collect price candidates that are NOT in the name column
        price_pool = [p for p in price_candidates if p[0] != name_idx]
        if not price_pool:
            return None

        # Prefer candidates AFTER the name column
        after = [p for p in price_pool if p[0] > name_idx]
        candidates = after if after else price_pool

        # Among candidates, filter out likely "quantity" values:
        # small integers (≤100) when there are also non-integer values present
        has_non_integer = any(p[1] != p[1].to_integral_value() or p[1] > 100 for p in candidates)
        if has_non_integer:
            # Drop small whole-number candidates that are likely qty/stock counts
            filtered = [p for p in candidates if p[1] > 100 or p[1] != p[1].to_integral_value()]
            if filtered:
                candidates = filtered

        # Take the LARGEST value — prices are bigger than quantities
        price_val = max(candidates, key=lambda x: x[1])[1]

        return {
            "product_name": product_name.strip()[:300],
            "price": price_val,
            "unit": unit,
        }

    def _parse_text_line(self, line: str) -> Optional[Dict[str, Any]]:
        """Parse a single text line that may contain 'name ... price'."""
        line = line.strip()
        if not line or len(line) < 5:
            return None

        # Find all price-like numbers (≥2 digits)
        matches = list(PRICE_RE.finditer(line))
        if not matches:
            return None

        unit = _detect_unit(line)

        # Take the last numeric match as price
        last_match = matches[-1]
        raw_price = last_match.group(1).replace(" ", "").replace(",", ".")
        dec = _to_decimal(raw_price)
        if dec is None or dec < 1:
            return None

        # Name = everything before the first number, cleaned up
        name_part = line[: last_match.start()].strip()
        name_part = re.sub(r"[^\w\s\-\(\)\/]", " ", name_part).strip()
        if len(name_part) < 3:
            return None

        # Skip header-like lines
        if _is_header_row([name_part]):
            return None

        return {
            "product_name": name_part[:300],
            "price": dec,
            "unit": unit,
        }

    @staticmethod
    def _deduplicate(items: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Remove exact name duplicates, keep highest price."""
        seen: Dict[str, Dict[str, Any]] = {}
        for item in items:
            key = item["product_name"].lower()
            if key not in seen or item["price"] > seen[key]["price"]:
                seen[key] = item
        return list(seen.values())
