# Phase 1 — Sprint Plan

---

## Sprint 1 (Ngày 1–5): Foundation

| Người | Task chính |
|-------|-----------|
| **Khanh** | P1-00~05 (Init monorepo, 1 ngày) → P1-10~12 (Core contracts, 1 ngày) → P1-13 (Router, 0.5 ngày) → P1-14 (Tests, 1 ngày) → P1-15 (Deploy, 0.5 ngày) |
| **Huy** | (Đợi P1-00) → P1-30 (DApp layout, 1 ngày) → P1-31~34 (SwapPage UI, 2 ngày) → P1-42 (apiClient, 0.5 ngày) |
| **Hộp** | (Đợi P1-00) → P1-50 (Express setup, 1 ngày) → P1-51 (Migrations, 1 ngày) → P1-52 (PgRepo, 1 ngày) → P1-53 (RedisRepo, 1 ngày) |

---

## Sprint 2 (Ngày 6–10): Core Features

| Người | Task chính |
|-------|-----------|
| **Khanh** | P1-20 (contracts.ts, 0.5 ngày) → P1-21 (WalletConnector, 1 ngày) → P1-22~24 (wagmi hooks, 1.5 ngày) → P1-25 (TxToast, 0.5 ngày) → P1-26 (TokenSelector, 1 ngày) |
| **Huy** | P1-35~37 (PoolPage UI, 1.5 ngày) → P1-38~39 (AddLiquidity UI, 1.5 ngày) → P1-40~41 (RemoveLiquidity UI, 1.5 ngày) |
| **Hộp** | P1-54 (Zod, 0.5 ngày) → P1-55 (PoolService, 1.5 ngày) → P1-56 (Pool routes, 1 ngày) → P1-58 (Health check, 0.5 ngày) |

---

## Sprint 3 (Ngày 11–15): Backend On-chain + Production Infra + Integration

| Người | Task chính |
|-------|-----------|
| **Khanh** | P1-27 (SwapButton, 0.5 ngày) → P1-60 (BSCClient, 1 ngày) → P1-61 (PriceService, 1 ngày) → P1-70~71 (Prod Docker + Dockerfiles, 1 ngày) → P1-72 (Nginx, 0.5 ngày) |
| **Huy** | P1-80 (Swap integration, 0.5 ngày) → P1-81 (Pool integration, 0.5 ngày) → P1-82 (FE-BE integration, 1 ngày) → Buffer / UI polish |
| **Hộp** | P1-57 (Price route, 0.5 ngày) → P1-82 (FE-BE integration, 0.5 ngày) → Unit tests for services/routes (buffer) |

---

## Sprint 4 (Ngày 16–20): Production Deploy + QA

| Người | Task chính |
|-------|-----------|
| **Khanh** | P1-73 (Certbot SSL, 0.5 ngày) → P1-74 (PG init scripts, 0.5 ngày) → P1-83 (Prod build test, 0.5 ngày) → P1-80~81 (Swap/Pool integration, 1 ngày) → Bug fixes |
| **Huy** | UI polish → Responsive testing → Bug fixes |
| **Hộp** | Unit tests backend → Chuẩn bị migration Phase 2 → Bug fixes |
| **Team** | P1-84 (E2E smoke test dev + production mode, 1-2 ngày) → Code review → Merge to develop |

---

## Timeline Gantt Chart

```mermaid
gantt
    title Phase 1 — MVP + Production Timeline (LizSwap)
    dateFormat  YYYY-MM-DD
    axisFormat  %d/%m

    section Khanh
    Init Monorepo (P1-00~05)           :p100, 2026-04-07, 1d
    Core Contracts (P1-10~12)          :p110, after p100, 1d
    Router + Mock (P1-13)              :p113, after p110, 0.5d
    Contract Tests (P1-14)             :p114, after p113, 1d
    Deploy BSC Testnet (P1-15)         :p115, after p114, 0.5d
    contracts.ts + tokens.ts (P1-20)   :p120, after p115, 0.5d
    WalletConnector (P1-21)            :p121, after p100, 1d
    wagmi hooks (P1-22~24)             :p122, after p120, 1.5d
    TxToast (P1-25)                    :p125, after p100, 0.5d
    TokenSelector (P1-26)              :p126, after p122, 1d
    SwapButton (P1-27)                 :p127, after p122, 0.5d
    BSCClient (P1-60)                  :p160, after p115, 1d
    PriceService (P1-61)               :p161, after p160, 1d
    Prod Docker + Dockerfiles (P1-70~71) :p170, after p161, 1d
    Nginx Prod (P1-72)                 :p172, after p170, 0.5d
    Certbot SSL (P1-73)                :p173, after p172, 0.5d
    PG Init Scripts (P1-74)            :p174, after p173, 0.5d
    Swap Integration (P1-80)           :p180, after p127, 0.5d
    Pool Integration (P1-81)           :p181, after p180, 0.5d
    Prod Build Test (P1-83)            :p183, after p174, 0.5d

    section Huy
    DApp Layout (P1-30)                :p130, after p100, 1d
    SwapPage UI (P1-31~34)             :p131, after p130, 2d
    apiClient (P1-42)                  :p142, after p100, 0.5d
    PoolPage UI (P1-35~37)             :p135, after p131, 1.5d
    AddLiquidity UI (P1-38~39)         :p138, after p135, 1.5d
    RemoveLiquidity UI (P1-40~41)      :p140, after p135, 1.5d
    Swap Integration (P1-80h)          :p180h, after p131, 0.5d
    Pool Integration (P1-81h)          :p181h, after p138, 0.5d
    FE-BE Integration (P1-82)          :p182h, after p181h, 1d

    section Hộp
    Express Setup (P1-50)              :p150, after p100, 1d
    DB Migrations (P1-51)              :p151, after p150, 1d
    PostgresRepository (P1-52)         :p152, after p151, 1d
    RedisRepository (P1-53)            :p153, after p150, 1d
    Zod Validation (P1-54)             :p154, after p150, 0.5d
    PoolService (P1-55)                :p155, after p152, 1.5d
    Pool Routes (P1-56)                :p156, after p155, 1d
    Price Route (P1-57)                :p157, after p161, 0.5d
    Health Check (P1-58)               :p158, after p150, 0.5d

    section Team
    E2E Smoke Test (P1-84)             :p184, after p183, 2d
    Bug Fixes & Polish                 :after p184, 3d
```

---

## Risk Assessment

| Risk | Mức độ | Mitigation |
|------|--------|------------|
| Khanh là bottleneck (Init + Contracts + Hooks + Prod Infra) | 🔴 Cao | Ưu tiên Init ngày 1, contracts ngày 2-3. Prod Infra chạy song song Sprint 3-4 khi feature code ổn |
| ABI chưa export → Frontend bị block | 🟡 Trung bình | Khanh export ABI ngay sau `forge build`, không cần đợi deploy xong |
| Docker Compose không chạy trên máy thành viên | 🟡 Trung bình | Khanh test Docker trên cả 3 máy trước khi merge |
| Wagmi hooks bị bug khi test trên BSC Testnet | 🟡 Trung bình | Dùng Anvil local fork để test trước, chuyển Testnet sau |
| PoolService cần data on-chain nhưng BSCClient chưa sẵn sàng | 🟡 Trung bình | Hộp mock BSCClient interface, Khanh implement sau |
| 2 người cùng sửa `apiClient.ts` | 🟢 Thấp | Huy tạo file trước + export interface, Hộp chỉ review API contract |
| Production Docker build fail do multi-stage config | 🟡 Trung bình | Test production build local trước khi VPS. Dùng `docker compose --profile prod up` |
| Certbot SSL lần đầu cấu hình trên VPS | 🟡 Trung bình | Dùng Let's Encrypt staging trước, chuyển production sau. Script `init-letsencrypt.sh` có sẵn reference |
| Nginx proxy config sai → 502 Bad Gateway | 🟢 Thấp | Test Nginx config local bằng `nginx -t`, verify proxy upstream trước khi SSL |
