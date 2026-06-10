import smtplib
import os
import asyncio
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase
from email import encoders
from typing import Optional
from sqlalchemy.orm import Session
from datetime import datetime
from .. import models


class RFQService:
    def __init__(self):
        self.smtp_host = os.getenv("SMTP_HOST", "smtp.gmail.com")
        self.smtp_port = int(os.getenv("SMTP_PORT", "587"))
        self.smtp_user = os.getenv("SMTP_USER", "")
        self.smtp_password = os.getenv("SMTP_PASSWORD", "")
        self.smtp_from = os.getenv("SMTP_FROM", self.smtp_user)

    def is_configured(self) -> bool:
        return bool(self.smtp_user and self.smtp_password)

    def generate_rfq_body(self, supplier_name: str, category: str, request_text: str) -> str:
        """
        Formats a professional B2B HoReCa email template.
        """
        return f"""Уважаемый партнер {supplier_name},

Вас приветствует отдел снабжения сети HoReCa («Жизнь Март» / «Сушкофф»).

Мы рассматриваем вашу компанию как потенциального поставщика в категории «{category}».
Просим предоставить коммерческое предложение, актуальный прайс-лист, а также информацию об условиях сотрудничества на основании нашего запроса:

---
{request_text}
---

Будем признательны за предоставление информации о:
- Минимальной сумме заказа (в рублях или килограммах).
- Возможности и условиях доставки до распределительного центра.
- Доступности отсрочки платежа.
- Наличии сертификатов качества (ГОСТ, Халяль, ISO).

Пожалуйста, направьте ответным письмом ваш актуальный прайс-лист (.pdf или .xlsx).

С уважением,
Отдел снабжения HoReCa
"""

    async def send_rfq(
        self,
        db: Session,
        supplier_id: int,
        request_text: str,
        attachment_bytes: Optional[bytes] = None,
        attachment_filename: Optional[str] = None,
    ) -> dict:
        """
        Generates and sends an RFQ email to the supplier (optionally with file attachment),
        then logs it in the database.
        """
        supplier = db.query(models.Supplier).filter(models.Supplier.id == supplier_id).first()
        if not supplier:
            raise ValueError("Supplier not found")

        email_to = supplier.contact_email or (supplier.emails[0] if supplier.emails else None)
        if not email_to:
            raise ValueError("Supplier has no contact email address configured")

        subject = f"Запрос коммерческого предложения (категория: {supplier.category}) — HoReCa"
        body = self.generate_rfq_body(supplier.name, supplier.category, request_text)

        has_attachment = bool(attachment_bytes and attachment_filename)
        attachment_note = f" [вложение: {attachment_filename}]" if has_attachment else ""

        # Log entry in database
        rfq_log = models.RFQRequest(
            supplier_id=supplier_id,
            email_sent_to=email_to,
            request_text=body + attachment_note,
            status="Отправлено"
        )
        db.add(rfq_log)
        db.commit()
        db.refresh(rfq_log)

        # If SMTP credentials are not configured, simulate success
        if not self.is_configured():
            rfq_log.status = "Симуляция отправки (нет SMTP настроек)"
            db.commit()
            return {
                "id": rfq_log.id,
                "status": rfq_log.status,
                "recipient": email_to,
                "subject": subject,
                "body": body,
                "has_attachment": has_attachment,
                "simulated": True
            }

        try:
            await asyncio.to_thread(
                self._send_email_sync,
                email_to,
                subject,
                body,
                attachment_bytes,
                attachment_filename,
            )
            rfq_log.status = "Отправлено"
            db.commit()
            return {
                "id": rfq_log.id,
                "status": rfq_log.status,
                "recipient": email_to,
                "subject": subject,
                "has_attachment": has_attachment,
                "simulated": False
            }
        except Exception as e:
            rfq_log.status = f"Ошибка: {str(e)}"
            db.commit()
            return {
                "id": rfq_log.id,
                "status": "Ошибка",
                "error": str(e),
                "recipient": email_to,
                "simulated": False
            }

    def _send_email_sync(
        self,
        to_email: str,
        subject: str,
        body: str,
        attachment_bytes: Optional[bytes] = None,
        attachment_filename: Optional[str] = None,
    ):
        msg = MIMEMultipart()
        msg['From'] = self.smtp_from
        msg['To'] = to_email
        msg['Subject'] = subject

        msg.attach(MIMEText(body, 'plain', 'utf-8'))

        # Attach file if provided
        if attachment_bytes and attachment_filename:
            part = MIMEBase('application', 'octet-stream')
            part.set_payload(attachment_bytes)
            encoders.encode_base64(part)
            part.add_header(
                'Content-Disposition',
                f'attachment; filename="{attachment_filename}"'
            )
            msg.attach(part)

        with smtplib.SMTP(self.smtp_host, self.smtp_port) as server:
            if self.smtp_port == 587:
                server.starttls()
            server.login(self.smtp_user, self.smtp_password)
            server.send_message(msg)
