from fastapi import FastAPI, Depends, HTTPException, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from typing import List, Optional
import redis
import tempfile
import os
import logging
from .price_analyzer import PriceAnalyzer
from .services.rfq_service import RFQService
import json
from datetime import datetime

logger = logging.getLogger(__name__)

from . import models, schemas, database, discovery
from .database import engine, get_db

models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="SupplyFind Professional API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Redis Cache setup
try:
    redis_client = redis.Redis(host='redis', port=6379, db=0, decode_responses=True)
except:
    redis_client = None

from .services.scoring import calculate_score

active_searches = set()

@app.get("/api/discovery/status")
def get_discovery_status():
    if active_searches:
        try:
            item = list(active_searches)[0]
            parts = item.split(":")
            return {
                "active": True,
                "category": parts[0],
                "city": parts[1]
            }
        except:
            pass
    return {"active": False}

@app.post("/api/suppliers/search", response_model=List[schemas.Supplier])
async def search_suppliers(
    category: str,
    city: str,
    verified_only: bool = False,
    has_certificate: bool = False,
    min_score: int = 0,
    source_type: Optional[str] = None,
    db: Session = Depends(get_db)
):
    cache_key = f"search:{category}:{city}:{verified_only}:{has_certificate}:{min_score}:{source_type}"
    
    if redis_client:
        cached = redis_client.get(cache_key)
        if cached:
            history = models.SearchHistory(
                query=f"{category} {city}",
                category=category,
                city=city,
                results_total=len(json.loads(cached)),
                results_after_filter=len(json.loads(cached)),
                cache_hit=True
            )
            db.add(history)
            db.commit()
            return json.loads(cached)

    # First check DB
    query = db.query(models.Supplier).filter(
        models.Supplier.category == category,
        models.Supplier.city == city,
        models.Supplier.is_hidden == False
    )
    if verified_only:
        query = query.filter(models.Supplier.is_verified == True)
    if has_certificate:
        query = query.filter(models.Supplier.has_certificate == True)
    if min_score > 0:
        query = query.filter(models.Supplier.score >= min_score)
    if source_type:
        query = query.filter(models.Supplier.source_type == source_type)
        
    db_results = query.order_by(models.Supplier.score.desc()).all()

    if len(db_results) < 3:
        # Run AI Discovery
        search_key = f"{category}:{city}"
        active_searches.add(search_key)
        try:
            service = discovery.DiscoveryService(db)
            await service.discover_suppliers(category, city)
        finally:
            active_searches.discard(search_key)
        
        # Re-query
        query = db.query(models.Supplier).filter(
            models.Supplier.category == category,
            models.Supplier.city == city,
            models.Supplier.is_hidden == False
        )
        if verified_only:
            query = query.filter(models.Supplier.is_verified == True)
        if has_certificate:
            query = query.filter(models.Supplier.has_certificate == True)
        if min_score > 0:
            query = query.filter(models.Supplier.score >= min_score)
        if source_type:
            query = query.filter(models.Supplier.source_type == source_type)
            
        db_results = query.order_by(models.Supplier.score.desc()).all()

    # Log history
    history = models.SearchHistory(
        query=f"{category} {city}",
        category=category,
        city=city,
        results_total=len(db_results),
        results_after_filter=len(db_results),
        cache_hit=False
    )
    db.add(history)
    db.commit()

    # Cache
    if redis_client and db_results:
        suppliers_json = [schemas.Supplier.model_validate(s).model_dump_json() for s in db_results]
        redis_client.setex(cache_key, 3600, json.dumps([json.loads(s) for s in suppliers_json]))

    return db_results

# Fallback for old frontend
@app.post("/suppliers/discover", response_model=List[schemas.Supplier])
async def discover_suppliers_old(
    category: str,
    city: str,
    db: Session = Depends(get_db)
):
    return await search_suppliers(category, city, db=db)

@app.post("/suppliers/discover/all", response_model=List[schemas.Supplier])
async def discover_all_suppliers(db: Session = Depends(get_db)):
    search_key = "Все:Все"
    active_searches.add(search_key)
    try:
        service = discovery.DiscoveryService(db)
        categories = ["Dairy", "Vegetables", "Meat", "Bakery"]
        cities = ["Москва", "Санкт-Петербург", "Краснодар", "Екатеринбург"]
        
        all_new = []
        for cat in categories:
            for city in cities:
                new = await service.discover_suppliers(cat, city)
                all_new.extend(new)
        return all_new
    finally:
        active_searches.discard(search_key)

@app.post("/suppliers/compare", response_model=dict)
def compare_suppliers(supplier_ids: List[int], db: Session = Depends(get_db)):
    """
    Task 5: Smart comparison with scoring.
    """
    suppliers = db.query(models.Supplier).filter(models.Supplier.id.in_(supplier_ids)).all()
    if not suppliers:
        return {"winner_id": None, "explanation": "Нет данных для сравнения."}

    scores = []
    for s in suppliers:
        score = 0
        if s.is_verified: score += 30
        if s.has_certificate: score += 20
        if s.contact_phone and s.contact_email: score += 20
        if s.min_order_amount and s.min_order_amount < 10000: score += 15
        if s.delivery_days and s.delivery_days <= 3: score += 15
        
        scores.append({"id": s.id, "name": s.name, "score": score})

    # Sort by score descending
    scores.sort(key=lambda x: x["score"], reverse=True)
    winner = scores[0]
    
    explanation = f"Победитель анализа: {winner['name']} (Балл: {winner['score']}/100).\n"
    explanation += "Обоснование: Лидер по совокупности факторов верификации, наличия контактов и операционных условий."

    return {
        "winner_id": winner["id"],
        "explanation": explanation,
        "scores": scores
    }

@app.get("/suppliers", response_model=List[schemas.Supplier])
def get_suppliers(
    category: Optional[str] = None,
    city: Optional[str] = None,
    show_hidden: bool = False,
    db: Session = Depends(get_db)
):
    query = db.query(models.Supplier).filter(models.Supplier.is_hidden == show_hidden)
    if category:
        query = query.filter(models.Supplier.category == category)
    if city:
        query = query.filter(models.Supplier.city == city)
    return query.all()

@app.get("/suppliers/{supplier_id}", response_model=schemas.Supplier)
def get_supplier(supplier_id: int, db: Session = Depends(get_db)):
    supplier = db.query(models.Supplier).filter(models.Supplier.id == supplier_id).first()
    if not supplier:
        raise HTTPException(status_code=404, detail="Supplier not found")
    return supplier

@app.post("/suppliers", response_model=schemas.Supplier)
def create_supplier(supplier: schemas.SupplierCreate, db: Session = Depends(get_db)):
    db_supplier = models.Supplier(**supplier.model_dump(exclude={"products"}))
    db_supplier.is_manual = True
    db.add(db_supplier)
    db.commit()
    db.refresh(db_supplier)
    return db_supplier

@app.patch("/suppliers/{supplier_id}", response_model=schemas.Supplier)
def update_supplier(
    supplier_id: int,
    supplier_update: schemas.SupplierUpdate,
    db: Session = Depends(get_db)
):
    db_supplier = db.query(models.Supplier).filter(models.Supplier.id == supplier_id).first()
    if not db_supplier:
        raise HTTPException(status_code=404, detail="Supplier not found")
    
    update_data = supplier_update.model_dump(exclude_unset=True)
    
    if "products" in update_data:
        db.query(models.Product).filter(models.Product.supplier_id == supplier_id).delete()
        for p in update_data["products"]:
            new_p = models.Product(**p, supplier_id=supplier_id)
            db.add(new_p)
        del update_data["products"]

    for key, value in update_data.items():
        setattr(db_supplier, key, value)
        
    db.commit()
    db.refresh(db_supplier)
    return db_supplier

@app.post("/suppliers/{supplier_id}/hide", response_model=schemas.Supplier)
def hide_supplier(supplier_id: int, db: Session = Depends(get_db)):
    db_supplier = db.query(models.Supplier).filter(models.Supplier.id == supplier_id).first()
    if not db_supplier:
        raise HTTPException(status_code=404, detail="Supplier not found")
    db_supplier.is_hidden = True
    db.commit()
    db.refresh(db_supplier)
    return db_supplier

@app.post("/suppliers/{supplier_id}/unhide", response_model=schemas.Supplier)
def unhide_supplier(supplier_id: int, db: Session = Depends(get_db)):
    db_supplier = db.query(models.Supplier).filter(models.Supplier.id == supplier_id).first()
    if not db_supplier:
        raise HTTPException(status_code=404, detail="Supplier not found")
    db_supplier.is_hidden = False
    db.commit()
    db.refresh(db_supplier)
    return db_supplier

@app.post("/api/suppliers/{supplier_id}/upload-price", response_model=dict)
async def upload_price(
    supplier_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    supplier = db.query(models.Supplier).filter(models.Supplier.id == supplier_id).first()
    if not supplier:
        raise HTTPException(status_code=404, detail="Supplier not found")

    suffix = os.path.splitext(file.filename)[1].lower()
    if suffix not in ['.pdf', '.xlsx', '.xls']:
        raise HTTPException(status_code=400, detail="Поддерживаются только PDF и Excel (.xlsx, .xls)")

    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        content = await file.read()
        tmp.write(content)
        tmp_path = tmp.name

    try:
        analyzer = PriceAnalyzer()
        items = []
        parse_warning = None

        try:
            if suffix == '.pdf':
                items = analyzer.analyze_pdf(tmp_path)
            else:
                items = analyzer.analyze_excel(tmp_path)
        except Exception as parse_ex:
            parse_warning = str(parse_ex)
            logger.warning(f"[upload-price] parser error for '{file.filename}': {parse_ex}")

        # Always attach the filename to the supplier record
        price_urls = set(supplier.price_list_urls or [])
        price_urls.add(file.filename)
        supplier.price_list_urls = list(price_urls)

        if items:
            # Replace old price items
            db.query(models.PriceItem).filter(models.PriceItem.supplier_id == supplier_id).delete()
            for item in items:
                db.add(models.PriceItem(
                    supplier_id=supplier_id,
                    product_name=item["product_name"],
                    price=item["price"],
                    unit=item["unit"]
                ))

            # Update supplier score
            supplier_dict = {
                "is_verified": supplier.is_verified,
                "reg_date": supplier.reg_date,
                "is_risky": supplier.is_risky,
                "phones": supplier.phones,
                "emails": supplier.emails,
                "personal_email": supplier.personal_email,
                "has_certificate": supplier.has_certificate,
                "is_manufacturer": supplier.is_manufacturer,
                "payment_delay_days": supplier.payment_delay_days,
                "has_delivery": supplier.has_delivery
            }
            score, explanation = calculate_score(supplier_dict)
            supplier.score = score
            supplier.score_explanation = explanation

        db.commit()
        db.refresh(supplier)

        summary = analyzer.get_summary(items) if items else {}

        if items:
            return {
                "message": f"Успешно разобрано {len(items)} позиций из файла '{file.filename}'",
                "items_parsed": len(items),
                "summary": summary,
                "parse_warning": None,
            }
        else:
            return {
                "message": f"Файл '{file.filename}' прикреплён к поставщику. Авторазбор позиций не удался — файл имеет нестандартную структуру.",
                "items_parsed": 0,
                "summary": {},
                "parse_warning": parse_warning or "Не найдено строк с товарами и ценами.",
            }
    except Exception as e:
        db.rollback()
        logger.error(f"[upload-price] unexpected error for supplier {supplier_id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Ошибка обработки файла: {str(e)}")
    finally:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)

@app.get("/api/smtp/status", response_model=dict)
def get_smtp_status():
    """Returns current SMTP configuration status (credentials are masked)."""
    rfq_service = RFQService()
    return {
        "configured": rfq_service.is_configured(),
        "smtp_host": rfq_service.smtp_host,
        "smtp_port": rfq_service.smtp_port,
        "smtp_user": rfq_service.smtp_user if rfq_service.smtp_user else None,
        "smtp_from": rfq_service.smtp_from if rfq_service.smtp_from else None,
    }

@app.post("/api/smtp/configure", response_model=dict)
def configure_smtp(
    smtp_host: str,
    smtp_port: int,
    smtp_user: str,
    smtp_password: str,
    smtp_from: Optional[str] = None,
):
    """
    Save SMTP credentials to the .env file and update environment variables.
    """
    env_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env")
    
    # Read existing env content
    env_lines = []
    smtp_keys = {"SMTP_HOST", "SMTP_PORT", "SMTP_USER", "SMTP_PASSWORD", "SMTP_FROM"}
    if os.path.exists(env_path):
        with open(env_path, "r") as f:
            for line in f:
                key = line.split("=")[0].strip()
                if key not in smtp_keys:
                    env_lines.append(line.rstrip())
    
    # Append new SMTP settings
    env_lines.append(f"SMTP_HOST={smtp_host}")
    env_lines.append(f"SMTP_PORT={smtp_port}")
    env_lines.append(f"SMTP_USER={smtp_user}")
    env_lines.append(f"SMTP_PASSWORD={smtp_password}")
    env_lines.append(f"SMTP_FROM={smtp_from or smtp_user}")
    
    with open(env_path, "w") as f:
        f.write("\n".join(env_lines) + "\n")
    
    # Update current process environment
    os.environ["SMTP_HOST"] = smtp_host
    os.environ["SMTP_PORT"] = str(smtp_port)
    os.environ["SMTP_USER"] = smtp_user
    os.environ["SMTP_PASSWORD"] = smtp_password
    os.environ["SMTP_FROM"] = smtp_from or smtp_user
    
    return {"status": "ok", "message": "SMTP настройки успешно сохранены"}

@app.post("/api/rfq/send", response_model=dict)
async def send_rfq(
    rfq_data: schemas.RFQRequestCreate,
    db: Session = Depends(get_db)
):
    rfq_service = RFQService()
    try:
        res = await rfq_service.send_rfq(
            db, rfq_data.supplier_id, rfq_data.request_text,
            recipient_email=rfq_data.email_sent_to
        )
        return res
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to send RFQ: {str(e)}")

@app.post("/api/rfq/send-with-file", response_model=dict)
async def send_rfq_with_file(
    supplier_id: int = Form(...),
    request_text: str = Form(...),
    email_sent_to: Optional[str] = Form(None),
    file: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db)
):
    """Send an RFQ email with an optional file attachment (price list, specification, etc.)"""
    rfq_service = RFQService()
    attachment_bytes = None
    attachment_filename = None
    
    if file:
        suffix = os.path.splitext(file.filename)[1].lower()
        if suffix not in ['.pdf', '.xlsx', '.xls', '.doc', '.docx']:
            raise HTTPException(status_code=400, detail="Поддерживаются только файлы: PDF, Excel, Word")
        attachment_bytes = await file.read()
        attachment_filename = file.filename
    
    try:
        res = await rfq_service.send_rfq(
            db, supplier_id, request_text,
            recipient_email=email_sent_to,
            attachment_bytes=attachment_bytes,
            attachment_filename=attachment_filename,
        )
        return res
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to send RFQ: {str(e)}")

@app.get("/api/rfq/history", response_model=List[schemas.RFQRequest])
def get_rfq_history(
    supplier_id: Optional[int] = None,
    db: Session = Depends(get_db)
):
    query = db.query(models.RFQRequest)
    if supplier_id is not None:
        query = query.filter(models.RFQRequest.supplier_id == supplier_id)
    return query.order_by(models.RFQRequest.sent_at.desc()).all()

@app.post("/api/rfq/{rfq_id}/status", response_model=schemas.RFQRequest)
def update_rfq_status(
    rfq_id: int,
    status: str,
    db: Session = Depends(get_db)
):
    rfq = db.query(models.RFQRequest).filter(models.RFQRequest.id == rfq_id).first()
    if not rfq:
        raise HTTPException(status_code=404, detail="RFQ log entry not found")
    rfq.status = status
    if status == "Получен ответ":
        rfq.response_received_at = datetime.now()
    db.commit()
    db.refresh(rfq)
    return rfq

@app.post("/clear", status_code=204)
def clear_data(db: Session = Depends(get_db)):
    db.query(models.Product).delete()
    db.query(models.PriceItem).delete()
    db.query(models.RFQRequest).delete()
    db.query(models.SearchHistory).delete()
    db.query(models.Supplier).delete()
    db.commit()
    return None
