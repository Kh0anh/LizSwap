# LizSwap – Project Structure

Tài liệu này mô tả cấu trúc thư mục đề xuất của dự án LizSwap (monorepo).

---

## Tổng quan Monorepo

```
LizSwap/
├── AGENT.md                        # Hướng dẫn cho AI Agent (Antigravity)
├── README.md                       # Giới thiệu dự án
├── .agents/                        # Skills & workflows của Antigravity
│   └── skills/
│       ├── c4-architecture/
│       ├── nextjs-app-router-patterns/
│       ├── shadcn/
│       └── solidity-security/
│
├── docs/
│   └── architecture/               # Tài liệu kiến trúc C4
│       ├── c4-context.md           # Level 1 – System Context
│       ├── c4-containers.md        # Level 2 – Container Diagram
│       ├── c4-components-smart-contracts.md  # Level 3 – Contracts
│       ├── c4-components-backend.md          # Level 3 – Backend
│       ├── c4-components-frontend.md         # Level 3 – Frontend
│       ├── c4-deployment.md        # Level 4 – Deployment
│       ├── techstack.md            # Tech Stack chi tiết
│       └── project-structure.md    # File này
│
├── contracts/                      # Smart Contracts (Foundry)
├── apps/
│   ├── dapp/                       # DApp Frontend (Next.js)
│   └── admin/                      # Admin Dashboard (Next.js)
├── packages/
│   ├── backend/                    # Backend API (Node.js)
│   └── indexer/                    # BSC Indexer (Node.js)
├── infra/                          # Nginx, PostgreSQL init, Certbot
├── docker-compose.yml              # Docker Compose (toàn bộ services)
├── .env.example                    # Template biến môi trường
└── .dockerignore                   # Exclude files từ Docker build
```

---

## 1. `contracts/` – Smart Contracts (Foundry)

```
contracts/
├── foundry.toml                    # Cấu hình Foundry
├── remappings.txt                  # Import remappings
│
├── src/                            # Source contracts
│   ├── core/
│   │   ├── LizSwapFactory.sol      # Tạo & quản lý Pair (CREATE2)
│   │   ├── LizSwapPair.sol         # AMM pool: reserves, x*y=k, LP Token
│   │   └── LizSwapERC20.sol        # Base LP Token (EIP-2612 permit)
│   ├── periphery/
│   │   ├── LizSwapRouter.sol       # Routing swap/liquidity, slippage, deadline
│   │   └── LizSwapStaking.sol      # Stake LP Token, reward per block
│   ├── interfaces/
│   │   ├── ILizSwapFactory.sol
│   │   ├── ILizSwapPair.sol
│   │   └── ILizSwapRouter.sol
│   ├── libraries/
│   │   ├── LizSwapLibrary.sol      # Tính amounts, fee 0.3%, sort tokens
│   │   └── Math.sol                # sqrt, min
│   └── test-helpers/
│       └── MockERC20.sol           # Token thử nghiệm
│
├── test/                           # Foundry tests
│   ├── core/
│   │   ├── Factory.t.sol
│   │   └── Pair.t.sol
│   ├── periphery/
│   │   ├── Router.t.sol
│   │   └── Staking.t.sol
│   └── integration/
│       └── SwapFlow.t.sol
│
├── script/                         # Deploy scripts
│   ├── DeployAll.s.sol             # Deploy Factory → Router → Staking
│   └── addresses.json              # Contract addresses sau khi deploy
│
└── broadcast/                      # Foundry broadcast logs (auto-generated)
```

---

## 2. `apps/dapp/` – DApp Frontend (Next.js)

```
apps/dapp/
├── package.json
├── components.json                 # shadcn/ui config (alias, style, baseColor)
├── tailwind.config.ts
├── next.config.ts
├── .env.local                      # NEXT_PUBLIC_API_URL, NEXT_PUBLIC_ROUTER_ADDR...
│
├── src/
│   ├── app/                        # Next.js App Router
│   │   ├── layout.tsx              # Root layout: WagmiProvider, ThemeProvider
│   │   ├── page.tsx                # Redirect → /swap
│   │   ├── swap/
│   │   │   └── page.tsx            # SwapPage
│   │   ├── pool/
│   │   │   ├── page.tsx            # PoolPage (danh sách pools)
│   │   │   ├── add/
│   │   │   │   └── page.tsx        # AddLiquidityPage
│   │   │   └── remove/
│   │   │       └── page.tsx        # RemoveLiquidityPage
│   │   └── stake/
│   │       └── page.tsx            # StakePage
│   │
│   ├── components/
│   │   ├── swap/
│   │   │   ├── TokenInSelector.tsx
│   │   │   ├── TokenOutSelector.tsx
│   │   │   ├── SlippageControl.tsx
│   │   │   ├── PriceImpactBadge.tsx
│   │   │   ├── RouteDisplay.tsx
│   │   │   └── SwapButton.tsx
│   │   ├── pool/
│   │   │   ├── PoolList.tsx
│   │   │   ├── MyPositions.tsx
│   │   │   ├── LPTokenPreview.tsx
│   │   │   └── LPAmountSlider.tsx
│   │   ├── chart/
│   │   │   ├── CandlestickChart.tsx  # lightweight-charts wrapper
│   │   │   ├── ChartLoader.tsx       # Fetch + loading/error state
│   │   │   ├── NoDataMessage.tsx     # Hiển thị khi NO_DIRECT_POOL
│   │   │   └── IntervalPicker.tsx
│   │   ├── stake/
│   │   │   └── StakeForm.tsx
│   │   └── shared/
│   │       ├── WalletConnector.tsx   # wagmi useConnect
│   │       ├── TokenSelector.tsx     # Modal chọn token
│   │       └── TxToast.tsx           # Thông báo tx pending/success/failed
│   ├── components/ui/                # shadcn/ui generated components
│   │   ├── button.tsx
│   │   ├── dialog.tsx
│   │   ├── input.tsx
│   │   ├── select.tsx
│   │   ├── toast.tsx
│   │   └── ...                       # npx shadcn add <component>
│   │
│   ├── hooks/
│   │   ├── useContractHooks.ts     # wagmi useContractWrite/Read wrappers
│   │   ├── useSwap.ts
│   │   ├── useLiquidity.ts
│   │   └── useStaking.ts
│   │
│   ├── lib/
│   │   └── apiClient.ts            # axios + WebSocket client
│   │
│   └── constants/
│       ├── contracts.ts            # ABI + addresses theo chainId
│       └── tokens.ts               # Danh sách token mặc định
```

---

## 3. `apps/admin/` – Admin Dashboard (Next.js)

```
apps/admin/
├── package.json
├── components.json                 # shadcn/ui config
├── tailwind.config.ts
├── next.config.ts
├── .env.local                      # NEXT_PUBLIC_API_URL
├── middleware.ts                   # AuthGuard: redirect /login nếu không có JWT
│
├── src/
│   ├── app/
│   │   ├── layout.tsx              # Root layout: RoleProvider
│   │   ├── login/
│   │   │   └── page.tsx            # LoginPage: wallet sign → JWT
│   │   ├── dashboard/
│   │   │   └── page.tsx            # Tổng quan: volume, TVL, active wallets
│   │   ├── pools/
│   │   │   └── page.tsx            # Pool stats monitor
│   │   ├── activity/
│   │   │   └── page.tsx            # Lịch sử giao dịch
│   │   ├── users/
│   │   │   └── page.tsx            # Quản lý Staff (Manager only)
│   │   └── config/
│   │       └── page.tsx            # Cài đặt hệ thống (Manager only)
│   │
│   ├── components/
│   │   ├── Sidebar.tsx             # Nav, ẩn /users + /config với Staff
│   │   ├── RoleGuard.tsx           # HOC kiểm tra role trước khi render
│   │   ├── shared/
│   │   │   └── WalletConnector.tsx
│   │   └── ui/                     # shadcn/ui generated components
│   │       ├── button.tsx
│   │       ├── table.tsx
│   │       ├── badge.tsx
│   │       └── ...                 # npx shadcn add <component>
│   │
│   ├── context/
│   │   └── RoleContext.tsx         # useState role: manager | staff
│   │
│   └── lib/
│       └── apiClient.ts            # axios với JWT Bearer header
```

---

## 4. `packages/backend/` – Backend API (Node.js)

```
packages/backend/
├── package.json
├── tsconfig.json
├── .env                            # DB_URL, REDIS_URL, BSC_RPC_WS, JWT_SECRET, FACTORY_ADDR
│
└── src/
    ├── index.ts                    # Entry point: Express app + PM2 start
    ├── routes/
    │   ├── prices.ts               # GET /api/prices/:token
    │   ├── pools.ts                # GET /api/pools, /api/pools/:pair/stats
    │   ├── ohlcv.ts                # GET /api/ohlcv
    │   ├── auth.ts                 # POST /api/auth/login|logout
    │   └── admin/
    │       ├── users.ts            # CRUD /api/admin/users
    │       └── config.ts           # GET/PUT /api/admin/config
    │
    ├── middleware/
    │   ├── auth.middleware.ts      # JWT verify + blacklist check
    │   └── role.middleware.ts      # Role guard: manager | staff
    │
    ├── services/
    │   ├── PriceService.ts         # Lấy giá token (Redis cache → BSC RPC)
    │   ├── PoolService.ts          # TVL, volume, APR
    │   ├── OHLCVService.ts         # validateDirectPool + fetchCandles
    │   └── AdminService.ts         # Quản lý user_roles, system_config
    │
    ├── repositories/
    │   ├── PostgresRepository.ts   # CRUD: ohlcv_candles, user_roles, system_config
    │   └── RedisRepository.ts      # Get/Set/Pub/Sub cache
    │
    ├── clients/
    │   └── BSCClient.ts            # viem PublicClient: readContract, getLogs
    │
    ├── websocket/
    │   └── WSGateway.ts            # Subscribe Redis pub/sub → broadcast clients
    │
    └── db/
        └── migrations/             # SQL migration files
```

---

## 5. `packages/indexer/` – BSC Indexer (Node.js)

```
packages/indexer/
├── package.json
├── tsconfig.json
├── .env                            # BSC_RPC_WS, DB_URL, REDIS_URL, FACTORY_ADDR
│
└── src/
    ├── index.ts                    # Entry point: khởi động PairRegistry + EventListener
    ├── PairRegistry.ts             # Đồng bộ allPairs từ Factory, lưu metadata
    ├── EventListener.ts            # viem watchContractEvent: Swap/Mint/Burn
    ├── CandleBuilder.ts            # parseSwapEvent → calcSpotPrice → CandleAggregator
    ├── IndexerWriter.ts            # INSERT ohlcv_candles + SET Redis cache
    └── FallbackFetcher.ts          # Fetch OHLCV từ nguồn ngoài (nếu cần)
```

---

## 6. `infra/` – Infrastructure Config

```
infra/
├── nginx/
│   ├── nginx.conf                  # Main Nginx config (workers, gzip, security)
│   └── conf.d/
│       └── default.conf            # Virtual hosts: DApp, Admin, API proxy, WSS
├── postgres/
│   └── init/
│       └── 01_init_schema.sql      # Auto-create schema + seed Manager + config
└── certbot/
    ├── init-letsencrypt.sh          # Script lấy SSL certificate lần đầu
    ├── conf/                        # Let's Encrypt certificates (auto-generated)
    └── www/                         # ACME challenge directory
```

---

## 7. Environment Variables

### Backend / Indexer (`.env`)
| Biến | Mô tả |
|---|---|
| `DB_URL` | PostgreSQL connection string |
| `REDIS_URL` | Redis connection string |
| `BSC_RPC_URL` | HTTPS RPC endpoint (QuickNode/Ankr) |
| `BSC_RPC_WS` | WebSocket RPC endpoint |
| `JWT_SECRET` | Secret ký JWT |
| `FACTORY_ADDR` | Địa chỉ LizSwapFactory on BSC |
| `ROUTER_ADDR` | Địa chỉ LizSwapRouter on BSC |
| `STAKING_ADDR` | Địa chỉ LizSwapStaking on BSC |

### Frontend DApp / Admin (`.env.local`)
| Biến | Mô tả |
|---|---|
| `NEXT_PUBLIC_API_URL` | Base URL Backend API (vd: `https://lizswap.xyz/api`) |
| `NEXT_PUBLIC_WS_URL` | WebSocket URL (vd: `wss://lizswap.xyz/ws`) |
| `NEXT_PUBLIC_FACTORY_ADDR` | Địa chỉ Factory contract |
| `NEXT_PUBLIC_ROUTER_ADDR` | Địa chỉ Router contract |
| `NEXT_PUBLIC_STAKING_ADDR` | Địa chỉ Staking contract |
| `NEXT_PUBLIC_CHAIN_ID` | `56` (mainnet) hoặc `97` (testnet) |
