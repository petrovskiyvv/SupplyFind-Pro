<div align="center">

# 🛒 SupplyFind

### Платформа автоматизированного поиска B2B-поставщиков для HoReCa и ритейла

[![FastAPI](https://img.shields.io/badge/FastAPI-0.128-009688?style=for-the-badge&logo=fastapi)](https://fastapi.tiangolo.com)
[![Flutter](https://img.shields.io/badge/Flutter-3.45-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-4169E1?style=for-the-badge&logo=postgresql)](https://postgresql.org)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker)](https://docker.com)

</div>

---

## 📋 Что это

**SupplyFind** — внутренний B2B-инструмент для отделов снабжения. Система автоматически ищет поставщиков продуктов питания в интернете, верифицирует их по ФНС, парсит прайс-листы и позволяет отправлять запросы коммерческих предложений прямо из карточки поставщика.

Разработан для сетей **«Жизнь Март»** и **«Сушкофф»**, но подходит любому бизнесу с нуждой в централизованной базе поставщиков.

---

## ✨ Возможности

| Функция | Описание |
|---------|----------|
| 🔍 **AI-поиск** | Поиск поставщиков через Tavily API с фильтрами по категории и городу |
| 🏛 **Верификация ФНС** | Автоматическая проверка ИНН, статуса компании и даты регистрации |
| 📊 **Скоринг** | Бальная система 0–100: верификация, сертификаты, контакты, доставка |
| 📄 **Прайс-листы** | Загрузка и авторазбор Excel/PDF — товары и цены появляются в карточке |
| 📧 **SMTP + КП** | Отправка запросов КП/прайс-листов прямо из приложения с вложениями |
| ⚖️ **Сравнение** | Сравнение нескольких поставщиков по ключевым параметрам |
| 🌙 **Тёмная тема** | Полная поддержка светлой и тёмной темы |
| 🌐 **Мультиязычность** | Интерфейс на русском и английском |

---

## 🏗 Архитектура

```
┌─────────────────────────────────────────────────────┐
│                   Flutter Web (SPA)                  │
│            http://localhost:8080                     │
└────────────────────┬────────────────────────────────┘
                     │ REST / multipart
┌────────────────────▼────────────────────────────────┐
│              FastAPI (Python 3.9)                    │
│  ┌──────────┐  ┌──────────┐  ┌────────────────────┐ │
│  │ Suppliers│  │   RFQ    │  │  Price Analyzer    │ │
│  │  Router  │  │ Service  │  │  (PDF + Excel)     │ │
│  └────┬─────┘  └────┬─────┘  └────────────────────┘ │
│       │             │                                 │
│  ┌────▼─────┐  ┌────▼─────┐                         │
│  │PostgreSQL│  │  SMTP    │                         │
│  │(SQLAlch.)│  │ (stdlib) │                         │
│  └──────────┘  └──────────┘                         │
│  ┌──────────┐  ┌──────────┐                         │
│  │  Redis   │  │  Tavily  │                         │
│  │  Cache   │  │   API    │                         │
│  └──────────┘  └──────────┘                         │
└─────────────────────────────────────────────────────┘
```

---

## 🚀 Быстрый старт

### Требования
- Docker Desktop
- 4 GB RAM свободной памяти

### Запуск

```bash
# 1. Клонировать репозиторий
git clone <url> && cd food_supplier_service

# 2. Создать файл переменных окружения
cp backend/.env.example backend/.env

# 3. Заполнить ключи в backend/.env
nano backend/.env

# 4. Запустить стек
docker-compose up --build

# 5. Открыть в браузере
open http://localhost:8080
```

---

## ⚙️ Переменные окружения

Создайте файл `backend/.env` на основе `backend/.env.example`:

```env
# База данных (не менять для Docker)
DATABASE_URL=postgresql://user:password@db:5432/food_supplier_db

# Поиск поставщиков (обязательно)
TAVILY_API_KEY=tvly-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Верификация ИНН (необязательно)
DADATA_API_KEY=your_dadata_key

# AI-анализ (необязательно)
DEEPSEEK_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# SMTP для отправки КП (настраивается в UI)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your@gmail.com
SMTP_PASSWORD=your_app_password
SMTP_FROM=Your Name <your@gmail.com>
```

> **Получение Tavily API Key:** [app.tavily.com](https://app.tavily.com) → бесплатный план 1000 запросов/мес.

---

## 📡 API Endpoints

### Поставщики
| Метод | Путь | Описание |
|-------|------|----------|
| `GET` | `/suppliers` | Список всех поставщиков |
| `GET` | `/suppliers/{id}` | Карточка поставщика (с price_items) |
| `POST` | `/api/suppliers/search` | AI-поиск с фильтрами |
| `PATCH` | `/suppliers/{id}` | Редактирование карточки |
| `POST` | `/suppliers/{id}/hide` | Скрыть / чёрный список |
| `POST` | `/suppliers/discover/all` | Глобальный фоновый скан рынка |

### Прайс-листы
| Метод | Путь | Описание |
|-------|------|----------|
| `POST` | `/api/suppliers/{id}/upload-price` | Загрузить Excel/PDF прайс-лист |

### SMTP и КП
| Метод | Путь | Описание |
|-------|------|----------|
| `GET` | `/api/smtp/status` | Статус SMTP (настроен / нет) |
| `POST` | `/api/smtp/configure` | Сохранить SMTP-реквизиты |
| `POST` | `/api/rfq/send-with-file` | Отправить КП с вложением |

---

## 📁 Структура проекта

```
food_supplier_service/
├── backend/
│   ├── app/
│   │   ├── main.py              # FastAPI роутеры и эндпоинты
│   │   ├── models.py            # SQLAlchemy модели (Supplier, PriceItem, ...)
│   │   ├── schemas.py           # Pydantic схемы
│   │   ├── price_analyzer.py    # Парсер прайс-листов (Excel / PDF)
│   │   ├── discovery.py         # AI-поиск поставщиков через Tavily
│   │   └── services/
│   │       └── rfq_service.py   # Отправка email (SMTP + вложения)
│   ├── .env.example
│   ├── requirements.txt
│   └── Dockerfile
├── frontend/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/
│   │   │   └── supplier.dart    # Модели данных (Supplier, PriceItem)
│   │   ├── screens/
│   │   │   ├── supplier_list_screen.dart   # Главный экран + SMTP кнопка
│   │   │   ├── supplier_detail_screen.dart # Карточка + КП + прайс
│   │   │   ├── add_supplier_screen.dart
│   │   │   └── compare_suppliers_screen.dart
│   │   ├── services/
│   │   │   ├── api_service.dart
│   │   │   ├── theme_service.dart
│   │   │   └── localization_service.dart
│   │   └── widgets/
│   │       └── dino_game.dart   # Easter egg 🦕
│   └── Dockerfile
└── docker-compose.yml
```

---

## 🔄 Как работает поиск поставщиков

```
Пользователь вводит категорию + город
         ↓
Tavily API → топ-10 релевантных сайтов
         ↓
Deep Parsing (httpx + BeautifulSoup)
  → страницы «Контакты», «О компании», «Сертификаты»
  → регулярки: телефоны, email, ИНН
         ↓
Верификация ФНС (DaData)
  → статус компании, дата регистрации, директор
         ↓
Скоринг (0–100 баллов)
  → верификация ФНС: +30
  → сертификаты (ГОСТ, Халяль): +15
  → корпоративный email: +10
  → наличие доставки: +10
  → срок работы > 5 лет: +10
         ↓
Сохранение в PostgreSQL + кэш Redis 1ч
```

---

## 📧 Настройка SMTP (отправка КП)

1. Нажмите кнопку **«Настроить SMTP»** в шапке приложения
2. Введите реквизиты вашего почтового ящика

**Gmail:**
- Включите двухфакторную аутентификацию
- Безопасность → Пароли приложений → создайте пароль
- Используйте этот пароль (не основной) в настройках

**Яндекс:** Настройки → Безопасность → Пароли приложений

**Mail.ru:** `smtp.mail.ru`, порт `587`

После настройки — откройте карточку поставщика с email и нажмите **«Написать»**.

---

## 🤝 Контрибуция

```bash
git checkout -b feature/your-feature
# ... изменения ...
git commit -m "feat: описание"
git push origin feature/your-feature
```

---

<div align="center">
Разработано для нужд отдела снабжения · 2025
</div>
