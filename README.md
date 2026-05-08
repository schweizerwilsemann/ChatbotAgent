# 🎱 Sports Venue AI Chatbot

AI Agent chatbot cho quán bida / pickleball / cầu lông.  
Tích hợp Knowledge Graph (Neo4j) + Tool Calling + Mobile App (Flutter).

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
  - [Raw Data Sources](#raw-data-sources)
  - [Data Pipeline](#data-pipeline)
  - [Knowledge Graph Schema](#knowledge-graph-schema)
- [API Reference](#api-reference)
- [Running the Application](#running-the-application)
- [Troubleshooting](#troubleshooting)

---

## Architecture Overview

```
┌─────────────────────────────────────┐
│           Flutter App               │  Presentation Layer
│  (Chat UI, Booking, Menu, Auth)     │
└──────────────┬──────────────────────┘
               │ HTTP / WebSocket
┌──────────────▼──────────────────────┐
│          FastAPI Backend            │  Application Layer
│  /chat  /booking  /order  /staff    │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│           AI Agent Layer            │  Domain Layer
│  Intent → Tool Selection → Execute  │
│  Graph RAG (Neo4j) + Tool Calling   │
│  LLM: Ollama (qwen2.5-coder:7b)    │
└──────┬───────────────────┬──────────┘
       │                   │
┌──────▼──────┐    ┌───────▼─────────┐
│   Neo4j     │    │   PostgreSQL    │  Infrastructure Layer
│  Knowledge  │    │  booking/order  │
│   Graph     │    │   /user data    │
└─────────────┘    └─────────────────┘
```

---

## Tech Stack

| Layer | Technology | Version |
|---|---|---|
| Mobile App | Flutter (iOS + Android) | Dart 3.1+ |
| Backend API | Python — FastAPI | 0.115+ |
| AI Agent | LangChain + Ollama | langchain 0.3.1 |
| LLM (Local) | Ollama — qwen2.5-coder:7b | 7B params |
| LLM (Cloud) | Google Gemini / Anthropic Claude | Optional fallback |
| Knowledge Graph | Neo4j AuraDB (free cloud) | 5.x |
| Database | PostgreSQL | 14+ |
| Cache | Redis | 7+ |
| Data Scraping | BeautifulSoup, yt-dlp, pdfplumber | — |

---

## Project Structure

```
ChatbotAgent/
│
├── README.md                          ← You are here
├── backend/
│   ├── main.py                        # FastAPI entry point
│   ├── requirements.txt               # Python dependencies
│   ├── .env                           # Environment variables (gitignored)
│   ├── .env.example                   # Environment template
│   │
│   ├── app/
│   │   ├── api/                       # FastAPI routers
│   │   │   ├── chat.py                # POST /api/chat
│   │   │   ├── booking.py             # CRUD booking
│   │   │   ├── order.py               # CRUD F&B order
│   │   │   ├── menu.py                # GET /api/menu
│   │   │   └── staff.py               # POST /api/staff/notify
│   │   │
│   │   ├── agent/                     # AI Agent core
│   │   │   ├── agent.py               # Main agent loop (VenueAgent)
│   │   │   ├── prompts.py             # System prompts
│   │   │   └── tools/
│   │   │       ├── book_court.py      # Tool: đặt sân
│   │   │       ├── order_food.py      # Tool: gọi món
│   │   │       ├── call_staff.py      # Tool: gọi nhân viên
│   │   │       ├── query_faq.py       # Tool: tra cứu KG
│   │   │       └── check_schedule.py  # Tool: xem lịch
│   │   │
│   │   ├── kg/                        # Knowledge Graph
│   │   │   ├── builder.py             # LLM extract → Neo4j insert
│   │   │   ├── query.py               # Graph traversal / RAG
│   │   │   ├── embeddings.py          # Node embeddings
│   │   │   └── scraper/
│   │   │       ├── base_scraper.py    # Abstract base scraper
│   │   │       ├── wpa_scraper.py     # WPA billiards rules
│   │   │       ├── youtube_scraper.py # yt-dlp transcript
│   │   │       ├── pickleball_scraper.py
│   │   │       └── bwf_scraper.py     # BWF badminton
│   │   │
│   │   ├── models/                    # SQLAlchemy models
│   │   │   ├── base.py                # UUID + timestamp mixins
│   │   │   ├── booking.py             # Booking, CourtType, BookingStatus
│   │   │   ├── order.py               # Order, OrderItem, OrderStatus
│   │   │   └── user.py                # User, UserRole
│   │   │
│   │   ├── schemas/                   # Pydantic request/response
│   │   ├── services/                  # Business logic
│   │   ├── repositories/              # DB access layer
│   │   └── core/
│   │       ├── config.py              # Pydantic BaseSettings
│   │       ├── database.py            # Async SQLAlchemy
│   │       ├── neo4j_client.py        # Neo4j async driver
│   │       └── redis_client.py        # Redis async client
│   │
│   ├── data_pipeline/                 # Knowledge graph build pipeline
│   │   ├── 01_scrape.py               # Scrape data from web
│   │   ├── 02_extract_entities.py     # LLM entity extraction
│   │   ├── 03_build_graph.py          # Insert into Neo4j
│   │   ├── 04_embed_nodes.py          # Generate embeddings
│   │   ├── run_pipeline.py            # Master orchestrator
│   │   │
│   │   ├── raw_data/                  # Source knowledge files
│   │   │   ├── billiards/             # Pool & carom knowledge
│   │   │   ├── pickleball/            # Pickleball knowledge
│   │   │   ├── badminton/             # Badminton knowledge
│   │   │   └── venue/                 # Venue-specific (manual input)
│   │   │
│   │   └── extracted/                 # LLM-extracted entities (JSON)
│   │
│   └── tests/
│
└── flutter_app/
    ├── pubspec.yaml
    └── lib/
        ├── main.dart
        ├── core/                      # Constants, theme, network, router
        ├── features/
        │   ├── chat/                  # Chat with AI
        │   ├── booking/               # Court booking
        │   ├── menu/                  # Food & drink ordering
        │   └── auth/                  # Login
        └── shared/                    # Widgets, utils
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
# 1. Navigate to backend
cd ChatbotAgent/backend

# 2. Create virtual environment
python -m venv venv
source venv/bin/activate        # Linux/Mac
# venv\Scripts\activate         # Windows

# 3. Install dependencies
pip install -r requirements.txt

# 4. Copy and edit environment file
cp .env.example .env
# Edit .env with your actual values (see below)

# 5. Start the server
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### Ollama Setup (Local LLM)

Ollama runs LLMs locally on your machine — no API key needed, no rate limits, fully private.

```bash
# 1. Install Ollama
# Windows: Download from https://ollama.ai
# Linux:   curl -fsSL https://ollama.ai/install.sh | sh

# 2. Pull the model used by this project
ollama pull qwen2.5-coder:7b

# 3. Verify it's running
ollama list
# Should show: qwen2.5-coder:7b

# 4. Test it
curl http://localhost:11434/api/tags
```

**Model used:** `qwen2.5-coder:7b` (4.7 GB)  
- Good at structured JSON output for entity extraction
- Runs on CPU (no GPU required, but slower)
- Each extraction chunk takes ~60 seconds on CPU

**Alternative models** (if you want faster/higher quality):
```bash
ollama pull qwen2.5:14b        # Better quality, needs 16GB+ RAM
ollama pull llama3.1:8b        # Good alternative
ollama pull mistral:7b         # Fast
```

Update `OLLAMA_MODEL` in `.env` if you switch models.

### Neo4j AuraDB Setup

Neo4j AuraDB is the cloud-hosted knowledge graph database.

```
# 1. Go to https://neo4j.com/cloud/aura-free/
# 2. Create a free instance
# 3. Note down the connection details:
#    - URI:      neo4j+s://xxxxxxxx.databases.neo4j.io
#    - Username: neo4j (or instance ID)
#    - Password: (set during creation)
# 4. Add to .env:
```

```env
NEO4J_URI=neo4j+s://your-instance.databases.neo4j.io
NEO4J_USERNAME=your-username
NEO4J_PASSWORD=your-password
NEO4J_DATABASE=your-database-name
```

**Current instance:**
- Instance ID: `fe8ca00f`
- URI: `neo4j+s://fe8ca00f.databases.neo4j.io`

**What's in the graph:**
- 418 entity nodes (Rule, Technique, Equipment, Sport, Concept, GameType)
- 441 relationships (DUNG_DE, LIEN_QUAN, LA_LOAI, THUOC, SU_DUNG, QUY_DINH)
- Full-text search index on entity names and descriptions

### PostgreSQL Setup

```bash
# In WSL (Ubuntu/Debian):
sudo apt update && sudo apt install postgresql postgresql-contrib
sudo systemctl start postgresql

# Create database
sudo -u postgres psql
CREATE DATABASE sports_venue;
\q

# Or if database already exists, just verify:
sudo -u postgres psql -c "SELECT 1 FROM pg_database WHERE datname='sports_venue'"
```

```env
# .env
DATABASE_URL=postgresql+asyncpg://postgres:your_password@localhost:5432/sports_venue
```

**Tables auto-created on startup:**
- `bookings` — court bookings (user_id, court_type, start/end time, status)
- `orders` — food/drink orders (user_id, items JSON, total_price, status)
- `order_items` — individual items in an order
- `users` — customer accounts (phone, name, email, role)

**Enums:**
- `court_type_enum`: billiards, pickleball, badminton
- `booking_status_enum`: confirmed, cancelled, completed
- `order_status_enum`: pending, preparing, ready, delivered, cancelled
- `user_role_enum`: CUSTOMER, STAFF, ADMIN

### Redis Setup

```bash
# In WSL:
sudo apt update && sudo apt install redis-server
sudo systemctl start redis-server

# Verify:
redis-cli ping
# Should return: PONG
```

```env
# .env
REDIS_URL=redis://localhost:6379
```

**Used for:**
- Chat session storage (conversation history with TTL)
- Staff notifications (pub/sub)
- Caching

### Flutter Setup

```bash
cd ChatbotAgent/flutter_app

# Generate platform directories (first time only)
flutter create . --org com.sportsvenue

# Install dependencies
flutter pub get

# Generate code (JSON serialization, etc.)
flutter run build_runner build --delete-conflicting-outputs

# Run on connected device/emulator
flutter run
```

**Dependencies:** Riverpod (state), GoRouter (navigation), Dio (HTTP), flutter_chat_ui (chat)

---

## Knowledge Base

### Raw Data Sources

All knowledge files are in `backend/data_pipeline/raw_data/`:

| File | Sport | Content | Words |
|------|-------|---------|-------|
| `billiards/wpa_rules.txt` | Billiards | WPA 8-ball, 9-ball, 10-ball, 3-cushion rules | ~2,500 |
| `billiards/diamond_system.txt` | Billiards | Diamond system deep-dive (plus 2, plus 3) | ~2,000 |
| `billiards/three_cushion_techniques.txt` | Billiards | 3-cushion techniques, strategy, safety | ~1,800 |
| `billiards/youtube_techniques.txt` | Billiards | Vietnamese technique summaries | ~1,500 |
| `pickleball/usapa_rules.txt` | Pickleball | USA Pickleball official rules | ~2,500 |
| `pickleball/USAP-Official-Rulebook.txt` | Pickleball | Full rulebook (96 pages, PDF extracted) | ~145K chars |
| `pickleball/techniques.txt` | Pickleball | Dinking, third shot, Erne, stacking | ~2,400 |
| `badminton/bwf_rules.txt` | Badminton | BWF laws of badminton | ~2,000 |
| `badminton/techniques.txt` | Badminton | Grip, footwork, smash, net play, doubles | ~2,400 |
| `venue/menu_placeholder.txt` | Venue | Menu template (needs manual input) | — |
| `venue/court_schedule_placeholder.txt` | Venue | Schedule template (needs manual input) | — |
| `venue/pricing_placeholder.txt` | Venue | Pricing template (needs manual input) | — |
| `billiards/local_rules_billiard_lo.txt` | Venue | Local pool rules (needs manual input) | — |
| `billiards/local_rules_billiard_phang.txt` | Venue | Local carom rules (needs manual input) | — |

**Data format:** Files use `[SECTION: ...]` and `[TOPIC: ...]` headers with `---` separators, designed for LLM entity extraction.

### Data Pipeline

The pipeline transforms raw text files into a Neo4j knowledge graph:

```
Step 1: Scrape / Collect
    Web scraping (BeautifulSoup), PDF extraction (pdfplumber),
    YouTube transcripts (yt-dlp), manual input
    → raw_data/*.txt

Step 2: Extract Entities (LLM)
    Each .txt file is parsed into chunks by [SECTION:]/[TOPIC:] headers.
    Each chunk is sent to the LLM (Ollama qwen2.5-coder:7b) with a prompt
    to extract entities and relationships as JSON.
    → extracted/*.json

Step 3: Build Graph
    Deduplicate entities across all files.
    Create constraints, indexes, and fulltext search in Neo4j.
    Insert all entities as nodes and relationships as edges.
    → Neo4j database

Step 4: Embed Nodes (Optional)
    Generate vector embeddings for entity names + descriptions.
    Store as node properties for hybrid search.
    → Neo4j node properties
```

**Running the pipeline:**

```bash
cd ChatbotAgent/backend

# Full pipeline (all steps)
python data_pipeline/02_extract_entities.py   # ~90 min with Ollama on CPU
python data_pipeline/03_build_graph.py        # ~1 min
python data_pipeline/04_embed_nodes.py        # Optional, needs embedding model
```

**Extraction results (completed):**

| Metric | Value |
|--------|-------|
| Files processed | 10 |
| Total chunks | 83 |
| Entities extracted | 563 |
| Relationships extracted | 464 |
| Unique entities (after dedup) | 418 |
| Unique relationships (after dedup) | 441 |
| Processing time | ~91 minutes |

### Knowledge Graph Schema

**Node types (labels):**

| Label | Description | Example |
|-------|-------------|---------|
| `Rule` | A specific rule or regulation | "8-Ball Break Rules" |
| `Technique` | A playing technique or skill | "Diamond System" |
| `Equipment` | Physical equipment | "Cue Stick", "Shuttlecock" |
| `Sport` | A sport name | "Billiards", "Pickleball" |
| `Concept` | General concept or strategy | "Safety Play" |
| `GameType` | A game variant | "8-Ball", "9-Ball", "Singles" |

**Relationship types:**

| Type | Meaning (Vietnamese) | Example |
|------|---------------------|---------|
| `DUNG_DE` | applies to / relevant for | Diamond System → DUNG_DE → 3-Cushion |
| `LIEN_QUAN` | related to | Smash → LIEN_QUAN → Jump |
| `LA_LOAI` | is a type of | 8-Ball → LA_LOAI → Pool |
| `THUOC` | belongs to | Kitchen Rule → THUOC → Pickleball |
| `SU_DUNG` | uses | Smash → SU_DUNG → Racket |
| `QUY_DINH` | regulates | WPA → QUY_DINH → 9-Ball |

**Querying the graph (Cypher examples):**

```cypher
-- Find all rules for billiards
MATCH (r:Rule)-[:THUOC]->(s:Sport {name: "Billiards"})
RETURN r.name, r.description

-- Find techniques related to the diamond system
MATCH (t:Technique {name: "Diamond System"})-[r]-(related)
RETURN t.name, type(r), related.name, labels(related)

-- Full-text search across all entities
CALL db.index.fulltext.queryNodes("entity_fulltext", "smash technique")
YIELD node, score
RETURN node.name, node.description, score
ORDER BY score DESC LIMIT 10

-- Find everything related to pickleball
MATCH (n)-[r]-(m)
WHERE n.name = "Pickleball" OR m.name = "Pickleball"
RETURN n.name, type(r), m.name
```

---

## API Reference

### Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/health` | Health check |
| `POST` | `/api/chat` | Chat with AI agent |
| `POST` | `/api/booking/` | Create booking |
| `GET` | `/api/booking/{id}` | Get booking by ID |
| `GET` | `/api/booking/user/{user_id}` | Get user's bookings |
| `PUT` | `/api/booking/{id}/cancel` | Cancel booking |
| `GET` | `/api/booking/available/` | Check availability |
| `POST` | `/api/order/` | Create order |
| `GET` | `/api/order/{id}` | Get order by ID |
| `PUT` | `/api/order/{id}/status` | Update order status |
| `GET` | `/api/menu/` | Get menu (VND prices) |
| `POST` | `/api/staff/notify` | Notify staff |

### Chat Request/Response

```json
// POST /api/chat
{
  "message": "Cho tôi biết kỹ thuật diamond system trong bida 3 băng",
  "session_id": "optional-session-id"
}

// Response
{
  "reply": "Diamond system là kỹ thuật tính góc...",
  "session_id": "abc-123",
  "tools_used": ["query_knowledge"]
}
```

### Agent Tools

| Tool | Trigger | Action |
|------|---------|--------|
| `query_knowledge` | Hỏi luật, kỹ thuật | Graph RAG → Neo4j fulltext search |
| `book_court` | Đặt sân | Check availability → insert PostgreSQL |
| `order_food` | Gọi đồ | Insert order → notify kitchen |
| `call_staff` | Gọi nhân viên | Redis pub/sub notification |
| `check_schedule` | Xem lịch | Query bookings by date |

### Demo Scenario

```
User: "Cho tôi biết kỹ thuật cule là gì rồi đặt sân bida lúc 7h tối mai"

Agent flow:
1. Detects two intents: query + booking
2. Calls query_knowledge → Neo4j search for "cule" → returns technique info
3. Calls book_court → checks availability → creates booking
4. Returns combined response with technique explanation + booking confirmation
```

---

## Running the Application

### Start all services

```bash
# Terminal 1 — Redis (in WSL)
sudo systemctl start redis-server

# Terminal 2 — PostgreSQL (in WSL)
sudo systemctl start postgresql

# Terminal 3 — Ollama
ollama serve

# Terminal 4 — Backend
cd ChatbotAgent/backend
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload

# Terminal 5 — Flutter (optional)
cd ChatbotAgent/flutter_app
flutter run
```

### Verify everything is running

```bash
# Backend health
curl http://localhost:8000/health
# → {"status": "ok", "env": "development"}

# Swagger UI
# Open: http://localhost:8000/docs

# Test chat
curl -X POST http://localhost:8000/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Luật bida 8-ball là gì?"}'

# Test menu
curl http://localhost:8000/api/menu/
```

---

## Troubleshooting

### Gemini API 429 (Rate Limit)

If you see `429 You exceeded your current quota`:
- Your Gemini API key has no free-tier allocation
- **Fix:** Use Ollama instead (set `LLM_PROVIDER=ollama` in `.env`)
- Or get a new API key from [aistudio.google.com](https://aistudio.google.com)

### LangChain Import Errors

If you see `cannot import name 'AgentExecutor'`:
- LangChain 1.x broke backward compatibility with 0.3.x
- **Fix:** Pin to compatible versions:
  ```bash
  pip install langchain==0.3.1 langchain-core==0.3.63 langchain-ollama==0.2.3
  ```

### Neo4j Connection Failed

If you see `ServiceUnavailable`:
- Check `NEO4J_URI` uses `neo4j+s://` scheme (not `bolt://`)
- Verify credentials in Neo4j AuraDB console
- Free tier instances pause after 3 days of inactivity — resume in console

### PostgreSQL Connection Refused

If you see `Connection refused`:
- Ensure PostgreSQL is running: `sudo systemctl status postgresql`
- Check `DATABASE_URL` in `.env` matches your setup
- WSL PostgreSQL listens on `localhost:5432` by default

### Redis Connection Refused

If you see `Error 10061 connecting to localhost:6379`:
- Ensure Redis is running: `sudo systemctl status redis-server`
- Start it: `sudo systemctl start redis-server`

### Entity Extraction is Slow

Each chunk takes ~60 seconds with `qwen2.5-coder:7b` on CPU. To speed up:
- Use a GPU: Install CUDA-enabled Ollama
- Use a smaller model: `ollama pull qwen2.5:3b`
- Use a faster model: `ollama pull mistral:7b`
- Use cloud LLM: Set `GEMINI_API_KEY` in `.env` (requires billing)

---

## .env.example

```env
# AI — Ollama (local, free, recommended)
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=qwen2.5-coder:7b
LLM_PROVIDER=ollama
LLM_MODEL=qwen2.5-coder:7b

# AI — Gemini (cloud fallback, requires API key)
GEMINI_API_KEY=your_key_here

# AI — Anthropic (cloud fallback, requires API key)
ANTHROPIC_API_KEY=your_key_here

# Neo4j AuraDB
NEO4J_URI=neo4j+s://xxxxxxxx.databases.neo4j.io
NEO4J_USERNAME=neo4j
NEO4J_PASSWORD=your_password
NEO4J_DATABASE=neo4j

# PostgreSQL
DATABASE_URL=postgresql+asyncpg://postgres:password@localhost:5432/sports_venue

# Redis
REDIS_URL=redis://localhost:6379

# App
APP_ENV=development
SECRET_KEY=your_secret_key
```

---

## License

Academic project — Sports Venue AI Chatbot.
