from sqlalchemy import Column, Integer, String, Boolean, Text, ForeignKey, DateTime, Numeric, Date
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from .database import Base

class Supplier(Base):
    __tablename__ = "suppliers"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    category = Column(String, index=True)
    city = Column(String, index=True)
    description = Column(Text)
    website = Column(String)
    contact_email = Column(String)
    contact_phone = Column(String)
    
    inn = Column(String(12), index=True)
    ogrn = Column(String(15))
    legal_name = Column(String(500))
    legal_address = Column(Text)
    director_name = Column(String(300))
    reg_date = Column(Date)
    legal_status = Column(String(100), default='Неизвестно')
    
    is_verified = Column(Boolean, default=False)
    verified_at = Column(DateTime)
    is_risky = Column(Boolean, default=False)
    risk_reasons = Column(ARRAY(Text), default=[])
    
    phones = Column(ARRAY(String), default=[])
    emails = Column(ARRAY(String), default=[])
    personal_email = Column(Boolean, default=False)
    
    has_certificate = Column(Boolean, default=False)
    cert_types = Column(ARRAY(String), default=[])
    is_manufacturer = Column(Boolean, default=False)
    
    has_delivery = Column(Boolean, default=False)
    has_pickup = Column(Boolean, default=False)
    payment_delay_days = Column(Integer, default=0)
    
    min_order_kg = Column(Numeric(precision=10, scale=2))
    min_order_rub = Column(Numeric(precision=10, scale=2))
    price_list_urls = Column(ARRAY(String), default=[])
    
    score = Column(Integer, default=0)
    score_explanation = Column(ARRAY(Text), default=[])
    source_type = Column(String(50), default='tavily')

    # Old fields for compatibility if needed
    is_manual = Column(Boolean, default=False)
    is_hidden = Column(Boolean, default=False)

    products = relationship("Product", back_populates="supplier", cascade="all, delete-orphan")
    price_items = relationship("PriceItem", back_populates="supplier", cascade="all, delete-orphan")
    rfq_requests = relationship("RFQRequest", back_populates="supplier", cascade="all, delete-orphan")

class Product(Base):
    __tablename__ = "products"

    id = Column(Integer, primary_key=True, index=True)
    supplier_id = Column(Integer, ForeignKey("suppliers.id", ondelete="CASCADE"), nullable=False)
    name = Column(String, index=True)
    price = Column(String)
    unit = Column(String)

    supplier = relationship("Supplier", back_populates="products")

class PriceItem(Base):
    __tablename__ = "price_items"

    id = Column(Integer, primary_key=True, index=True)
    supplier_id = Column(Integer, ForeignKey("suppliers.id", ondelete="CASCADE"), nullable=False)
    product_name = Column(String, index=True)
    price = Column(Numeric(precision=10, scale=2))
    unit = Column(String)
    parsed_at = Column(DateTime, server_default=func.now())

    supplier = relationship("Supplier", back_populates="price_items")

class RFQRequest(Base):
    __tablename__ = "rfq_requests"

    id = Column(Integer, primary_key=True, index=True)
    supplier_id = Column(Integer, ForeignKey("suppliers.id", ondelete="CASCADE"), nullable=False)
    status = Column(String(50), default="Отправлено")
    email_sent_to = Column(String)
    request_text = Column(Text)
    sent_at = Column(DateTime, server_default=func.now())
    response_received_at = Column(DateTime, nullable=True)

    supplier = relationship("Supplier", back_populates="rfq_requests")

class SearchHistory(Base):
    __tablename__ = "search_history"

    id = Column(Integer, primary_key=True, index=True)
    query = Column(String(500))
    category = Column(String(200))
    city = Column(String(200))
    results_total = Column(Integer)
    results_after_filter = Column(Integer)
    cache_hit = Column(Boolean, default=False)
    created_at = Column(DateTime, server_default=func.now())
