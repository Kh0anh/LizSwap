# LizSwap – Agent Instructions

Đây là tệp hướng dẫn dành cho AI Agent (Antigravity). **Đọc toàn bộ file này trước khi thực hiện bất kỳ tác vụ nào trong dự án LizSwap.**

---

## 1. Tổng quan dự án

**LizSwap** là một Sàn giao dịch phi tập trung (DEX) triển khai trên **Binance Smart Chain (BSC)**, theo kiến trúc **Uniswap V2 – AMM (Automated Market Maker)**.

| Mục | Chi tiết |
|---|---|
| **Blockchain** | Binance Smart Chain (BSC Mainnet – Chain ID: 56 / Testnet – Chain ID: 97) |
| **Smart Contract** | Solidity + Foundry (không CI/CD, deploy thủ công) |
| **Frontend** | Next.js + wagmi + viem + shadcn/ui + Tailwind CSS |
| **Backend** | Node.js + TypeScript + Express |
| **Database** | PostgreSQL 15 |
| **Cache** | Redis 7 |
| **Deploy** | VPS Ubuntu 22.04 + PM2 + Docker + Nginx + Let's Encrypt |

---

## 2. Tính năng hệ thống

- **Swap** token ERC-20 (có slippage control, deadline, routing)
- **Add / Remove Liquidity** (nhận LP Token)
- **LP Token Staking** (stake nhận reward token)
- **Kết nối MetaMask** (wagmi + EIP-1193)
- **Candlestick Chart realtime** — chỉ hiển thị với cặp có **direct pool**; cặp routing nhiều pool → hiển thị *"Không có dữ liệu chart"*
- **Admin Dashboard** — phân quyền Manager / Staff (xem mục 4)

---

## 3. Kiến trúc Smart Contracts

### Core (Immutable)
- `LizSwapFactory.sol` — tạo & lưu Pair (CREATE2), quản lý `feeTo`
- `LizSwapPair.sol` — AMM pool: `reserve0/1`, `x*y=k`, LP Token (ERC-20), `Swap/Mint/Burn` events
- `LizSwapERC20.sol` — base LP Token với EIP-2612 permit

### Periphery (Entry Points)
- `LizSwapRouter.sol` — routing swap/liquidity, kiểm tra slippage & deadline
- `LizSwapStaking.sol` — stake LP Token, reward per block (`accRewardPerShare`)
- `MockERC20.sol` — token thử nghiệm cho dev/testnet

### Quy tắc bảo mật bắt buộc
- Tất cả hàm write trong `LizSwapPair` phải dùng `lock` modifier (reentrancy guard)
- `Router` phải kiểm tra `amountOutMin`, `amountInMax`, `deadline` cho mọi tx
- Protocol fee: `feeTo != address(0)` → 1/6 của 0.3% swap fee tích luỹ vào Pair

---

## 4. Phân quyền người dùng

| Role | Quyền DApp | Quyền Backend API | Quyền Contract |
|---|---|---|---|
| **Trader** | Swap, xem chart | Public endpoints | ❌ |
| **Liquidity Provider** | Pool, Add/Remove, Stake | Public endpoints | ❌ |
| **Manager** | Toàn bộ Admin Dashboard | Tất cả `/api/admin/*` | ✅ (`setFeeTo`, `setFeeToSetter`, reward config) |
| **Staff** | Dashboard, Pool Monitor, Activity | Read-only `/api/admin/*` | ❌ |

> **QUAN TRỌNG**: Role guard phải enforce ở cả 2 tầng — React UI (ẩn/hiện) **VÀ** Backend API (403 Forbidden). Không chỉ dựa vào UI.

---

## 5. Backend API – Endpoints chính

| Method | Route | Auth | Mô tả |
|---|---|---|---|
| GET | `/api/prices/:token` | — | Giá token realtime |
| GET | `/api/pools` | — | Danh sách pools & stats |
| GET | `/api/pools/:pair/stats` | — | TVL, volume, APR của pool |
| GET | `/api/ohlcv` | — | Dữ liệu nến (kiểm tra direct pool) |
| POST | `/api/auth/login` | — | Wallet signature → JWT |
| POST | `/api/auth/logout` | JWT | Invalidate token |
| GET | `/api/admin/users` | Manager/Staff | Danh sách users & role |
| POST | `/api/admin/users` | **Manager only** | Thêm Staff mới |
| PUT | `/api/admin/users/:id/role` | **Manager only** | Cập nhật role |
| DELETE | `/api/admin/users/:id` | **Manager only** | Vô hiệu hoá tài khoản |
| GET | `/api/admin/activity` | Manager/Staff | Lịch sử giao dịch Swap/Mint/Burn, filter theo pair và thời gian |
| GET | `/api/admin/stats` | Manager/Staff | Thống kê tổng quan: 24h volume, TVL, số active wallets |
| GET | `/api/admin/config` | Manager/Staff | Xem cấu hình hệ thống |
| PUT | `/api/admin/config` | **Manager only** | Cập nhật cấu hình |

### WebSocket Events

| Event | Chiều | Mô tả |
|---|---|---|
| `subscribe:price` | Client → Server | Đăng ký nhận giá token |
| `price:update` | Server → Client | Push giá mới nhất (mỗi ~2s) |
| `subscribe:ohlcv` | Client → Server | Đăng ký nhận candle realtime |
| `ohlcv:new_candle` | Server → Client | Push nến mới khi Indexer flush |

### Auth Flow
- Manager/Staff ký message bằng MetaMask (EIP-191)
- Backend xác thực signature → cấp JWT token với `role` payload
- JWT blacklist lưu trên Redis (logout/revoke)


---

## 6. Candlestick Chart Logic

```
GET /api/ohlcv?token0=X&token1=Y&interval=1h
  └─ validateDirectPool(X, Y)
       ├─ Factory.getPair(X, Y) == address(0) → return { error: 'NO_DIRECT_POOL' }
       │    └─ Frontend: hiển thị "Không có dữ liệu chart"
       └─ getPair != address(0) → fetch OHLCV từ Redis/PostgreSQL → return candle[]
            └─ Frontend: hiển thị CandlestickChart (lightweight-charts)
```

**Intervals hỗ trợ**: `1m`, `5m`, `1h`, `1d`

---

## 7. BSC Indexer – Pipeline

```
BSC WebSocket (Swap/Mint/Burn events)
  └─ EventListener
       └─ CandleBuilder (parseSwapEvent → calcSpotPrice → CandleAggregator)
            └─ IndexerWriter
                 ├─ INSERT INTO ohlcv_candles (PostgreSQL)
                 └─ SET latest candle cache (Redis pub/sub)
                      └─ WebSocket Gateway → broadcast ohlcv:new_candle → Frontend
```

---

## 8. Frontend Routes

### DApp (`lizswap.xyz`)
| Route | Chức năng |
|---|---|
| `/swap` | Swap token + Candlestick Chart |
| `/pool` | Danh sách pools, LP balance |
| `/pool/add` | Thêm thanh khoản |
| `/pool/remove` | Rút thanh khoản |
| `/stake` | Stake/Unstake LP, claim reward |

### Admin Dashboard (`admin.lizswap.xyz`)
| Route | Role |
|---|---|
| `/login` | Tất cả |
| `/dashboard` | Manager + Staff |
| `/pools` | Manager + Staff |
| `/activity` | Manager + Staff |
| `/users` | **Manager only** |
| `/config` | **Manager only** |

---

## 9. Hạ tầng triển khai (VPS)

**Tất cả services đều trên cùng một VPS** (Ubuntu 22.04):

| Process | Tech | Port |
|---|---|---|
| `dapp-frontend` | Next.js (PM2) | `:3001` |
| `admin-dashboard` | Next.js (PM2) | `:3002` |
| `backend-api` | Node.js (PM2) | `:3000` |
| `bsc-indexer` | Node.js (PM2) | daemon |
| `postgres` | Docker | `:5432` (internal) |
| `redis` | Docker | `:6379` (internal) |
| `nginx` | Nginx + TLS | `:80` → `:443` |

**Nginx routing:**
- `lizswap.xyz` → `:3001`
- `admin.lizswap.xyz` → `:3002`
- `*/api/*` + WebSocket → `:3000`

**PostgreSQL và Redis chỉ bind `localhost`** — không expose ra ngoài.

---

## 10. Tài liệu kiến trúc C4

Tất cả tài liệu nằm tại `docs/architecture/`:

| File | Nội dung |
|---|---|
| `c4-context.md` | Level 1 – System Context (actors & external systems) |
| `c4-containers.md` | Level 2 – Container Diagram |
| `c4-components-smart-contracts.md` | Level 3 – Smart Contract components |
| `c4-components-backend.md` | Level 3 – Backend API & Indexer components |
| `c4-components-frontend.md` | Level 3 – DApp & Admin Dashboard components |
| `c4-deployment.md` | Level 4 – Infrastructure Deployment |
| `techstack.md` | Toàn bộ công nghệ, thư viện, công cụ |
| `project-structure.md` | Cấu trúc thư mục monorepo đề xuất |

> Khi tạo hoặc sửa tài liệu kiến trúc, luôn đảm bảo nhất quán với các file trên và cập nhật file liên quan nếu có thay đổi.

---

## 11. Quy tắc làm việc bắt buộc cho Agent

### Bước thực hiện TRƯỚC KHI bắt đầu bất kỳ tác vụ nào

```
1. Đọc AGENT.md (file này)
2. Xác định loại công việc → chọn skill phù hợp → đọc SKILL.md của skill đó
3. Đọc tài liệu liên quan trong docs/architecture/*.md
4. Sau đó mới bắt đầu thực hiện
```

> **NGHIÊM CẤM** bỏ qua các bước trên. Không đọc tài liệu và skill trước khi làm sẽ dẫn đến sai sót kiến trúc, vi phạm bảo mật, hoặc không nhất quán với hệ thống.

---

### Bảng Skills & Khi nào sử dụng

| Loại công việc | Skill bắt buộc đọc | File SKILL.md |
|---|---|---|
| Smart Contract (viết, audit, sửa) | `solidity-security` | `.agents/skills/solidity-security/SKILL.md` |
| Vẽ / cập nhật C4 diagram | `c4-architecture` | `.agents/skills/c4-architecture/SKILL.md` |
| Frontend Next.js (page, hook, routing) | `nextjs-app-router-patterns` | `.agents/skills/nextjs-app-router-patterns/SKILL.md` |
| UI Component (shadcn/ui) | `shadcn` | `.agents/skills/shadcn/SKILL.md` |

---

### Bảng Tài liệu & Khi nào đọc

| Khi làm việc liên quan đến... | Tài liệu cần đọc trước |
|---|---|
| Kiến trúc tổng quan, actors, external systems | `docs/architecture/c4-context.md` |
| Quan hệ giữa các services / containers | `docs/architecture/c4-containers.md` |
| Smart Contract (Factory, Pair, Router, Staking) | `docs/architecture/c4-components-smart-contracts.md` |
| Backend API, Indexer, database schema, endpoints | `docs/architecture/c4-components-backend.md` |
| Frontend pages, components, chart logic, admin | `docs/architecture/c4-components-frontend.md` |
| Hạ tầng, VPS, PM2, Nginx, deploy checklist | `docs/architecture/c4-deployment.md` |
| Chọn thư viện, phiên bản, công cụ | `docs/architecture/techstack.md` |
| Tạo file / thư mục mới, đặt tên, vị trí code | `docs/architecture/project-structure.md` |

---

### Quy tắc chung

1. **Đọc AGENT.md này đầu tiên** — luôn luôn.
2. **Xác định skill** phù hợp với tác vụ → đọc `SKILL.md` của skill đó trước khi code.
3. **Đọc tài liệu kiến trúc liên quan** trước khi tạo hoặc sửa bất kỳ file code nào.
4. **Tuân theo tech stack** đã định nghĩa — không tự ý thêm thư viện mà không hỏi.
5. **Ngôn ngữ**: Trả lời bằng **tiếng Việt** trừ khi người dùng yêu cầu khác.
6. **Không CI/CD**: Deploy thủ công — Foundry cho contracts, PM2 cho backend/frontend.
7. **Nhất quán tài liệu**: Khi thay đổi kiến trúc, cập nhật cả `docs/architecture/` lẫn `AGENT.md`.
