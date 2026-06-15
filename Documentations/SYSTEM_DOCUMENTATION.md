# Tài liệu Đồ án - Sports Venue AI Chatbot

## Mục lục

1. [Tổng quan kiến trúc](#1-tổng-quan-kiến-trúc)
2. [Công nghệ sử dụng](#2-công-nghệ-sử-dụng)
3. [Cơ sở lý thuyết](#3-cơ-sở-lý-thuyết)
4. [Chức năng hệ thống](#4-chức-năng-hệ-thống)
5. [Cơ sở dữ liệu](#5-cơ-sở-dữ-liệu)
6. [API Reference](#6-api-reference)
7. [Tài liệu tham khảo](#7-tài-liệu-tham-khảo)

---

## 1. Tổng quan kiến trúc

### 1.1 Mô hình Client-Server

Hệ thống áp dụng mô hình **Client-Server** với kiến trúc **3-tier**:

```
┌─────────────────────────────────────────────────────┐
│              Presentation Layer (Flutter)            │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐            │
│  │ Customer  │ │  Staff   │ │  Admin   │            │
│  │  Screen   │ │  Screen  │ │  Screen  │            │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘            │
│       └─────────────┼───────────┘                   │
│                     │ HTTP / WebSocket               │
├─────────────────────┼───────────────────────────────┤
│              Application Layer (FastAPI)             │
│  ┌──────────────────────────────────────────┐       │
│  │  REST API + WebSocket + AI Agent         │       │
│  │  ┌────────┐ ┌────────┐ ┌──────────┐     │       │
│  │  │ Auth   │ │Booking │ │  Chat    │     │       │
│  │  │ API    │ │ API    │ │  Agent   │     │       │
│  │  └────────┘ └────────┘ └──────────┘     │       │
│  │  ┌────────┐ ┌────────┐ ┌──────────┐     │       │
│  │  │ Camera │ │ Staff  │ │ Payment  │     │       │
│  │  │ API    │ │ API    │ │ API      │     │       │
│  │  └────────┘ └────────┘ └──────────┘     │       │
│  └──────────────────────────────────────────┘       │
├─────────────────────────────────────────────────────┤
│              Data Layer                              │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐            │
│  │PostgreSQL│ │  Neo4j   │ │  Redis   │            │
│  │ (ORM)    │ │ (Graph)  │ │ (Cache)  │            │
│  └──────────┘ └──────────┘ └──────────┘            │
└─────────────────────────────────────────────────────┘
```

### 1.2 Kiến trúc Clean Architecture

Backend áp dụng mô hình **Repository Pattern** tách biệt các tầng:

- **API Layer** (`app/api/`): FastAPI routers, xử lý request/response
- **Service Layer** (`app/services/`): Business logic
- **Repository Layer** (`app/repositories/`): Data access, truy vấn database
- **Model Layer** (`app/models/`): SQLAlchemy ORM models
- **Schema Layer** (`app/schemas/`): Pydantic validation schemas

### 1.3 State Management (Flutter)

Sử dụng **Riverpod** - state management declarative:

- `StateNotifierProvider`: Quản lý state phức tạp (auth, booking, camera)
- `FutureProvider`: Async data loading (resources, venues)
- `Provider`: Computed values, dependencies

---

## 2. Công nghệ sử dụng

| Layer | Công nghệ | Phiên bản | Vai trò |
|-------|-----------|-----------|---------|
| Mobile App | Flutter + Dart | 3.1+ | Cross-platform UI |
| Backend API | Python + FastAPI | 0.115+ | REST API server |
| AI Agent | LangChain + Ollama | 0.3.1 | Chat AI với tool calling |
| LLM | qwen2.5-coder:7b | 7B params | Xử lý ngôn ngữ tự nhiên |
| Knowledge Graph | Neo4j AuraDB | 5.x | Lưu trữ tri thức |
| Database | PostgreSQL | 14+ | Cơ sở dữ liệu chính |
| Cache | Redis | 7+ | Session, pub/sub, chat |
| Video Streaming | media_kit (libmpv) | 1.1.10+ | RTSP camera playback |
| Payment | Stripe + VNPay | - | Thanh toán quốc tế + nội địa |
| Real-time | WebSocket | - | Thông báo real-time |

---

## 3. Cơ sở lý thuyết

### 3.1 Knowledge Graph (Đồ thị tri thức)

**Khái niệm**: Knowledge Graph là cấu trúc dữ liệu biểu diễn tri thức dưới dạng đồ thị, trong đó:
- **Node (Đỉnh)**: Đại diện cho thực thể (Rule, Technique, Equipment, Sport)
- **Edge (Cạnh)**: Đại diện cho mối quan hệ giữa các thực thể

**Schema đồ thị tri thức**:
```
Node types: Rule, Technique, Equipment, Sport, Concept, GameType
Relationships: DUNG_DE, LIEN_QUAN, LA_LOAI, THUOC, SU_DUNG, QUY_DINH
```

**Graph RAG (Retrieval-Augmented Generation)**:
- Chạy song song full-text search và vector search trên Neo4j
- Hợp nhất thứ hạng bằng Reciprocal Rank Fusion (RRF)
- Mở rộng quan hệ tri thức trong phạm vi 1-2 bước
- Fallback sang keyword `CONTAINS` khi embedding hoặc index không khả dụng
- Kết hợp với LLM để tạo câu trả lời chính xác
- Giảm hallucination bằng cách grounding vào dữ liệu thực

**Vòng đời embedding**:
- Pipeline đã lưu embedding cho 418/418 node tri thức và vector index
  `entity_embedding_index` đang ở trạng thái `ONLINE`.
- Khi backend khởi động, tác vụ nền gọi `sync_missing_embeddings()` nhưng chỉ
  xử lý node thiếu embedding hoặc stale do thay đổi model, profile, name hay
  description. Tác vụ không chặn quá trình mở API.
- Với `nomic-embed-text`, document, query và intent dùng đúng các task prefix
  tương ứng: `search_document:`, `search_query:` và `classification:`.
- Các embedding mẫu của `IntentRouter` được cache trong Redis 7 ngày theo hash
  của model/profile/danh sách mẫu. Vì vậy lần đầu hoặc khi cấu hình thay đổi mới
  sinh lại toàn bộ vector; các lần restart sau đọc cache.
- Vector search đã chạy được về mặt kỹ thuật, nhưng kiểm tra thực tế tiếng Việt
  chưa cho kết quả top-1 tốt. Vì vậy hệ thống vẫn dùng full-text, keyword, RRF
  và graph expansion; chưa được phép kết luận semantic retrieval đã tối ưu.

### 3.2 AI Agent với Tool Calling

**Ý tưởng triển khai**: Chatbot LLM thông thường chỉ thực hiện luồng
`message -> LLM -> text`. AI Agent của hệ thống bổ sung vòng lặp
`message -> quyết định -> function call -> observation -> final answer`.
LLM hiểu ngôn ngữ và chọn hành động, còn Python tool cùng service/repository
thực hiện nghiệp vụ trên dữ liệu thật.

Agent được xây dựng bằng `create_tool_calling_agent` và `AgentExecutor` của
LangChain. Khi khởi tạo, backend truyền system prompt và danh sách tool cho
LLM. Từ chữ ký hàm, type hint và docstring của các hàm `@tool`, LangChain tạo
JSON schema mô tả function. LLM chỉ sinh một yêu cầu có cấu trúc gồm tên tool
và arguments; LLM không trực tiếp chạy Python, SQL hay Cypher.

Luồng kỹ thuật của một function call:

1. `ChatService` tải `chat_history` từ Redis và enrich message bằng user,
   venue, ngày giờ, múi giờ, loại sân và giá.
2. `IntentRouter` kiểm tra cache, keyword và embedding. Vector mẫu được đọc từ
   Redis nếu cache còn hiệu lực; các yêu cầu nghiệp vụ được chuyển tiếp cho
   `VenueAgent`.
3. `AgentExecutor` gửi prompt, history, tool schemas và `agent_scratchpad` cho
   LLM.
4. LLM trả `AgentFinish` hoặc `tool_call(name, args)`.
5. `AgentExecutor` ánh xạ tên tool sang hàm Python và gọi `ainvoke(args)`.
6. Tool lấy `current_user_id` và `current_chat_context` từ `ContextVar`, sau đó
   gọi service/repository.
7. Kết quả tool được thêm vào `agent_scratchpad` dưới dạng observation và gửi
   lại cho LLM.
8. LLM tổng hợp câu trả lời cuối; backend trả thêm `tools_used` và metadata.

Ba loại trạng thái được tách riêng:

- `chat_history`: bộ nhớ hội thoại nhiều lượt, lưu trong Redis với TTL.
- `agent_scratchpad`: action/observation tạm thời trong một lần chạy agent.
- Business state: booking, order, menu trong PostgreSQL; tri thức trong Neo4j.

`AgentExecutor` giới hạn tối đa 5 vòng lặp, bật xử lý lỗi parse và trả
`intermediate_steps` để xác định tool đã dùng. Vì vậy đây là bounded agent:
model chỉ được gọi các function đăng ký trước, không có quyền thực thi mã tùy
ý hoặc truy cập database trực tiếp.

**Các tool hiện có**:

| Tool | Trigger | Chức năng |
|------|---------|-----------|
| `query_knowledge` | Hỏi luật, kỹ thuật | Truy vấn Neo4j knowledge graph |
| `book_court` | Đặt sân | Kiểm tra availability, tạo booking |
| `order_menu_items` | Gọi đồ/thuê dụng cụ | Khớp item, tạo order, liên kết booking |
| `recommend_menu` | Hỏi thực đơn/gợi ý | Tìm theo sở thích hoặc món bán chạy |
| `call_staff` | Gọi nhân viên | Tạo staff request, thông báo WebSocket |
| `check_schedule` | Xem lịch | Query bookings theo ngày |

Ví dụ logic khi đặt sân:

```json
{
  "name": "book_court",
  "args": {
    "court_type": "billiards",
    "court_number": 1,
    "start_time": "2026-06-14T20:00:00",
    "end_time": "2026-06-14T22:00:00",
    "notes": ""
  }
}
```

Function call trên chỉ là dữ liệu điều khiển nội bộ. `book_court` tiếp tục
chuẩn hóa loại sân, parse thời gian, xác định venue/resource, kiểm tra trùng
lịch bằng `BookingService`, tạo transaction PostgreSQL và trả booking thật.
LLM chỉ được phép diễn đạt lại kết quả đó.

### 3.3 Real-time Communication (WebSocket)

**Khái niệm**: WebSocket là giao thức truyền thông hai chiều (full-duplex) trên một kết nối TCP.

**Áp dụng trong hệ thống**:
- **Notifications**: Thông báo real-time cho staff/admin khi có sự kiện
- **Staff Chat**: Chat trực tiếp giữa staff và customer
- **Court Status**: Cập nhật trạng thái sân real-time

### 3.4 RTSP Camera Streaming

**Khái niệm**: RTSP (Real Time Streaming Protocol) là giao thức truyền phát video trực tuyến.

**Kiến trúc**:
```
[IP Camera] --RTSP--> [media_kit/libmpv] --> [Flutter Video Widget]
```

**Các hãng camera hỗ trợ**:

| Hãng | RTSP URL Pattern |
|------|-----------------|
| Hikvision | `rtsp://user:pass@ip:port/cam/realmonitor?channel=1&subtype=0` |
| Dahua | `rtsp://user:pass@ip:port/cam/realmonitor?channel=1&subtype=0` |
| Seetong | `rtsp://user:pass@ip:port/mpeg4` |
| FPT | `rtsp://user:pass@ip:port/live/0` |

### 3.5 Multi-tenancy

**Khái niệm**: Multi-tenancy là kiến trúc một ứng dụng phục vụ nhiều khách hàng (tenant).

**Triển khai**:
- Mỗi `Business` có nhiều `Venue`
- Mỗi `Venue` có nhiều `ServiceResource` (sân/bàn)
- `StaffAssignment` liên kết staff với venue/area/resource với scope:
  - `VENUE`: Toàn quyền venue
  - `AREA`: Quản lý khu vực
  - `RESOURCE`: Quản lý sân cụ thể

---

## 4. Chức năng hệ thống

### 4.1 Chức năng Customer

| Chức năng | Mô tả |
|-----------|-------|
| Chat AI | Hỏi đáp về luật, kỹ thuật, đặt sân qua AI |
| Đặt sân | Chọn sân, thời gian, xác nhận đặt |
| Đặt món | Xem menu, đặt thức ăn/thức uống |
| Gọi nhân viên | Tạo yêu cầu hỗ trợ |
| Xem lịch | Xem lịch sử đặt sân |
| Thanh toán | Stripe (quốc tế) + VNPay (nội địa) |
| Quét QR nhận sân | Quét QR code để xác nhận nhận sân |

### 4.2 Chức năng Staff

| Chức năng | Mô tả |
|-----------|-------|
| Quản lý đặt sân | Xem, xác nhận, check-in booking |
| Quản lý yêu cầu | Tiếp nhận, xử lý yêu cầu khách |
| Chat với khách | Trò chuyện real-time với khách |
| Quản lý menu | Xem, cập nhật trạng thái món |
| Xem camera sân | Giám sát camera IP các sân được phân công |
| Hoá đơn | Xem hoá đơn khách |

### 4.3 Chức năng Admin

| Chức năng | Mô tả |
|-----------|-------|
| Dashboard | Tổng quan doanh thu, booking, orders |
| Quản lý đặt sân | CRUD booking, đổi trạng thái |
| Quản lý sân | Thêm/sửa/xoá sân, đổi trạng thái (hoạt động/bảo trì/tắt) |
| Cấu hình giá | Thiết lập giá theo giờ cho từng sân |
| Quản lý camera | CRUD camera IP, gán camera cho sân |
| Quản lý nhân viên | CRUD staff, phân quyền theo venue/area/resource |
| Quản lý menu | CRUD thức ăn/thức uống |
| Biểu đồ | Thống kê doanh thu, booking |
| Quản lý hoá đơn | Xem, quản lý hoá đơn |

### 4.4 Chức năng Camera (Mới)

**Luồng hoạt động**:
1. Admin cấu hình camera (IP, port, username, password, hãng)
2. Admin gán camera cho sân/bàn cụ thể
3. Staff mở "Camera sân" → thấy grid thumbnail các camera được phân công
4. Staff chọn camera → mở RTSP stream trực tiếp

**Backend API**:

| Method | Endpoint | Mô tả |
|--------|----------|-------|
| GET | `/api/admin/cameras` | Admin xem camera theo venue |
| POST | `/api/admin/cameras` | Admin thêm camera |
| PATCH | `/api/admin/cameras/{id}` | Admin sửa camera |
| DELETE | `/api/admin/cameras/{id}` | Admin xoá camera |
| GET | `/api/staff/cameras` | Staff xem camera theo phân công |

**Venue Scope**:
- Admin chỉ quản lý camera trong venue của mình
- Staff chỉ thấy camera của sân được phân công
- Camera được gán resource_id để lọc theo sân

### 4.5 Chức năng Quản lý sân (Mới)

**Chức năng**:
- Xem danh sách tất cả sân/bàn
- Lọc theo trạng thái: Hoạt động / Bảo trì / Tắt
- Đổi trạng thái nhanh (Kích hoạt / Bảo trì / Tắt)
- Hiển thị: tên sân, khu vực, mã sân, giá/giờ

**Trạng thái sân**:

| Status | Ý nghĩa | Khách đặt được? |
|--------|---------|----------------|
| `active` | Hoạt động bình thường | ✅ |
| `maintenance` | Đang bảo trì | ❌ |
| `inactive` | Tắt/không sử dụng | ❌ |

---

## 5. Cơ sở dữ liệu

### 5.1 Schema (PostgreSQL)

```
users
├── id (UUID, PK)
├── phone, name, email
├── password_hash
├── role (CUSTOMER/STAFF/ADMIN)
├── business_id (FK → businesses)
└── default_venue_id (FK → venues)

venues
├── id (UUID, PK)
├── business_id (FK → businesses)
├── name, address, timezone
└── is_active, is_deleted

service_resources (sân/bàn)
├── id (UUID, PK)
├── venue_id (FK → venues)
├── area_id (FK → venue_areas)
├── code, name, resource_type
├── sport_type, number, capacity
├── status (active/maintenance/inactive)
└── hourly_rate

cameras
├── id (UUID, PK)
├── venue_id (FK → venues)
├── resource_id (FK → service_resources)
├── name, ip_address, port
├── username, password
├── camera_brand (hik/dahua/seetong/fpt/custom)
├── rtsp_url_override
└── is_active

bookings
├── id (UUID, PK)
├── user_id (FK → users)
├── venue_id, resource_id
├── start_time, end_time
├── status (confirmed/checked_in/completed/cancelled)
├── payment_status
├── checkin_token, checked_in_at
└── total_price

staff_assignments
├── id (UUID, PK)
├── staff_id (FK → users)
├── venue_id, area_id, resource_id
├── scope (venue/area/resource)
├── starts_at, ends_at
└── is_active
```

### 5.2 Relationships

```
Business 1──N Venue 1──N ServiceResource
                  │
                  ├── 1──N Camera
                  ├── 1──N Booking
                  ├── 1──N StaffAssignment
                  └── 1──N MenuItem

User 1──N Booking
User 1──N StaffAssignment
Booking 1──N Order
```

---

## 6. API Reference

### 6.1 Auth APIs

| Method | Path | Mô tả |
|--------|------|-------|
| POST | `/api/auth/login` | Đăng nhập |
| GET | `/api/auth/verify` | Xác thực token |
| POST | `/api/auth/change-password` | Đổi mật khẩu |

### 6.2 Booking APIs

| Method | Path | Mô tả |
|--------|------|-------|
| POST | `/api/booking` | Tạo booking |
| GET | `/api/booking/availability` | Kiểm tra sân trống |
| GET | `/api/booking/active` | Booking đang hoạt động |
| POST | `/api/booking/{id}/confirm-checkin` | Xác nhận nhận sân (QR) |
| GET | `/api/booking/bills` | Danh sách hoá đơn |

### 6.3 Admin APIs

| Method | Path | Mô tả |
|--------|------|-------|
| GET | `/api/admin/dashboard` | Dashboard stats |
| GET | `/api/admin/bookings` | Quản lý booking |
| PATCH | `/api/admin/bookings/{id}/status` | Đổi trạng thái booking |
| GET | `/api/admin/cameras` | Quản lý camera |
| POST | `/api/admin/cameras` | Thêm camera |
| PATCH | `/api/admin/resources/{id}` | Cập nhật sân (status, giá) |
| GET | `/api/admin/staff` | Quản lý nhân viên |
| GET | `/api/admin/staff-assignments` | Phân quyền nhân viên |

### 6.4 Staff APIs

| Method | Path | Mô tả |
|--------|------|-------|
| GET | `/api/staff/cameras` | Camera theo phân công |
| GET | `/api/staff/requests` | Yêu cầu khách |
| GET | `/api/staff/chat/rooms` | Phòng chat |
| WS | `/api/staff/chat/{id}/ws` | Chat WebSocket |

---

## 7. Tài liệu tham khảo

1. FastAPI Documentation: https://fastapi.tiangolo.com/
2. Flutter Documentation: https://docs.flutter.dev/
3. SQLAlchemy Documentation: https://docs.sqlalchemy.org/
4. Neo4j Documentation: https://neo4j.com/docs/
5. LangChain Documentation: https://python.langchain.com/
6. RTSP Protocol (RFC 2326): https://tools.ietf.org/html/rfc2326
7. media_kit Package: https://pub.dev/packages/media_kit
8. Riverpod Documentation: https://riverpod.dev/
