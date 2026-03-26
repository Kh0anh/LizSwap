# C4 Level 3 – Component Diagram: Frontend

## LizSwap Frontend Apps

Lớp Frontend của LizSwap gồm 2 ứng dụng **Next.js** riêng biệt (hoặc 2 app trong monorepo):
- **DApp Frontend**: Giao diện người dùng công khai — Trader & Liquidity Provider.
- **Admin Dashboard**: Giao diện quản trị nội bộ — Manager & Staff.

Cả hai đều dùng **wagmi + viem** để tương tác on-chain và **MetaMask** để ký giao dịch.

---

## Kiến trúc tổng quan – Frontend Layer

**DApp Frontend** `(Next.js + wagmi + viem)`
- Pages: `/swap`, `/pool`, `/pool/add`, `/pool/remove`, `/stake`
- Shared: `WalletConnector` (wagmi), `ContractHooks` (viem), `APIClient` (REST/WS)
- On-chain writes → MetaMask → BSC
- Off-chain reads → Backend API (giá, OHLCV, pool stats)

**Admin Dashboard** `(Next.js + REST)`
- Pages: `/login`, `/dashboard`, `/users`, `/config`, `/pools`, `/activity`
- Shared: `AuthGuard` (JWT), `APIClient`, `RoleGuard` (Manager/Staff)
- Không giao tiếp on-chain trực tiếp — chỉ qua Backend API

---

## Diagram 1 – Tổng thể Frontend Components

```mermaid
C4Component
  title Component Diagram – Frontend Layer (LizSwap)

  Container(metamaskExt, "MetaMask", "Browser Extension", "Ký giao dịch BSC")
  Container(backendExt, "Backend API", "Node.js + Express", "REST & WebSocket")
  Container(routerExt, "LizSwapRouter", "Solidity", "Thực thi swap/liquidity on-chain")
  Container(stakingExt, "LizSwapStaking", "Solidity", "Stake/Unstake LP Token on-chain")
  Container(factoryExt, "LizSwapFactory", "Solidity", "Kiểm tra pool tồn tại")

  Container_Boundary(dapp, "DApp Frontend (Next.js + wagmi + viem)") {
    Component(walletConn, "WalletConnector", "wagmi useConnect", "Kết nối MetaMask, quản lý account/chain state")
    Component(swapPage, "SwapPage", "Next.js Page", "Giao diện swap token, hiển thị giá & slippage")
    Component(poolPage, "PoolPage", "Next.js Page", "Danh sách pools, TVL, APR, nút Add/Remove")
    Component(addLiqPage, "AddLiquidityPage", "Next.js Page", "Form thêm thanh khoản, tính optimal amounts")
    Component(removeLiqPage, "RemoveLiquidityPage", "Next.js Page", "Form rút thanh khoản, hiển thị LP token balance")
    Component(stakePage, "StakePage", "Next.js Page", "Stake/Unstake LP Token, hiển thị pending reward")
    Component(chartWidget, "CandlestickChart", "lightweight-charts", "Render chart nến hoặc thông báo không có dữ liệu")
    Component(contractHooks, "ContractHooks", "wagmi useContractWrite/Read", "Hook tái sử dụng: swap, addLiquidity, stake, getReserves")
    Component(dappApiClient, "APIClient", "axios + WebSocket", "Gọi Backend API: giá, OHLCV, pool stats")
    Component(tokenSelector, "TokenSelector", "React Component", "Tìm kiếm & chọn token từ danh sách pool")
    Component(txToast, "TxToast", "React Component", "Thông báo trạng thái giao dịch: pending/success/failed")
  }

  Container_Boundary(adminApp, "Admin Dashboard (Next.js + REST)") {
    Component(loginPage, "LoginPage", "Next.js Page", "Đăng nhập bằng wallet signature (EIP-191)")
    Component(authGuard, "AuthGuard", "Next.js Middleware", "Kiểm tra JWT, redirect nếu chưa đăng nhập")
    Component(roleGuard, "RoleGuard", "React Context", "Ẩn/hiện UI theo role Manager/Staff")
    Component(dashboardPage, "DashboardPage", "Next.js Page", "Tổng quan: volume, TVL, active users (Manager + Staff)")
    Component(usersPage, "UsersPage", "Next.js Page", "Danh sách user/role, thêm/vô hiệu hoá Staff (Manager only)")
    Component(configPage, "ConfigPage", "Next.js Page", "Cập nhật system_config: fee, reward/block (Manager only)")
    Component(poolsAdminPage, "PoolsMonitorPage", "Next.js Page", "Theo dõi pool stats, TVL, volume (Manager + Staff)")
    Component(activityPage, "ActivityPage", "Next.js Page", "Lịch sử Swap/Mint/Burn, filter theo pair (Manager + Staff)")
    Component(adminApiClient, "APIClient", "axios", "Gọi Backend /api/admin/* với JWT Bearer")
  }

  %% DApp: Wallet connection
  Rel(walletConn, metamaskExt, "eth_requestAccounts / signMessage", "EIP-1193")

  %% DApp pages → Wallet & Contract Hooks
  Rel(swapPage, walletConn, "Lấy account & chain", "wagmi hook")
  Rel(swapPage, contractHooks, "executeSwap()", "wagmi useContractWrite")
  Rel(swapPage, dappApiClient, "GET /api/prices/:token", "REST")
  Rel(swapPage, chartWidget, "Truyền pair & interval", "React props")

  Rel(poolPage, dappApiClient, "GET /api/pools", "REST")
  Rel(poolPage, contractHooks, "getReserves() / getPair()", "wagmi useContractRead")

  Rel(addLiqPage, contractHooks, "addLiquidity(tokenA, tokenB, amounts)", "wagmi useContractWrite")
  Rel(removeLiqPage, contractHooks, "removeLiquidity(pair, liquidity)", "wagmi useContractWrite")

  Rel(stakePage, contractHooks, "stake() / unstake() / claimReward()", "wagmi useContractWrite")
  Rel(stakePage, contractHooks, "pendingReward(address)", "wagmi useContractRead")

  %% Chart widget → API
  Rel(chartWidget, dappApiClient, "GET /api/ohlcv?token0&token1&interval", "REST")

  %% Contract Hooks → On-chain
  Rel(contractHooks, routerExt, "swapExactTokensForTokens / addLiquidity", "viem writeContract")
  Rel(contractHooks, stakingExt, "stake / unstake / claimReward", "viem writeContract")
  Rel(contractHooks, factoryExt, "getPair(tokenA, tokenB)", "viem readContract")

  %% DApp WS → Backend
  Rel(dappApiClient, backendExt, "REST + WebSocket: price, OHLCV, pool stats", "HTTPS / WS")

  %% Tx notification
  Rel(contractHooks, txToast, "Emit tx hash / error", "React event")

  %% Admin: Auth flow
  Rel(loginPage, walletConn, "Ký message với MetaMask", "EIP-191")
  Rel(loginPage, adminApiClient, "POST /api/auth/login (signature)", "REST HTTPS")
  Rel(authGuard, adminApiClient, "Verify JWT trên mỗi navigation", "Next.js Middleware")

  %% Admin pages
  Rel(dashboardPage, adminApiClient, "GET /api/pools, /api/admin/*", "REST")
  Rel(usersPage, adminApiClient, "GET/POST/DELETE /api/admin/users", "REST")
  Rel(configPage, adminApiClient, "GET/PUT /api/admin/config", "REST")
  Rel(poolsAdminPage, adminApiClient, "GET /api/pools/:pair/stats", "REST")
  Rel(activityPage, adminApiClient, "GET /api/ohlcv, /api/admin/activity", "REST")

  %% Admin API → Backend
  Rel(adminApiClient, backendExt, "REST /api/admin/* với JWT Bearer", "HTTPS")

  UpdateLayoutConfig($c4ShapeInRow="4", $c4BoundaryInRow="1")
```

---

## Diagram 2 – Chi tiết SwapPage & CandlestickChart

```mermaid
C4Component
  title Component Diagram – SwapPage & Candlestick Chart Logic

  Container_Boundary(swap_boundary, "SwapPage") {
    Component(tokenIn, "TokenInSelector", "React", "Chọn token đầu vào, nhập amount")
    Component(tokenOut, "TokenOutSelector", "React", "Chọn token đầu ra, hiển thị estimated amount")
    Component(slippageCtrl, "SlippageControl", "React", "Cài đặt slippage tolerance (default 0.5%)")
    Component(priceImpact, "PriceImpactBadge", "React", "Hiển thị cảnh báo nếu price impact > 2%")
    Component(swapBtn, "SwapButton", "React", "Trigger approve (nếu cần) → executeSwap()")
    Component(routeInfo, "RouteDisplay", "React", "Hiển thị lộ trình swap: A → B hoặc A → BNB → B")
  }

  Container_Boundary(chart_boundary, "CandlestickChart") {
    Component(chartLoader, "ChartLoader", "React", "Gọi API, xử lý loading / error state")
    Component(noDataMsg, "NoDataMessage", "React", "Hiển thị 'Không có dữ liệu chart' nếu NO_DIRECT_POOL")
    Component(candleRenderer, "CandleRenderer", "lightweight-charts", "Render nến OHLCV, cập nhật realtime qua WS")
    Component(intervalPicker, "IntervalPicker", "React", "Chọn khung thời gian: 1m / 5m / 1h / 1d")
  }

  Component(apiClientS, "APIClient", "axios + WS", "Gọi /api/ohlcv, subscribe WS ohlcv:new_candle")
  Component(contractH, "ContractHooks", "wagmi", "getAmountsOut, executeSwap")
  Component(backendS, "Backend API", "Node.js", "Trả OHLCV hoặc NO_DIRECT_POOL")

  Rel(tokenIn, contractH, "getAmountsOut(amountIn, [tokenIn, tokenOut])", "wagmi useContractRead")
  Rel(contractH, tokenOut, "Cập nhật estimated output + price impact", "React state")
  Rel(swapBtn, contractH, "executeSwap(tokenIn, tokenOut, amountIn, slippage)", "wagmi useContractWrite")
  Rel(priceImpact, contractH, "Đọc priceImpact từ getAmountsOut", "React props")
  Rel(routeInfo, contractH, "Hiển thị path[] từ router", "React props")

  Rel(tokenIn, chartLoader, "Thay đổi pair → reload chart", "React effect")
  Rel(tokenOut, chartLoader, "Thay đổi pair → reload chart", "React effect")
  Rel(intervalPicker, chartLoader, "Thay đổi interval → reload chart", "React effect")
  Rel(chartLoader, apiClientS, "GET /api/ohlcv?token0&token1&interval", "REST")
  Rel(apiClientS, backendS, "Fetch OHLCV data", "HTTPS")
  Rel(apiClientS, chartLoader, "Trả candle[] hoặc NO_DIRECT_POOL", "Promise")
  Rel(chartLoader, candleRenderer, "Truyền candle data", "React props")
  Rel(chartLoader, noDataMsg, "Nếu NO_DIRECT_POOL → render thông báo", "React condition")
  Rel(apiClientS, candleRenderer, "WS: ohlcv:new_candle → update realtime", "WebSocket")

  UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

---

## Diagram 3 – Chi tiết PoolPage & Liquidity Flow

```mermaid
C4Component
  title Component Diagram – PoolPage & Liquidity Management

  Container_Boundary(pool_boundary, "PoolPage") {
    Component(poolList, "PoolList", "React", "Danh sách pools: pair name, TVL, APR, 24h volume")
    Component(myPositions, "MyPositions", "React", "LP token balance & pool share của user hiện tại")
    Component(addBtn, "AddLiquidityButton", "React", "Chuyển đến /pool/add?token0=&token1=")
    Component(removeBtn, "RemoveLiquidityButton", "React", "Chuyển đến /pool/remove?pair=")
  }

  Container_Boundary(addliq_boundary, "AddLiquidityPage") {
    Component(tokenAPicker, "TokenA Picker", "React", "Chọn tokenA, nhập amount")
    Component(tokenBPicker, "TokenB Picker", "React", "Chọn tokenB, tự tính amount theo reserves")
    Component(lpPreview, "LP Token Preview", "React", "Hiển thị LP token sẽ nhận, pool share %")
    Component(approveBtnA, "ApproveButton (A)", "React", "Approve tokenA cho Router nếu allowance < amount")
    Component(approveBtnB, "ApproveButton (B)", "React", "Approve tokenB cho Router nếu allowance < amount")
    Component(confirmAddBtn, "ConfirmAddButton", "React", "Gọi addLiquidity() trên Router")
  }

  Container_Boundary(removeliq_boundary, "RemoveLiquidityPage") {
    Component(lpSlider, "LP Amount Slider", "React", "Chọn % LP token muốn rút (25/50/75/100%)")
    Component(receivePreview, "ReceivePreview", "React", "Hiển thị token0 + token1 sẽ nhận lại")
    Component(approveLP, "ApproveLP Button", "React", "Approve LP token cho Router")
    Component(confirmRemoveBtn, "ConfirmRemoveButton", "React", "Gọi removeLiquidity() trên Router")
  }

  Component(contractHP, "ContractHooks", "wagmi", "getReserves, addLiquidity, removeLiquidity, allowance")
  Component(apiClientP, "APIClient", "axios", "GET /api/pools, /api/pools/:pair/stats")
  Component(backendP, "Backend API", "Node.js", "Pool stats: TVL, volume, APR")

  Rel(poolList, apiClientP, "GET /api/pools", "REST")
  Rel(apiClientP, backendP, "Fetch pool list & stats", "HTTPS")
  Rel(myPositions, contractHP, "balanceOf(user) trên Pair contract", "wagmi useContractRead")

  Rel(tokenAPicker, contractHP, "getReserves() → tính token B amount", "wagmi useContractRead")
  Rel(approveBtnA, contractHP, "approve(Router, amountA)", "wagmi useContractWrite")
  Rel(approveBtnB, contractHP, "approve(Router, amountB)", "wagmi useContractWrite")
  Rel(confirmAddBtn, contractHP, "addLiquidity(tokenA, tokenB, amts, deadline)", "wagmi useContractWrite")
  Rel(lpPreview, contractHP, "Tính LP = sqrt(amtA * amtB) - MINIMUM_LIQUIDITY", "wagmi useContractRead")

  Rel(lpSlider, contractHP, "balanceOf(user) → tính amount LP", "wagmi useContractRead")
  Rel(receivePreview, contractHP, "Tính token0/1 trả về theo LP * reserves / totalSupply", "wagmi compute")
  Rel(approveLP, contractHP, "approve(Router, lpAmount)", "wagmi useContractWrite")
  Rel(confirmRemoveBtn, contractHP, "removeLiquidity(tokenA, tokenB, lp, min, deadline)", "wagmi useContractWrite")

  UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

---

## Diagram 4 – Chi tiết Admin Dashboard & Role Guard

```mermaid
C4Component
  title Component Diagram – Admin Dashboard & Role Guard

  Container_Boundary(admin_boundary, "Admin Dashboard (Next.js)") {
    Component(loginP, "LoginPage", "Next.js Page", "Kết nối ví, ký message EIP-191, nhận JWT")
    Component(authGuardA, "AuthGuard", "Next.js Middleware", "Redirect /login nếu không có JWT hợp lệ")
    Component(roleCtx, "RoleContext", "React Context", "Lưu role: manager | staff, expose useRole()")
    Component(sidebar, "Sidebar", "React", "Menu điều hướng, ẩn các mục Manager-only với Staff")

    Component(dashP, "DashboardPage", "Next.js Page", "Tổng quan: 24h volume, TVL, active wallets")
    Component(usersP, "UsersPage", "Next.js Page", "Thêm Staff, cập nhật role, vô hiệu hoá (Manager only)")
    Component(configP, "ConfigPage", "Next.js Page", "Cài đặt: protocol fee, reward/block (Manager only)")
    Component(poolsP, "PoolsMonitorPage", "Next.js Page", "Theo dõi pool stats realtime (Manager + Staff)")
    Component(activityP, "ActivityPage", "Next.js Page", "Lịch sử giao dịch, filter pair/time (Manager + Staff)")
  }

  Component(adminApi, "APIClient", "axios", "Gọi /api/admin/* với JWT Bearer header")
  Component(backendAdmin, "Backend API", "Node.js", "Xác thực JWT, kiểm tra role, trả dữ liệu")

  Rel(loginP, adminApi, "POST /api/auth/login {address, signature}", "REST HTTPS")
  Rel(adminApi, loginP, "Trả JWT token + role", "JSON")
  Rel(loginP, roleCtx, "Lưu JWT + role vào Context & localStorage", "React state")
  Rel(authGuardA, roleCtx, "Đọc JWT, parse role", "Next.js Middleware")
  Rel(sidebar, roleCtx, "useRole() → ẩn menu Manager-only với Staff", "React")

  Rel(dashP, adminApi, "GET /api/pools, /api/admin/stats", "REST")
  Rel(usersP, adminApi, "GET /api/admin/users", "REST")
  Rel(usersP, adminApi, "POST /api/admin/users (Manager only)", "REST")
  Rel(usersP, adminApi, "DELETE /api/admin/users/:id (Manager only)", "REST")
  Rel(configP, adminApi, "GET/PUT /api/admin/config (Manager only)", "REST")
  Rel(poolsP, adminApi, "GET /api/pools/:pair/stats", "REST")
  Rel(activityP, adminApi, "GET /api/ohlcv, /api/admin/activity", "REST")

  Rel(adminApi, backendAdmin, "HTTPS với JWT Bearer", "REST HTTPS")

  UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

---

## Page Map tổng hợp

### DApp Frontend

| Route | Component | Actors | Tính năng chính |
|---|---|---|---|
| `/swap` | SwapPage | Trader, LP | Chọn cặp, nhập amount, xem chart, thực thi swap |
| `/pool` | PoolPage | Trader, LP | Danh sách pool, TVL/APR, LP balance cá nhân |
| `/pool/add` | AddLiquidityPage | LP | Nhập 2 token, approve, thêm thanh khoản |
| `/pool/remove` | RemoveLiquidityPage | LP | Chọn % LP, preview output, rút thanh khoản |
| `/stake` | StakePage | LP | Stake/Unstake LP Token, claim reward |

### Admin Dashboard

| Route | Roles | Tính năng chính |
|---|---|---|
| `/login` | Manager, Staff | Đăng nhập bằng wallet signature |
| `/dashboard` | Manager, Staff | Tổng quan hệ thống |
| `/pools` | Manager, Staff | Theo dõi pool stats |
| `/activity` | Manager, Staff | Lịch sử giao dịch |
| `/users` | **Manager only** | Quản lý Staff |
| `/config` | **Manager only** | Cấu hình hệ thống & contract |

---

## Ghi chú thiết kế

> [!IMPORTANT]
> **Chart logic tại Frontend**: `CandlestickChart` kiểm tra response từ API — nếu nhận `{ error: 'NO_DIRECT_POOL' }` thì render `NoDataMessage`, không render chart. Không có fallback tự tính từ multi-hop.

> [!IMPORTANT]
> **Role Guard tại Admin**: Trang `/users` và `/config` phải kiểm tra role ở **cả 2 tầng**: React (ẩn UI) và Backend API (403 Forbidden). Không chỉ dựa vào UI-level.

> [!NOTE]
> **Approve flow**: Trước khi `addLiquidity` hoặc `swap`, Frontend phải kiểm tra `allowance` hiện tại. Nếu `allowance < amount` → hiển thị nút **Approve** và đợi tx confirm trước khi tiếp tục.

> [!NOTE]
> **wagmi + viem**: Dùng `useContractWrite` cho write transactions (swap, addLiquidity, stake), `useContractRead` cho view calls (getReserves, balanceOf, pendingReward). Tất cả metadata contract (ABI, address) lưu trong `src/constants/contracts.ts`.
