from pydantic import BaseModel, ConfigDict
from typing import Optional, List
from datetime import datetime
from decimal import Decimal

class ProductBase(BaseModel):
    name: str
    price: str
    unit: str

class ProductCreate(ProductBase):
    pass

class Product(ProductBase):
    id: int
    supplier_id: int
    model_config = ConfigDict(from_attributes=True)

class PriceItemBase(BaseModel):
    product_name: str
    price: Decimal
    unit: str

class PriceItem(PriceItemBase):
    id: int
    supplier_id: int
    parsed_at: datetime
    model_config = ConfigDict(from_attributes=True)

class SupplierBase(BaseModel):
    name: str
    description: Optional[str] = None
    website: Optional[str] = None
    contact_email: Optional[str] = None
    contact_phone: Optional[str] = None
    category: str
    city: str
    
    # New verified fields
    inn: Optional[str] = None
    ogrn: Optional[str] = None
    legal_address: Optional[str] = None
    is_verified: Optional[bool] = False
    verified_at: Optional[datetime] = None
    blacklisted_reason: Optional[str] = None
    
    # Operational fields
    price_range: Optional[str] = None
    min_order_amount: Optional[Decimal] = None
    delivery_days: Optional[int] = None
    has_certificate: Optional[bool] = False
    certificate_types: List[str] = []
    
    notes: Optional[str] = None
    rating: Optional[int] = 0
    is_manual: Optional[bool] = False
    is_hidden: Optional[bool] = False
    revenue: Optional[str] = None
    status: Optional[str] = "Требуется проверка"

class SupplierCreate(SupplierBase):
    products: Optional[List[ProductCreate]] = []

class SupplierUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    website: Optional[str] = None
    contact_email: Optional[str] = None
    contact_phone: Optional[str] = None
    inn: Optional[str] = None
    ogrn: Optional[str] = None
    legal_address: Optional[str] = None
    is_verified: Optional[bool] = None
    price_range: Optional[str] = None
    min_order_amount: Optional[Decimal] = None
    delivery_days: Optional[int] = None
    has_certificate: Optional[bool] = None
    certificate_types: Optional[List[str]] = None
    notes: Optional[str] = None
    rating: Optional[int] = None
    products: Optional[List[ProductCreate]] = None

class RFQRequestBase(BaseModel):
    supplier_id: int
    email_sent_to: Optional[str] = None
    request_text: str

class RFQRequestCreate(RFQRequestBase):
    pass

class RFQRequest(RFQRequestBase):
    id: int
    status: str
    sent_at: datetime
    response_received_at: Optional[datetime] = None
    model_config = ConfigDict(from_attributes=True)

class Supplier(SupplierBase):
    id: int
    products: List[Product] = []
    price_items: List[PriceItem] = []
    rfq_requests: List[RFQRequest] = []
    model_config = ConfigDict(from_attributes=True)

class SearchHistoryBase(BaseModel):
    user_query: str
    category: str
    city: str
    results_count: int
    cache_hit: bool = False

class SearchHistory(SearchHistoryBase):
    id: int
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)
