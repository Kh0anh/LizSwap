# LizSwap – Tech Stack

Tài liệu này liệt kê toàn bộ công nghệ, thư viện, và công cụ được sử dụng trong dự án LizSwap.

---

## 1. Blockchain & Smart Contracts

| Hạng mục | Công nghệ | Ghi chú |
|---|---|---|
| **Blockchain** | Binance Smart Chain (BSC) | Mainnet Chain ID: 56 / Testnet: 97 |
| **Ngôn ngữ SC** | Solidity | EVM-compatible |
| **Build & Test** | Foundry (`forge`, `cast`, `anvil`) | Không dùng Hardhat |
| **Local Fork** | Anvil | Fork BSC mainnet để test local |
| **Deploy** | `forge script` | Thủ công, không CI/CD |
| **Verify** | `forge verify-contract` | BscScan |
| **Chuẩn Token** | ERC-20, EIP-2612 (permit) | LP Token dùng permit |
| **Kiến trúc AMM** | Uniswap V2 (x\*y=k) | Core + Periphery tách biệt |

---

## 2. Frontend – DApp

| Hạng mục | Công nghệ | Phiên bản | Ghi chú |
|---|---|---|---|
| **Framework** | Next.js | 14+ (App Router) | SSR + SSG |
| **Ngôn ngữ** | TypeScript | 5+ | |
| **Web3 Wallet** | wagmi | v2 | Quản lý wallet connection |
| **Blockchain Client** | viem | v2 | `readContract`, `writeContract` |
| **Wallet** | MetaMask | — | EIP-1193, EIP-191 |
| **Chart** | lightweight-charts | v4 | Candlestick chart |
| **HTTP Client** | axios | — | REST API calls |
| **WebSocket** | Browser WebSocket | — | Realtime price & OHLCV |
| **State** | React Context / wagmi hooks | — | |
| **Styling** | Tailwind CSS + shadcn/ui | Radix UI primitives, class-variance-authority |
| **UI Components** | shadcn/ui | `components.json` config, copy-paste components |

---

## 3. Frontend – Admin Dashboard

| Hạng mục | Công nghệ | Ghi chú |
|---|---|---|
| **Framework** | Next.js | App Router, SSR |
| **Ngôn ngữ** | TypeScript | |
| **Styling** | Tailwind CSS + shadcn/ui | Cùng design system với DApp |
| **HTTP Client** | axios | REST API, `/api/admin/*` |
| **Role Guard** | React Context + Next.js Middleware | Manager / Staff |

---

## 4. Backend API

| Hạng mục | Công nghệ | Phiên bản | Ghi chú |
|---|---|---|---|
| **Runtime** | Node.js | v20 LTS | |
| **Ngôn ngữ** | TypeScript | 5+ | |
| **Framework** | Express.js | — | REST API |
| **Validation** | Zod | — | Request schema validation |
| **Security** | Helmet.js | — | HTTP security headers |
| **WebSocket** | Socket.IO | v4 | Realtime price & candle push (room/namespace per token pair, auto-reconnect) |
| **Blockchain Client** | viem (PublicClient) | v2 | Đọc on-chain: reserves, getPair |
| **DB Client** | pg (node-postgres) | — | PostgreSQL |
| **Cache Client** | ioredis | — | Redis |
| **Auth** | jsonwebtoken | — | JWT sign/verify |
| **Signature Verify** | viem `verifyMessage` | — | EIP-191 wallet signature |
| **Process Manager** | PM2 | — | `ecosystem.config.js` |

---

## 5. BSC Indexer

| Hạng mục | Công nghệ | Ghi chú |
|---|---|---|
| **Runtime** | Node.js v20 LTS | |
| **Ngôn ngữ** | TypeScript | |
| **Event Listener** | viem `watchContractEvent` | Subscribe Swap/Mint/Burn |
| **DB Client** | pg | INSERT OHLCV candles |
| **Cache Client** | ioredis | SET/PUB candle cache |
| **HTTP Fallback** | axios | Fetch external OHLCV nếu cần |
| **Process Manager** | PM2 | Daemon, không expose port |

---

## 6. Database & Storage

| Hạng mục | Công nghệ | Phiên bản | Ghi chú |
|---|---|---|---|
| **Relational DB** | PostgreSQL | 15 | Docker container |
| **Cache** | Redis | 7 | Docker, AOF persist |
| **Volume** | Docker named volumes | — | `/data/postgres`, `/data/redis` |

### Bảng chính trong PostgreSQL
| Bảng | Mô tả |
|---|---|
| `ohlcv_candles` | Dữ liệu nến index từ Swap events |
| `user_roles` | Wallet address → role (manager/staff) |
| `system_config` | Cấu hình hệ thống dạng key-value JSONB |

---

## 7. Infrastructure & DevOps

| Hạng mục | Công nghệ | Ghi chú |
|---|---|---|
| **OS** | Ubuntu 22.04 LTS | VPS |
| **Reverse Proxy** | Nginx | TLS termination, virtual hosts |
| **TLS** | Let's Encrypt + Certbot | `lizswap.xyz`, `admin.lizswap.xyz` |
| **Containerisation** | Docker + Docker Compose | postgres, redis |
| **Process Manager** | PM2 | backend-api, bsc-indexer, dapp-frontend, admin-dashboard |
| **BSC RPC** | QuickNode / Ankr | HTTPS + WebSocket (tránh public RPC) |
| **CI/CD** | ❌ Không dùng | Deploy thủ công |

---

## 8. Development Tools

| Công cụ | Mục đích |
|---|---|
| `forge build` | Compile contracts |
| `forge test` | Unit test contracts |
| `forge script` | Deploy script |
| `cast` | Interact với BSC từ CLI |
| `anvil` | Local BSC fork |
| `npm run dev` | Dev server (Next.js / Backend) |
| `docker compose up` | Khởi động postgres + redis |
| `pm2 logs` | Xem log services |
| `certbot` | Cấp / renew SSL |

---

## 9. Chuẩn & Giao thức

| Chuẩn | Mô tả |
|---|---|
| ERC-20 | Interface token chuẩn |
| EIP-2612 | Permit (gasless approve) cho LP Token |
| EIP-1193 | Provider interface MetaMask ↔ DApp |
| EIP-191 | Ký message (wallet-based auth cho Admin) |
| JSON-RPC | Giao tiếp Frontend/Backend ↔ BSC node |
| AMM x\*y=k | Invariant formula của Uniswap V2 |
