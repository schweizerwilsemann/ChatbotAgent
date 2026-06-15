# Sports Venue AI Chatbot

AI Agent chatbot cho quán bida / pickleball / cau long.
Tich hop Knowledge Graph (Neo4j) + Tool Calling + Mobile App (Flutter).
Super App voi Mini App (WebView) va Partner F&B system.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Setup Guide](#setup-guide)
  - [Prerequisites](#prerequisites)
  - [Backend Setup](#backend-setup)
  - [Ollama Setup (Local LLM)](#ollama-setup-local-llm)
  - [Neo4j AuraDB Setup](#neo4j-auradb-setup)
  - [PostgreSQL Setup](#postgresql-setup)
  - [Redis Setup](#redis-setup)
  - [Flutter Setup](#flutter-setup)
- [Knowledge Base](#knowledge-base)
- [API Reference](#api-reference)
- [Features](#features)
- [Super App & Mini Apps](#super-app--mini-apps)
- [Partner F&B System](#partner-fb-system)
- [Running the Application](#running-the-application)
- [Demo Accounts](#demo-accounts)
- [Troubleshooting](#troubleshooting)

---

## Architecture Overview

```
+-------------------------------------+
|           Flutter App               |  Presentation Layer
|  (Chat UI, Booking, Menu, Auth)     |
|  (Staff Chat, Staff Requests)       |
|  (Payment: Stripe/VNPay SDK)        |
|  (Explore: Mini Apps via WebView)   |
|  (Partner Shell: CRUD menu/orders)  |
+--------------+----------------------+
               | HTTP / WebSocket
+--------------v----------------------+
|    FastAPI Backend Monolith         |  Application Layer
|  /chat /booking /order /staff       |
|  /payment /stripe /realtime         |
|  /staff/chat /staff/requests        |
|  /partner (stores, menu, orders)    |
+---+---------------------------+-----+
    |                           |
+---v-----------+   +-----------v---------+
|  AI Agent     |   | Payment Module      |  Domain Layer
|  LangChain    |   |  Stripe SDK         |
|  Tool Call    |   |  VNPay prototype*   |
+---+-----------+   +-----------+---------+
    |                           |
+---v---------------------------v---------+
|         Infrastructure Layer            |
|       PostgreSQL | Neo4j | Redis        |
+-----------------------------------------+
* Java/VNPay chi la prototype nghien cuu, chua co merchant credentials.
```

---

## Tech Stack

| Layer | Technology | Version |
|---|---|---|
| Mobile App | Flutter (iOS + Android) | Dart 3.1+ |
| Backend API | Python - FastAPI | 0.115+ |
| AI Agent | LangChain + Ollama | langchain 0.3.1 |
| LLM (Local) | Ollama - qwen2.5-coder:7b | 7B params |
| LLM (Cloud) | Google Gemini / Anthropic Claude | Optional fallback |
| Knowledge Graph | Neo4j AuraDB (free cloud) | 5.x |
| Database | PostgreSQL | 14+ |
| Cache & Pub/Sub | Redis | 7+ |
| Payment (International) | Stripe + flutter_stripe | ^11.0.0 |
| Payment (Domestic) | VNPay prototype | Chua kiem thu sandbox |
| Real-time | WebSocket (web_socket_channel) | 3.0.3 |
| Data Scraping | BeautifulSoup, yt-dlp, pdfplumber | - |

---

## Project Structure

```
ChatbotAgent/
|
+-- README.md
+-- backend/
|   +-- main.py                        # FastAPI entry point
|   +-- requirements.txt
|   +-- .env / .env.example
|   +-- app/
|   |   +-- api/                       # FastAPI routers (15 modules)
|   |   |   +-- auth.py                # Authentication
|   |   |   +-- chat.py                # AI Chat
|   |   |   +-- booking.py             # Booking + Bill
|   |   |   +-- order.py               # F&B Order
|   |   |   +-- menu.py                # Menu
|   |   |   +-- staff.py               # Staff notify
|   |   |   +-- staff_request.py       # Staff request management
|   |   |   +-- staff_chat.py          # Staff-customer real-time chat
|   |   |   +-- realtime.py            # WebSocket notifications
|   |   |   +-- payment.py             # VNPay payment
|   |   |   +-- stripe.py              # Stripe payment
|   |   |   +-- admin.py               # Admin management
|   |   |   +-- venue.py               # Venue/resource
|   |   |   +-- partner.py             # Partner F&B system (NEW)
|   |   |
|   |   +-- agent/                     # AI Agent core
|   |   |   +-- agent.py               # VenueAgent (LangChain)
|   |   |   +-- prompts.py             # System prompts (Vietnamese)
|   |   |   +-- tools/
|   |   |       +-- book_court.py
|   |   |       +-- order_food.py
|   |   |       +-- call_staff.py
|   |   |       +-- query_faq.py
|   |   |       +-- check_schedule.py
|   |   |       +-- order_menu_items.py
|   |   |
|   |   +-- models/                    # SQLAlchemy models
|   |   |   +-- user.py, booking.py, order.py
|   |   |   +-- menu.py, venue.py, payment.py
|   |   |   +-- staff_request.py, notification.py
|   |   |   +-- camera.py, partner.py  # Partner models (NEW)
|   |   |
|   |   +-- schemas/                   # Pydantic schemas
|   |   |   +-- ..., partner.py        # Partner schemas (NEW)
|   |   +-- services/                  # Business logic
|   |   +-- repositories/              # DB access layer
|   |   +-- core/
|   |       +-- config.py, database.py
|   |       +-- neo4j_client.py, redis_client.py
|   |       +-- seed.py                # Seed data (incl. partners)
|   |
|   +-- data_pipeline/                 # KG build pipeline
|   +-- Dockerfile
|
+-- flutter_app/
|   +-- pubspec.yaml
|   +-- assets/
|   |   +-- mini_apps/                 # Mini App HTML/CSS/JS (NEW)
|   |       +-- mini_game.html         # Sport Reflex game
|   |       +-- fnb_partner.html       # F&B partner ordering
|   |       +-- coach_booking.html     # Coach/trainer booking
|   +-- lib/
|       +-- main.dart
|       +-- core/                      # Constants, theme, network, router
|       +-- features/                  # 17 feature modules
|       |   +-- chat/                  # Chat with AI
|       |   +-- booking/               # Court booking + billing
|       |   +-- menu/                  # Food & drink ordering
|       |   +-- auth/                  # Login/register
|       |   +-- payment/               # Stripe/VNPay payment
|       |   +-- staff/                 # Staff notifications
|       |   +-- staff_chat/            # Staff-customer chat
|       |   +-- staff_request/         # Staff request management
|       |   +-- admin/                 # Admin panel
|       |   +-- billing/               # Customer billing
|       |   +-- profile/               # User profile
|       |   +-- venue/                 # Venue selection
|       |   +-- explore/               # Explore tab + Mini Apps (NEW)
|       |   +-- partner/               # Partner shell + CRUD (NEW)
|       |   +-- camera/                # Camera monitoring
|       |   +-- call/                  # WebRTC voice call
|       |   +-- settings/              # App settings
|       |   +-- shared/                # Shared widgets
|       +-- shared/
|
+-- docker-compose.yml
+-- proto/                             # gRPC definitions
```

---

## Setup Guide

### Prerequisites

- Python 3.10+
- Flutter 3.1+ (for mobile app)
- PostgreSQL 14+ (running in WSL or natively)
- Redis 7+ (running in WSL or natively)
- Ollama (for local LLM)
- Neo4j AuraDB account (free tier)

### Backend Setup

```bash
cd ChatbotAgent/backend
python -m venv venv
source venv/bin/activate        # Linux/Mac
# venv\Scripts\activate         # Windows
pip install -r requirements.txt
cp .env.example .env
# Edit .env with your actual values
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### Ollama Setup (Local LLM)

```bash
# Install Ollama from https://ollama.ai
ollama pull qwen2.5-coder:7b
ollama pull nomic-embed-text
ollama list
```

### Neo4j AuraDB Setup

1. Go to https://neo4j.com/cloud/aura-free/
2. Create a free instance
3. Add connection details to `.env`

```env
NEO4J_URI=neo4j+s://your-instance.databases.neo4j.io
NEO4J_USERNAME=your-username
NEO4J_PASSWORD=your-password
NEO4J_DATABASE=your-database-name
```

### PostgreSQL Setup

```bash
# In WSL:
sudo apt update && sudo apt install postgresql postgresql-contrib
sudo systemctl start postgresql
sudo -u postgres psql
CREATE DATABASE sports_venue;
\q
```

```env
DATABASE_URL=postgresql+asyncpg://postgres:your_password@localhost:5432/sports_venue
```

**Tables auto-created on startup:**
- `users` - customer/staff/admin/partner accounts
- `bookings` - court bookings with payment_status
- `orders` - F&B orders with booking_id FK
- `order_items` - individual items
- `venues`, `service_resources` - venue & court management
- `cameras` - IP camera configuration with RTSP credentials
- `staff_assignments` - staff access control (venue/area/resource scope)
- `menu_items` - food/drink menu (venue internal)
- `payments` - payment transactions (Stripe/VNPay)
- `staff_requests` - customer support requests
- `notifications` - real-time notification records
- `partner_stores` - partner F&B store profiles (NEW)
- `partner_menu_items` - partner menu items (NEW)
- `partner_orders` - customer orders from partners (NEW)
- `partner_order_items` - individual items in partner orders (NEW)

### Redis Setup

```bash
sudo apt install redis-server
sudo systemctl start redis-server
redis-cli ping  # Should return: PONG
```

```env
REDIS_URL=redis://localhost:6379
```

**Used for:**
- Chat session storage (conversation history with TTL)
- Staff notifications pub/sub
- Staff chat rooms (ephemeral, Redis-only)
- Presence tracking for chat participants
- Caching

### Flutter Setup

```bash
cd ChatbotAgent/flutter_app
flutter pub get
flutter run build_runner build --delete-conflicting-outputs
flutter run
```

**Key Dependencies:** Riverpod (state), GoRouter (navigation), Dio (HTTP), flutter_chat_ui (chat), flutter_stripe (payment), web_socket_channel (real-time)

---

## Knowledge Base

### Data Sources

All knowledge files in `backend/data_pipeline/raw_data/`:

| Sport | Content | Files |
|-------|---------|-------|
| Billiards | WPA rules, diamond system, techniques | 5 files |
| Pickleball | USAPA rules, techniques, full rulebook | 3 files |
| Badminton | BWF laws, techniques | 2 files |

### Knowledge Graph Schema

**Node types:** Rule, Technique, Equipment, Sport, Concept, GameType
**Relationships:** DUNG_DE, LIEN_QUAN, LA_LOAI, THUOC, SU_DUNG, QUY_DINH

**Stats:** 418 entities, 441 relationships, full-text and vector search indexes

Khi backend khoi dong, mot background task chi tao lai embedding cho node bi
thieu hoac da stale do doi model/noi dung. Cac node hien tai da co 418/418
embedding; lan khoi dong tiep theo khong nhung lai toan bo. `IntentRouter`
cung luu cac vector mau vao Redis trong 7 ngay de tranh tao lai hang tram
request Ollama sau moi lan restart.

Truy van `query_knowledge` la Graph RAG: full-text va vector search duoc hop
nhat bang RRF, sau do mo rong quan he Neo4j 1-2 buoc. Neu Ollama/vector index
khong san sang, he thong van fallback ve full-text va keyword. Model
`nomic-embed-text` da hoat dong ve mat ky thuat, nhung chat luong ngu nghia
tieng Viet chua duoc benchmark va chua nen duoc xem la toi uu.

---

## API Reference

### Endpoints (80+ REST + 2 WebSocket)

| Group | Endpoints | Description |
|-------|-----------|-------------|
| Auth | 4 | Login, verify, change password, profile |
| Chat | 1 | AI chat with tool calling |
| Booking | 10 | CRUD, availability, active, bills |
| Order | 4 | CRUD with booking linking |
| Menu | 3 | List, top-selling, suggest |
| Staff Notify | 1 | Send notification to staff |
| Staff Request | 7 | Create, accept, complete, cancel, active |
| Staff Chat | 4 | Rooms, history, close, WebSocket |
| Realtime | 4 | WebSocket notifications, list, mark read |
| VNPay Payment | 3 | Create, callback, query |
| Stripe Payment | 6 | PaymentIntent, checkout, webhook, config |
| Admin | 15 | Dashboard, bookings, orders, menu, analytics, cameras |
| Venue | 8+ | CRUD venues, resources, staff assignments, cameras |
| **Partner** | **12** | **Store CRUD, menu CRUD, order management (NEW)** |

### Key API Groups

**Staff Request APIs:**
| Method | Path | Description |
|--------|------|-------------|
| POST | /api/staff/requests | Create support request |
| GET | /api/staff/requests/mine | Get my requests |
| GET | /api/staff/requests/pending | Get pending requests |
| GET | /api/staff/requests/active | Get pending + accepted |
| PATCH | /api/staff/requests/{id}/accept | Accept request |
| PATCH | /api/staff/requests/{id}/complete | Complete request |
| PATCH | /api/staff/requests/{id}/cancel | Cancel request |

**Staff Chat APIs:**
| Method | Path | Description |
|--------|------|-------------|
| GET | /api/staff/chat/rooms | List chat rooms |
| GET | /api/staff/chat/{id}/history | Chat message history |
| POST | /api/staff/chat/{id}/close | Close chat room |
| WS | /api/staff/chat/{id}/ws | Real-time chat WebSocket |

**Realtime Notification APIs:**
| Method | Path | Description |
|--------|------|-------------|
| WS | /api/realtime/notifications | WebSocket for push notifications |
| GET | /api/realtime/notifications | List notifications (paginated) |
| PATCH | /api/realtime/notifications/{id}/read | Mark as read |
| PATCH | /api/realtime/notifications/read-all | Mark all as read |

**Stripe Payment APIs:**
| Method | Path | Description |
|--------|------|-------------|
| POST | /api/stripe/create-payment-intent | Create PaymentIntent (native) |
| POST | /api/stripe/create-checkout | Create Checkout Session (legacy) |
| POST | /api/stripe/webhook | Stripe webhook handler |
| GET | /api/stripe/config | Get publishable key |

**Booking Bill APIs:**
| Method | Path | Description |
|--------|------|-------------|
| GET | /api/booking/bills | List all booking bills |
| GET | /api/booking/{id}/bill | Get bill for specific booking |
| GET | /api/admin/bookings/{id}/bill | Admin view booking bill |

**Partner APIs (NEW):**
| Method | Path | Description |
|--------|------|-------------|
| GET | /api/partner/me/store | Get partner's own store |
| PATCH | /api/partner/me/store | Update store info |
| GET | /api/partner/me/menu | List own menu items |
| POST | /api/partner/me/menu | Add menu item |
| PATCH | /api/partner/me/menu/{id} | Update menu item |
| DELETE | /api/partner/me/menu/{id} | Delete menu item |
| GET | /api/partner/me/orders | List store orders |
| PATCH | /api/partner/me/orders/{id}/status | Update order status |
| GET | /api/partner/stores | List active stores (public) |
| GET | /api/partner/stores/{id}/menu | Get store menu (public) |
| POST | /api/partner/orders | Create order (customer) |

### Agent Tools

| Tool | Trigger | Action |
|------|---------|--------|
| query_knowledge | Hoi luat, ky thuat | Hybrid full-text/vector, RRF, graph expansion 1-2 hops |
| book_court | Dat san | Check availability, insert PostgreSQL |
| order_food | Goi do | Insert order, link to active booking |
| call_staff | Goi nhan vien | Create staff request, notify via WebSocket |
| check_schedule | Xem lich | Query bookings by date |
| order_menu_items | Dat mon | Order from menu with booking association |

---

## Features

### Core Features
- AI Chat with Knowledge Graph (Graph RAG)
- Court booking with real-time availability
- F&B ordering with menu management
- Staff request system (create, accept, complete, cancel)
- Real-time WebSocket notifications for all roles

### Payment Features
- Stripe native PaymentIntent (flutter_stripe)
- VNPay native SDK (Method Channel)
- Booking bill aggregation (court fees + food orders)
- Payment status tracking on orders and bookings

### Staff Features
- Staff-customer real-time chat (ephemeral, Redis-backed)
- Staff request management screen
- Notification inbox with unread badge
- Room-scoped WebSocket for chat
- **Camera monitoring** - View RTSP camera feeds for assigned courts

### Admin Features
- Dashboard with analytics
- Booking/order management
- Menu CRUD (ADMIN only)
- Revenue statistics
- **Resource management** - Add/edit courts, toggle status (active/maintenance/inactive)
- **Camera management** - CRUD camera IP, assign cameras to courts
- **Staff assignment** - Assign staff to venues/areas/resources with scope-based access

### Explore & Mini App Features (New)
- **Explore tab** - Discovery page for mini apps (Customer + Staff)
- **Mini apps via WebView** - HTML/CSS/JS apps embedded in Flutter
- **Sport Reflex game** - Tap game for waiting time
- **F&B Partner ordering** - Order from external partners, delivered to court
- **Coach booking** - Book personal trainers by the hour
- **Data injection** - Flutter fetches API, injects into WebView via JS

### Partner Features (New)
- **Partner role** - New user role with scoped access
- **Partner shell** - Dashboard, menu management, order management
- **Menu CRUD** - Partners add/edit/delete their own products
- **Order lifecycle** - pending → accepted → preparing → ready → delivering → delivered
- **Public API** - Stores and menus accessible without auth (for mini app)
- **Scoped access** - Partners only see their own store data

### Camera System (New)
- RTSP camera integration (Hikvision, Dahua, Seetong, FPT)
- Admin: Configure camera (IP, port, credentials, brand)
- Admin: Assign camera to specific court/table
- Staff: View camera grid with thumbnail preview
- Staff: Tap to open full-screen RTSP live stream
- Venue-scoped access control (admin/staff only see their venue's cameras)

### Resource Management (New)
- Admin: View all courts/tables with status
- Filter by status: Active / Maintenance / Inactive
- Quick toggle: Activate / Maintenance / Disable
- Display: court name, area, code, hourly rate
- Status affects booking availability (maintenance/inactive = not bookable)

---

## Super App & Mini Apps

### Concept

App Flutter đóng vai trò "Super App" — nhúng các mini app HTML/CSS/JS chạy trong WebView. Không cần update app khi thêm mini app mới.

### Mini Apps (HTML/CSS/JS)

| Mini App | File | Mô tả |
|----------|------|-------|
| Sport Reflex | `mini_game.html` | Game tap target 30s, combo system, leaderboard |
| F&B Partner | `fnb_partner.html` | Đặt đồ từ đối tác, fetch từ API |
| Coach Booking | `coach_booking.html` | Đặt HLV cá nhân theo giờ |

### Architecture

```
Flutter App (Super App Shell)
    ├── Tab "Khám phá" (ExploreScreen)
    │   ├── Grid mini apps
    │   └── Tap → MiniAppWebViewScreen
    │       └── WebView load asset HTML
    │           ├── Flutter inject data via runJavaScript()
    │           └── HTML sends events via JavaScriptChannel
    └── Admin có thể disable explore từ dashboard
```

### Communication Flow

```
1. Flutter loads HTML: loadFlutterAsset('assets/mini_apps/fnb_partner.html')
2. onPageFinished → Flutter fetches API → runJavaScript('loadStores(...)')
3. User taps "Đặt hàng" → JS: PartnerBridge.postMessage(JSON.stringify({...}))
4. Flutter receives → POST /api/partner/orders → runJavaScript('onOrderSuccess(...)')
```

---

## Partner F&B System

### Concept

Đối tác F&B (quán nước, quán ăn nhỏ) đăng ký qua hệ thống. Họ dùng chính app Flutter để quản lý cửa hàng, menu, và nhận đơn. Không cần API riêng.

### Roles

| Role | Phone | Tính năng |
|------|-------|-----------|
| CUSTOMER | `0900000000` | Đặt sân, đặt đồ, chat AI, khám phá mini apps |
| STAFF | `0111111112` | Quản lý booking, yêu cầu, menu venue, camera |
| ADMIN | `0111111111` | Dashboard, quản lý toàn bộ, cấu hình |
| **PARTNER** | `0911111111` | **Quản lý cửa hàng, menu, nhận đơn (NEW)** |

### Partner Flow

```
1. Admin tạo tài khoản PARTNER (gán venue)
2. Partner login → PartnerShell (3 tabs: Dashboard, Menu, Đơn hàng)
3. Partner CRUD menu items (tên, giá, mô tả, trạng thái)
4. Khách đặt hàng qua mini app → Partner nhận notification
5. Partner xác nhận → chuẩn bị → giao → hoàn tất
```

### Seed Partner Stores

| Store | Owner | Phone | Category | Items |
|-------|-------|-------|----------|-------|
| Trà Sữa Mèo | Chủ Trà Sữa Mèo | `0911111111` | drink | 6 món (15k-38k) |
| Cơm Gà 123 | Chủ Cơm Gà 123 | `0922222222` | food | 6 món (10k-55k) |
| Bánh Mì Ngon | Chủ Bánh Mì Ngon | `0933333333` | food | 6 món (5k-25k) |

### Menu nội bộ vs Đối tác

| | Menu nội bộ (tab Dịch vụ) | F&B Partner (mini app) |
|---|---|---|
| Ai bán | Chính venue tự phục vụ | Đối tác bên ngoài |
| Giao ai | Staff venue giao tại bàn | Nhân viên đối tác giao đến sân |
| Menu | Cà phê, nước suối, đồ ăn vặt | Trà sữa, cơm gà, bánh mì... |
| Payment | Qua hệ thống venue | Qua hệ thống partner |

---

## Running the Application

```bash
# Terminal 1 - Redis (in WSL)
sudo systemctl start redis-server

# Terminal 2 - PostgreSQL (in WSL)
sudo systemctl start postgresql

# Terminal 3 - Ollama
ollama serve

# Terminal 4 - Backend
cd ChatbotAgent/backend
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload

# Terminal 5 - Flutter
cd ChatbotAgent/flutter_app
flutter run
```

### Verify

```bash
curl http://localhost:8000/health
# -> {"status": "ok", "env": "development"}

# Swagger UI: http://localhost:8000/docs
```

---

## Demo Accounts

Seed data tao san 3 venue theo loai san, moi venue co admin + staff rieng.

| Vai tro | Ten | So dien thoai | Mat khau | Venue |
|---------|-----|---------------|-----------|-------|
| Admin Bida | Quan ly Bida | `0111111111` | `123456` | CLB Bida Sai Gon |
| Staff Bida | NV Bida | `0111111112` | `123456` | CLB Bida Sai Gon |
| Admin Pickleball | Quan ly Pickleball | `0222222222` | `123456` | San Pickleball Thu Duc |
| Staff Pickleball | NV Pickleball | `0222222223` | `123456` | San Pickleball Thu Duc |
| Admin Cau long | Quan ly Cau long | `0333333333` | `123456` | Nha thi dau Cau long Binh Thanh |
| Staff Cau long | NV Cau long | `0333333334` | `123456` | Nha thi dau Cau long Binh Thanh |
| Khach hang | Khach hang | `0900000000` | `123456` | (mac dinh: CLB Bida) |
| **Partner Tra sua** | **Chu Tra Sua Meo** | `0911111111` | `123456` | **CLB Bida SG (NEW)** |
| **Partner Com ga** | **Chu Com Ga 123** | `0922222222` | `123456` | **CLB Bida SG (NEW)** |
| **Partner Banh mi** | **Chu Banh Mi Ngon** | `0933333333` | `123456` | **CLB Bida SG (NEW)** |

**Seed data:**
- CLB Bida Sai Gon - 8 ban bida (B01-B08)
- San Pickleball Thu Duc - 6 san pickleball (P01-P06)
- Nha thi dau Cau long Binh Thanh - 6 san cau long (C01-C06)
- 3 partner stores voi 18 menu items (NEW)

Staff chi thay request tu venue minh duoc assign. Khach goi nhan vien se tu dong detect tu booking dang active.

---

## Troubleshooting

### Gemini API 429 (Rate Limit)
Use Ollama instead: set `LLM_PROVIDER=ollama` in `.env`

### LangChain Import Errors
```bash
pip install langchain==0.3.1 langchain-core==0.3.63 langchain-ollama==0.2.3
```

### Neo4j Connection Failed
Check `NEO4J_URI` uses `neo4j+s://` scheme. Free tier pauses after 3 days inactivity.

### PostgreSQL Connection Refused
Ensure PostgreSQL is running: `sudo systemctl status postgresql`

### Redis Connection Refused
Ensure Redis is running: `sudo systemctl status redis-server`

---

## .env.example

```env
# AI - Ollama (local, free, recommended)
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=qwen2.5-coder:7b
LLM_PROVIDER=ollama

# AI - Gemini (cloud fallback)
GEMINI_API_KEY=your_key_here

# Neo4j AuraDB
NEO4J_URI=neo4j+s://xxxxxxxx.databases.neo4j.io
NEO4J_USERNAME=neo4j
NEO4J_PASSWORD=your_password
NEO4J_DATABASE=neo4j

# PostgreSQL
DATABASE_URL=postgresql+asyncpg://postgres:password@localhost:5432/sports_venue

# Redis
REDIS_URL=redis://localhost:6379

# Knowledge Graph embeddings
EMBEDDING_API_URL=http://localhost:11434/api/embeddings
EMBEDDING_MODEL=nomic-embed-text
KG_AUTO_EMBED_ON_STARTUP=true
KG_AUTO_EMBED_MAX_NODES=500

# Stripe
STRIPE_SECRET_KEY=sk_test_xxx
STRIPE_PUBLISHABLE_KEY=pk_test_xxx
STRIPE_WEBHOOK_SECRET=whsec_xxx

# VNPay
VNPAY_TMN_CODE=your_tmn_code
VNPAY_HASH_SECRET=your_hash_secret
VNPAY_URL=https://sandbox.vnpayment.vn/paymentv2/vpcpay.html
VNPAY_RETURN_URL=http://localhost:8000/api/payment/callback

# App
APP_ENV=development
SECRET_KEY=your_secret_key
```

---

## License

Academic project - Sports Venue AI Chatbot.
