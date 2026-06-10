import pdfplumber
import openpyxl
import re
from typing import List, Dict, Any, Optional
from decimal import Decimal
from datetime import datetime

class PriceAnalyzer:
    def analyze_pdf(self, file_path: str) -> List[Dict[str, Any]]:
        """
        Extracts price data from PDF using pdfplumber.
        """
        items = []
        try:
            with pdfplumber.open(file_path) as pdf:
                for page in pdf.pages:
                    table = page.extract_table()
                    if not table:
                        continue
                        
                    for row in table:
                        # Heuristic: find rows with numbers (prices)
                        # Expecting: [Name, Price, Unit] or similar
                        parsed_item = self._parse_row(row)
                        if parsed_item:
                            items.append(parsed_item)
        except Exception as e:
            print(f"PDF analysis error: {e}")
        return items

    def analyze_excel(self, file_path: str) -> List[Dict[str, Any]]:
        """
        Extracts price data from Excel using openpyxl.
        """
        items = []
        try:
            wb = openpyxl.load_workbook(file_path, data_only=True)
            sheet = wb.active
            for row in sheet.iter_rows(values_only=True):
                parsed_item = self._parse_row(list(row))
                if parsed_item:
                    items.append(parsed_item)
        except Exception as e:
            print(f"Excel analysis error: {e}")
        return items

    def _parse_row(self, row: List[Any]) -> Optional[Dict[str, Any]]:
        """
        Normalizes a row into a price item.
        """
        if not row:
            return None
            
        # Filter out completely None cells
        cells = [c for c in row if c is not None]
        if len(cells) < 2:
            return None
            
        # Join as string for keyword checks
        row_str = " ".join([str(c) for c in cells]).lower()
        
        # Skip header rows
        header_keywords = ["наименование", "товар", "цена", "прайс", "артикул", "код", "ед.изм"]
        if sum(1 for kw in header_keywords if kw in row_str) >= 2:
            return None
            
        # Find price and product name candidate
        price_val = None
        product_name = None
        unit = "кг"
        
        # Basic unit detection from the row string
        if "шт" in row_str:
            unit = "шт"
        elif "л" in row_str or "литр" in row_str:
            unit = "л"
        elif "уп" in row_str or "упак" in row_str:
            unit = "уп"
        elif "гр" in row_str or "грамм" in row_str:
            unit = "г"
            
        # Iterate through cells to identify name and price
        candidates_prices = []
        candidates_names = []
        
        for i, cell in enumerate(cells):
            cell_str = str(cell).strip()
            if not cell_str:
                continue
                
            # Try to parse cell as number
            is_serial = (i == 0 and cell_str.isdigit() and int(cell_str) < 1000)
            
            if not is_serial:
                if isinstance(cell, (int, float)):
                    if cell > 0:
                        candidates_prices.append((i, Decimal(str(cell))))
                else:
                    # Clean currency symbols and spaces from price string
                    clean_cell_str = re.sub(r"[^\d.,]", "", cell_str).replace(",", ".")
                    if clean_cell_str and re.match(r"^\d+(?:\.\d+)?$", clean_cell_str):
                        val = float(clean_cell_str)
                        if val > 0:
                            candidates_prices.append((i, Decimal(str(val))))
                            
            if isinstance(cell, str) and len(cell_str) > 3:
                if re.search(r"[a-zA-Zа-яА-Я]", cell_str):
                    candidates_names.append((i, cell_str))
                    
        if not candidates_prices or not candidates_names:
            return None
            
        # Product name is the longest name candidate
        candidates_names.sort(key=lambda x: len(x[1]), reverse=True)
        name_idx, product_name = candidates_names[0]
        
        # Price is a price candidate that is not in the name column
        price_candidates = [p for p in candidates_prices if p[0] != name_idx]
        if not price_candidates:
            return None
            
        price_candidates.sort(key=lambda x: x[0])
        price_val = price_candidates[-1][1]
        
        return {
            "product_name": product_name.strip(),
            "price": price_val,
            "unit": unit
        }

    def get_summary(self, items: List[Dict[str, Any]]) -> Dict[str, Any]:
        if not items:
            return {}
        prices = [float(i["price"]) for i in items]
        return {
            "min": min(prices),
            "max": max(prices),
            "avg": sum(prices) / len(prices),
            "count": len(items)
        }
