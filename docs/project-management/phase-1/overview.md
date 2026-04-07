# 🔵 GIAI ĐOẠN 1 — MVP: Swap & Pool trên BSC Testnet + Production Ready

> **Mục tiêu**: DEX chạy được với chức năng **Swap token** và **Tạo/Quản lý Pool (Add/Remove Liquidity)** trên BSC Testnet, **sẵn sàng deploy production** trên VPS.
> **Thời gian ước tính**: ~4 tuần (4 Sprints × 1 tuần)

---

## Phạm vi Phase 1

**✅ Bao gồm:**
- Smart Contracts: Factory, Pair, ERC20, Router, MockERC20, Library, Math
- Frontend DApp: `/swap` (không chart), `/pool`, `/pool/add`, `/pool/remove`
- Backend API: `GET /api/prices/:token`, `GET /api/pools`, `GET /api/pools/:pair/stats`
- Shared: WalletConnector, TokenSelector, TxToast, contracts.ts, tokens.ts, apiClient.ts
- Infrastructure: Docker Compose dev mode **+ Production mode** (PostgreSQL + Redis)
- Database: Bảng `tokens`, `pools` (migration cơ bản)
- **Production Deployment**: Docker Compose prod, Dockerfiles (multi-stage build), Nginx reverse proxy, Certbot SSL, Init SQL scripts

**❌ KHÔNG bao gồm:**
- Candlestick Chart / OHLCV
- Staking (contract + frontend)
- Admin Dashboard (toàn bộ)
- BSC Indexer
- Auth system (JWT, wallet signature login)
- WebSocket realtime

---

## Danh sách File Chi Tiết

| File | Mô tả |
|------|-------|
| [overview.md](./overview.md) | Tổng quan Phase 1 — phạm vi, mục tiêu, thời gian ước tính |
| [sprints.md](./sprints.md) | Kế hoạch 4 Sprints (Ngày 1–20), Gantt Chart timeline, Risk Assessment |
| [group-0-khoi-tao-du-an.md](./group-0-khoi-tao-du-an.md) | 🏗️ **Nhóm 0**: Khởi tạo Dự án (BLOCKING) — Init monorepo, Foundry, Next.js, Express, Docker Compose dev, ESLint/Prettier (P1-00~05, **Khanh**) |
| [group-1-smart-contracts.md](./group-1-smart-contracts.md) | ⛓️ **Nhóm 1**: Smart Contracts — Core (Factory, Pair, ERC20), Libraries (Math, Library), Interfaces, Periphery (Router, MockERC20), Tests, Deploy BSC Testnet (P1-10~15, **Khanh**) |
| [group-2-frontend-shared-components-blockchain-hooks.md](./group-2-frontend-shared-components-blockchain-hooks.md) | 🎨 **Nhóm 2**: Frontend Shared — contracts.ts, tokens.ts, WalletConnector, wagmi hooks (useSwap, useLiquidity), TxToast, TokenSelector, SwapButton (P1-20~27, **Khanh**) |
| [group-3-frontend-dapp-ui-pages.md](./group-3-frontend-dapp-ui-pages.md) | 🖥️ **Nhóm 3**: DApp UI Pages — Layout, SwapPage (SlippageControl, PriceImpactBadge, RouteDisplay), PoolPage (PoolList, MyPositions), AddLiquidity, RemoveLiquidity, apiClient (P1-30~42, **Huy**) |
| [group-4-backend-api-database.md](./group-4-backend-api-database.md) | 🔧 **Nhóm 4**: Backend API & Database — Express setup, Migrations, PostgresRepository, RedisRepository, Zod validation, PoolService, Pool routes, Price route, Health check (P1-50~58, **Hộp**) |
| [group-5-backend-bscclient-priceservice.md](./group-5-backend-bscclient-priceservice.md) | 🌐 **Nhóm 5**: BSCClient & PriceService — viem PublicClient đọc on-chain (getReserves, getPair), PriceService tính giá từ reserves + cache Redis TTL 2s (P1-60~61, **Khanh**) |
| [group-6-production-infrastructure.md](./group-6-production-infrastructure.md) | 🏗️ **Nhóm 6**: Production Infrastructure — Docker Compose prod, Dockerfiles multi-stage, Nginx reverse proxy, Certbot SSL, PG init scripts (P1-70~74, **Khanh**) |
| [group-7-integration-testing.md](./group-7-integration-testing.md) | 🔗 **Nhóm 7**: Integration & Testing — Swap integration, Pool integration, FE-BE integration, Production build test, E2E Smoke test (P1-80~84, **Tất cả**). Bao gồm: Tổng hợp khối lượng, Integration Points, Critical Path |

---

## Tổng hợp Khối lượng Công việc

| Thành viên | Tasks | Ước tính tổng | Ghi chú |
|------------|-------|---------------|---------|
| **Khanh** | P1-00~05, P1-10~15, P1-20~27, P1-60~61, P1-70~74, P1-80~81, P1-83 | ~15.5 ngày | Khởi tạo + Contracts + Hooks + BSCClient + PriceService + **Prod Infra** + Integration |
| **Huy** | P1-30~42, P1-80~82 | ~12 ngày | DApp UI toàn bộ + apiClient + Integration |
| **Hộp** | P1-50~58, P1-82 | ~9 ngày | Express + DB + Repositories + Services + Routes |

> ⚠️ **Ghi chú**: Hộp có ít task hơn do Phase 1 không có Auth, Admin, OHLCV, Indexer. Hộp nên dùng thời gian dư để viết **unit test backend** cho Services/Routes và chuẩn bị migration Phase 2. Khanh nhận thêm Production Infrastructure (~2.5 ngày) để đảm bảo MVP sẵn sàng deploy production.

---

## Integration Points — Điểm Phối hợp

| Điểm tích hợp | Thành viên liên quan | File/Module chung | Quy tắc |
|---|---|---|---|
| ABI + Contract Addresses | Khanh → Huy | `contracts.ts`, `tokens.ts` | Khanh tạo trước + export interface, Huy import |
| wagmi Hooks → UI Pages | Khanh → Huy | `useSwap.ts`, `useLiquidity.ts` | Khanh export hook API, Huy gọi trong page component |
| TokenSelector sử dụng trên SwapPage & PoolPage | Khanh → Huy | `TokenSelector.tsx` | Khanh tạo component, Huy tích hợp vào layout |
| BSCClient → PriceService → Price Route | Khanh → Hộp | `BSCClient.ts`, `PriceService.ts` | Khanh tạo BSCClient + PriceService, Hộp tạo route gọi service |
| apiClient → Backend Routes | Huy → Hộp | `apiClient.ts` ↔ routes | Hộp export API contract (URL + response format), Huy gọi theo spec |
| Docker PostgreSQL/Redis | Khanh → Hộp | `docker-compose.dev.yml` | Khanh setup containers, Hộp dùng connection string từ `.env` |
| Init SQL scripts ← Migrations | Khanh ← Hộp | `01_init_schema.sql` ← migration files | Hộp viết migrations, Khanh merge thành init script cho production |
| Production Docker → All services | Khanh → Team | `docker-compose.yml`, `Dockerfile` | Khanh config, team verify mỗi service chạy đúng trong container |

---

## Critical Path

**Path A — Feature (longest):**
```
P1-00 (Init) → P1-10 (Core contracts) → P1-13 (Periphery) → P1-14 (Tests)
→ P1-15 (Deploy) → P1-20 (contracts.ts) → P1-22 (wagmi hooks) → P1-27 (SwapButton)
→ P1-80 (Swap integration) → P1-81 (Pool integration) → P1-84 (E2E smoke test)
```

**Path B — Production Infra:**
```
P1-00 (Init) → P1-70 (Prod Docker) → P1-72 (Nginx) → P1-73 (SSL)
→ P1-83 (Prod build test) → P1-84 (E2E smoke test prod mode)
```

**Thời gian critical path**: ~16 ngày làm việc (3.5 tuần) — Path A và B chạy song song, hội tụ tại E2E test

---

## Sprint Plan

> Chi tiết các Sprints được quy định trong file [sprints.md](./sprints.md).
