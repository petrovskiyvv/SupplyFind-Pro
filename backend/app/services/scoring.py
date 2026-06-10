from datetime import date

def calculate_score(supplier: dict) -> tuple[int, list[str]]:
    score = 0
    explanation = []

    # Юридическая чистота
    if supplier.get("is_verified"):
        score += 25
        explanation.append("+25: ИНН подтверждён в ЕГРЮЛ")
    
    if supplier.get("reg_date"):
        try:
            # Handle both date objects and string dates
            reg_date = supplier["reg_date"]
            if isinstance(reg_date, str):
                from datetime import datetime
                reg_date = datetime.strptime(reg_date, "%Y-%m-%d").date()
                
            years = (date.today() - reg_date).days / 365
            if years >= 3:
                score += 20
                explanation.append(f"+20: Компания работает {int(years)} лет")
            elif years >= 1:
                score += 10
                explanation.append(f"+10: Компания работает {int(years)} лет")
            else:
                score -= 15
                explanation.append("-15: Компания зарегистрирована менее года назад")
        except:
            pass

    if supplier.get("is_risky"):
        score -= 20
        explanation.append("-20: Признаки риска (массовый адрес или ликвидация)")

    # Контакты
    if supplier.get("phones") and len(supplier["phones"]) > 0:
        score += 15
        explanation.append("+15: Есть прямой телефон")
        
    if supplier.get("emails") and len(supplier["emails"]) > 0 and not supplier.get("personal_email"):
        score += 10
        explanation.append("+10: Есть корпоративный email")
        
    if not supplier.get("phones") and not supplier.get("emails"):
        score -= 20
        explanation.append("-20: Нет контактов кроме соцсетей")

    # Качество
    if supplier.get("has_certificate"):
        score += 15
        explanation.append("+15: Есть сертификаты качества")
    if supplier.get("is_manufacturer"):
        score += 10
        explanation.append("+10: Собственное производство")

    # Коммерческие условия
    payment_delay = supplier.get("payment_delay_days") or 0
    if payment_delay > 0:
        score += 10
        explanation.append(f"+10: Отсрочка платежа {payment_delay} дней")
        
    if supplier.get("has_delivery"):
        score += 5
        explanation.append("+5: Есть доставка")

    score = max(0, min(100, score))
    return score, explanation
