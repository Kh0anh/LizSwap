<div align="center">

# 🦎 LizSwap

**Decentralized Exchange on Binance Smart Chain**

[![Solidity](https://img.shields.io/badge/Solidity-363636?style=for-the-badge&logo=solidity&logoColor=white)](https://soliditylang.org/)
[![Next.js](https://img.shields.io/badge/Next.js_14-000000?style=for-the-badge&logo=nextdotjs&logoColor=white)](https://nextjs.org/)
[![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?style=for-the-badge&logo=typescript&logoColor=white)](https://www.typescriptlang.org/)
[![Node.js](https://img.shields.io/badge/Node.js_20-339933?style=for-the-badge&logo=nodedotjs&logoColor=white)](https://nodejs.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL_15-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![BSC](https://img.shields.io/badge/BSC-F0B90B?style=for-the-badge&logo=binance&logoColor=black)](https://www.bnbchain.org/)

LizSwap là sàn giao dịch phi tập trung (DEX) được xây dựng trên Binance Smart Chain,
triển khai theo kiến trúc **Uniswap V2 AMM (Automated Market Maker)**.

[Kiến trúc](#kiến-trúc) · [Tính năng](#tính-năng) · [Cài đặt](#cài-đặt) · [Tài liệu](#tài-liệu)

</div>

---

## Giới thiệu

**LizSwap** là đồ án môn học **Công nghệ Chuỗi khối (Blockchain Technology)** tại **Trường Đại học Nam Cần Thơ**, được thiết kế và phát triển như một sản phẩm hoàn chỉnh từ Smart Contract, Backend, Frontend cho đến hạ tầng triển khai.

Dự án mô phỏng một DEX thực tế với đầy đủ các chức năng: swap token, cung cấp thanh khoản, staking LP token, biểu đồ giá realtime, và bảng quản trị dành cho quản trị viên.

### Nhóm phát triển

| Thành viên | GitHub |
|---|---|
| **Trần Nguyễn Chí Khanh** | [@Kh0anh](https://github.com/Kh0anh) |
| **Võ Nguyễn Gia Huy** | [@studywithhuyne](https://github.com/studywithhuyne) |
| **Lâm Hòa Hộp** | [@lhh224](https://github.com/lhh224) |

---

## Tính năng

### DApp (Người dùng)
- **Swap Token** – Hoán đổi token ERC-20 với slippage control và deadline protection
- **Add / Remove Liquidity** – Cung cấp hoặc rút thanh khoản, nhận LP Token
- **LP Token Staking** – Stake LP Token để nhận reward token
- **Candlestick Chart** – Biểu đồ nến realtime cho các cặp có direct pool
- **Kết nối MetaMask** – Kết nối ví và ký giao dịch qua EIP-1193

### Admin Dashboard (Quản trị)
- **Dashboard** – Tổng quan volume, TVL, số active wallets
- **Pool Monitor** – Giám sát trạng thái và thống kê các pool
- **Activity Log** – Lịch sử giao dịch Swap / Mint / Burn on-chain
- **User Management** – Quản lý Staff (chỉ Manager)
- **System Config** – Cấu hình protocol fee, reward per block

---

## Kiến trúc

```
┌─────────────────────────────────────────────────────────────────┐
│                        Docker Compose                           │
│                                                                 │
│  ┌───────────┐                                                  │
│  │   Nginx   │ ◄── Port 80/443 (entry point duy nhất)          │
│  │  (Proxy)  │                                                  │
│  └─────┬─────┘                                                  │
│        │                                                        │
│  ┌─────┼──────────────────────────────────┐                     │
│  │     ▼              ▼            ▼      │                     │
│  │ ┌────────┐   ┌──────────┐  ┌────────┐ │                     │
│  │ │  DApp  │   │  Admin   │  │Backend │ │                     │
│  │ │ :3001  │   │  :3002   │  │ :3000  │ │                     │
│  │ │Next.js │   │ Next.js  │  │Express │ │                     │
│  │ └────────┘   └──────────┘  └───┬────┘ │                     │
│  │                                │      │                     │
│  │              ┌─────────────────┤      │                     │
│  │              ▼                 ▼      │                     │
│  │        ┌──────────┐     ┌──────────┐  │  ┌───────────┐      │
│  │        │PostgreSQL│     │  Redis   │  │  │  Indexer  │      │
│  │        │  :5432   │     │  :6379   │◄─┼──│ (daemon)  │      │
│  │        └──────────┘     └──────────┘  │  └─────┬─────┘      │
│  └───────────────────────────────────────┘        │             │
│                                                   │             │
└───────────────────────────────────────────────────┼─────────────┘
                                                    │
                                             ┌──────▼──────┐
                                             │  BSC Chain  │
                                             │ (Contracts) │
                                             └─────────────┘
```

### Smart Contracts (Solidity + Foundry)

| Contract | Mô tả |
|---|---|
| `LizSwapFactory` | Tạo và quản lý Pair contracts (CREATE2) |
| `LizSwapPair` | AMM pool: reserves, LP Token, `x * y = k` |
| `LizSwapERC20` | Base LP Token với EIP-2612 permit |
| `LizSwapRouter` | Entry point: routing swap & liquidity |
| `LizSwapStaking` | Stake LP Token, phân phối reward per block |

---

## Tech Stack

| Layer | Công nghệ |
|---|---|
| **Blockchain** | Binance Smart Chain (BSC Testnet/Mainnet) |
| **Smart Contracts** | Solidity · Foundry (forge, cast, anvil) |
| **Frontend** | Next.js 14 · TypeScript · wagmi v2 · viem v2 · Tailwind CSS · shadcn/ui |
| **Backend** | Node.js 20 · TypeScript · Express · Socket.IO v4 · Zod · Helmet |
| **Database** | PostgreSQL 15 · Redis 7 |
| **Infrastructure** | Docker Compose · Nginx · Certbot (Let's Encrypt) |
| **Chart** | lightweight-charts v4 (TradingView) |
| **Auth** | MetaMask (EIP-191) · JWT · Redis blacklist |

---

## Cấu trúc dự án

```
LizSwap/
├── contracts/                  # Smart Contracts (Foundry)
│   ├── src/core/               #   Factory, Pair, ERC20
│   ├── src/periphery/          #   Router, Staking
│   ├── test/                   #   Unit & Integration tests
│   └── script/                 #   Deploy scripts
│
├── apps/
│   ├── dapp/                   # DApp Frontend (Next.js)
│   └── admin/                  # Admin Dashboard (Next.js)
│
├── packages/
│   ├── backend/                # Backend API (Express + Socket.IO)
│   └── indexer/                # BSC Indexer (daemon)
│
├── infra/                      # Infrastructure
│   ├── nginx/                  #   Reverse proxy config
│   ├── postgres/init/          #   Database schema init
│   └── certbot/                #   SSL certificate
│
├── docs/                       # Tài liệu kiến trúc (C4 Model)
├── docker-compose.yml          # Production deployment
├── docker-compose.dev.yml      # Development override
└── .env.example                # Template biến môi trường
```

---

## Cài đặt

### Yêu cầu

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Windows/Mac) hoặc Docker Engine + Docker Compose (Linux)
- [Git](https://git-scm.com/)
- [Foundry](https://book.getfoundry.sh/getting-started/installation) (chỉ cần nếu deploy contracts)

### Bước 1: Clone repository

```bash
git clone https://github.com/Kh0anh/LizSwap.git
cd LizSwap
```

### Bước 2: Cấu hình biến môi trường

```bash
cp .env.example .env
```

Mở file `.env` và điền các thông tin:

```env
# Contract Addresses (sau khi deploy bằng Foundry)
FACTORY_ADDR=0x...
ROUTER_ADDR=0x...
STAKING_ADDR=0x...

# BSC RPC Endpoint
BSC_RPC_URL=https://bsc-testnet-rpc.publicnode.com
BSC_RPC_WS=wss://bsc-testnet-rpc.publicnode.com

# JWT Secret
JWT_SECRET=your_random_secret_here

# Frontend (giống contract addresses)
NEXT_PUBLIC_FACTORY_ADDR=0x...
NEXT_PUBLIC_ROUTER_ADDR=0x...
NEXT_PUBLIC_STAKING_ADDR=0x...
```

---

### Chế độ Development

Development mode hỗ trợ **hot-reload** — sửa code và thấy thay đổi ngay lập tức mà không cần rebuild.

```bash
# Khởi chạy tất cả services với hot-reload
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --build
```

**Truy cập:**

| Service | URL |
|---|---|
| DApp Frontend | http://localhost:3001 |
| Admin Dashboard | http://localhost:3002 |
| Backend API | http://localhost:3000/api |
| PostgreSQL | `localhost:5432` |
| Redis | `localhost:6379` |

**Lệnh thường dùng:**

```bash
# Xem logs
docker compose -f docker-compose.yml -f docker-compose.dev.yml logs -f

# Xem logs 1 service
docker compose -f docker-compose.yml -f docker-compose.dev.yml logs -f backend

# Dừng tất cả
docker compose -f docker-compose.yml -f docker-compose.dev.yml down
```

**Tuỳ chọn: Chạy chỉ Database (dev local không Docker):**

```bash
# Chỉ chạy PostgreSQL + Redis
docker compose up -d postgres redis

# Sau đó chạy từng service local
cd packages/backend && npm run dev    # Terminal 1
cd packages/indexer && npm run dev    # Terminal 2
cd apps/dapp && npm run dev           # Terminal 3
cd apps/admin && npm run dev          # Terminal 4
```

> **Lưu ý:** Khi chạy local, đổi hostname trong `DATABASE_URL` từ `postgres` thành `localhost`

---

### Chế độ Production

Production mode build image tối ưu, chạy ổn định, hỗ trợ HTTPS.

```bash
# Build và khởi chạy
docker compose up -d --build

# Kiểm tra trạng thái
docker compose ps
```

**Bật HTTPS (SSL/TLS):**

```bash
# 1. Uncomment SSL lines trong infra/nginx/conf.d/default.conf
# 2. Lấy SSL certificate
chmod +x infra/certbot/init-letsencrypt.sh
./infra/certbot/init-letsencrypt.sh

# 3. Restart nginx
docker compose restart nginx
```

**Truy cập:**

| Service | URL |
|---|---|
| DApp | https://lizswap.xyz |
| Admin | https://admin.lizswap.xyz |
| API | https://lizswap.xyz/api |
| WebSocket | wss://lizswap.xyz/socket.io |

**So sánh Development vs Production:**

| | Development | Production |
|---|---|---|
| **Hot-reload** | Có | Không (cần rebuild) |
| **Build** | `Dockerfile.dev` (nhanh) | `Dockerfile` (multi-stage, tối ưu) |
| **Ports** | Tất cả exposed | Chỉ Nginx 80/443 |
| **SSL/HTTPS** | Không | Let's Encrypt |
| **Security** | — | Non-root user, health checks |
| **Restart** | — | `unless-stopped` |

---

## Lệnh quản lý

```bash
# Trạng thái containers
docker compose ps

# Xem log realtime
docker compose logs -f backend indexer

# Restart 1 service
docker compose restart backend

# Rebuild 1 service
docker compose up -d --build backend

# Vào PostgreSQL CLI
docker compose exec postgres psql -U lizswap

# Vào Redis CLI
docker compose exec redis redis-cli

# Dừng tất cả
docker compose down

# Dừng + xoá data (mất hết dữ liệu)
docker compose down -v
```

---

## Deploy Smart Contracts

Smart Contracts được deploy thủ công bằng **Foundry**:

```bash
cd contracts

# Compile
forge build

# Test
forge test

# Deploy lên BSC Testnet
forge script script/DeployAll.s.sol \
    --rpc-url https://bsc-testnet-rpc.publicnode.com \
    --broadcast

# Verify trên BscScan
forge verify-contract <address> src/core/LizSwapFactory.sol:LizSwapFactory \
    --chain bsc-testnet
```

Sau khi deploy, cập nhật địa chỉ contract vào file `.env` rồi rebuild frontend:

```bash
docker compose up -d --build dapp admin
```

---

## Tài liệu

| Tài liệu | Mô tả |
|---|---|
| [C4 Context](docs/architecture/c4-context.md) | Kiến trúc Level 1 – Actors & External Systems |
| [C4 Containers](docs/architecture/c4-containers.md) | Kiến trúc Level 2 – Container Diagram |
| [Smart Contracts](docs/architecture/c4-components-smart-contracts.md) | Kiến trúc Level 3 – Smart Contract Components |
| [Backend](docs/architecture/c4-components-backend.md) | Kiến trúc Level 3 – Backend & Indexer Components |
| [Frontend](docs/architecture/c4-components-frontend.md) | Kiến trúc Level 3 – DApp & Admin Components |
| [Deployment](docs/architecture/c4-deployment.md) | Kiến trúc Level 4 – Infrastructure Deployment |
| [REST API](docs/api/rest-api.md) | Đặc tả REST API Endpoints |
| [WebSocket](docs/api/websocket.md) | Đặc tả Socket.IO Events |
| [Database](docs/database/schema.md) | Lược đồ CSDL PostgreSQL & Redis |
| [Tech Stack](docs/architecture/techstack.md) | Toàn bộ công nghệ sử dụng |
| [Error Handling](docs/architecture/error-handling.md) | Chiến lược xử lý lỗi |
| [Testing](docs/testing/test-strategy.md) | Chiến lược kiểm thử |

---

## License

Dự án này được phân phối dưới giấy phép [MIT](LICENSE).

---

<div align="center">

**🦎 LizSwap** – *Decentralized Exchange on BSC*

</div>
