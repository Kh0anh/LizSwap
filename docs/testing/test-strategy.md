# LizSwap – Testing Strategy

Tài liệu này định nghĩa chiến lược kiểm thử (Testing Strategy) toàn diện cho dự án LizSwap (v1). Vì dự án không chạy CI/CD Pipeline, toàn bộ test suite phải được chạy thủ công và đạt chỉ tiêu Coverage Target trước khi tiến hành Audit hoặc Deploy lên mạng chính thức (Mainnet).

---

## 1. Smart Contract Tests (Foundry)

Việc kiểm thử Smart Contract là ưu tiên cao nhất, được thực hiện bằng **Foundry**. Mục tiêu là mô phỏng các tương tác thực tế và ngăn chặn các lỗ hổng bảo mật AMM cơ bản.

-   **Công cụ:** Foundry (`forge test`, `anvil`)
-   **Coverage Target:** `>= 90%` đối với Core contracts (`Factory`, `Pair`).

### Các File Test Tương Ứng trong `contracts/test/`

-   `contracts/test/core/Factory.t.sol`: Unit test cho `LizSwapFactory`. Kiểm tra tính toàn vẹn của `createPair()`, cấu hình `feeTo` và quản lý danh sách Pair.
-   `contracts/test/core/Pair.t.sol`: Unit test cho `LizSwapPair`. Kiểm tra AMM logic (x*y=k, mint, burn, hoán đổi dự trữ), fee protocol, thư viện toán học.
-   `contracts/test/periphery/Router.t.sol`: Unit test cho `LizSwapRouter`. Kiểm tra slippage protection, deadline logic, routing path, tối ưu pool reserve, và tương tác an toàn với Pair.
-   `contracts/test/periphery/Staking.t.sol`: Unit test cho `LizSwapStaking`. Kiểm tra tính toán block reward, cấp số nhân thưởng (`accRewardPerShare`), thêm/rút LP Tokens.
-   `contracts/test/integration/SwapFlow.t.sol`: Integration test mô phỏng toàn bộ vòng đời End-to-End: `deploy → createPair → addLiquidity → swap → removeLiquidity`.

### Các Test Case Quan Trọng

-   **Swap Invariant & Fee Calculation:** Đảm bảo hằng số `k` luôn tăng hoặc giữ nguyên sau mỗi lần hoán đổi (hoặc khi trừ các loại fee). Xác minh chính xác phí giao thức (0.3% pool fee, cơ chế rút 0.05% protocol fee).
-   **Slippage Protection:** Kiểm tra Router liên tục từ chối giao dịch khi nhận được ít hơn `amountOutMin` hoặc phải trả nhiều hơn `amountInMax`.
-   **Deadline Logic:** Đảm bảo modifier `ensure(deadline)` của Router hoạt động từ chối giao dịch bị mốc thời gian quá trễ (chặn MEV front-running attack trên mempool).
-   **Reentrancy Guard:** Đảm bảo lock modifier chặn triệt để tấn công Reentrancy trên các lệnh đổi trạng thái nhạy cảm `mint`, `burn`, và `swap` của `LizSwapPair`.
-   **Permit (EIP-2612):** Xác minh chức năng duyệt chữ ký (signature verify v, r, s) thay vì Approve Token trước trên LP Tokens hoạt động chính xác.
-   **Fork Test BSC:** Local fork sử dụng `anvil --fork-url <BSC_RPC>` để mô phỏng tương tác nội bộ dự án cùng với một số DEX Liquidity có sẵn trên Binance Smart Chain Mainnet.

---

## 2. Backend API Tests

Backend API xử lý dữ liệu và xác thực quan trọng cho Dashboard, do đó việc kiểm tra các Backend Services, Routes và Middleware là bắt buộc. Framework đồng bộ thống nhất là **Vitest**.

-   **Framework Test:** Vitest + Supertest (cho HTTP Route testing test Database).

### Các File Test Tương Ứng trong `packages/backend/test/`

-   `packages/backend/test/services/PriceService.test.ts`: Unit test mock Redis + Mock BSC RPC (viem) verify luồng lấy giá gốc an toàn.
-   `packages/backend/test/services/PoolService.test.ts`: Unit test cô lập logic tổng hợp TVL, Volume, và APR bỏ qua Database Query.
-   `packages/backend/test/services/OHLCVService.test.ts`: Verify check Pool tồn tại gọi mock `Factory.getPair`.
-   `packages/backend/test/routes/auth.integration.test.ts`: Integration test toàn bộ E2E Auth API.
-   `packages/backend/test/routes/admin.integration.test.ts`: Integration test xác thực phân quyền Role (Manager/Staff API authorization).

### Test Flow Điển Hình

-   **Unit Tests Services:** Bị cô lập thành Unit Functions thông qua Mock Dependencies (Redis - ioredis, Postgres - pg, BSC RPC - viem).
-   **Integration Tests Routes:** Sử dụng Supertest với Test Database (Container rời) gửi JSON payload.
-   **Auth Flow Test (E2E Integration):** 
    1.  Mô phỏng Request Login ký payload chuyển lên POST `/api/auth/login`.
    2.  Nhận Bearer JWT token ở response.
    3.  Thực hiện payload truy cập thông tin quản trị hệ thống (vd: GET `/api/admin/users`) với header JWT cung cấp.
    4.  Gọi POST `/api/auth/logout` báo server logout.
    5.  Kiểm tra Request truy cập `/api/admin/users` lần nữa bằng JWT cũ đảm bảo Redis Blacklist đã cản trở kết nối.

---

## 3. Frontend Tests

Đảm bảo trải nghiệm người dùng tối ưu qua giao diện DApp/Admin chuẩn (kết nối Web3, swap parameters input) trên Next.js App Router.

-   **Framework Test:** Vitest + React Testing Library (RTL). Tái sử dụng engine của backend cho frontend.

### Bố Cục Thử Nghiệm

-   **Component Tests:** Sử dụng `render` từ RTL render các core UI Component để xác minh Form validation, rendering state (`TokenSelector`, `SlippageControl`, `SwapButton`, `PoolList`).
-   **Hook Tests:** Sử dụng `@testing-library/react-hooks` (renderHook utility) để kiểm tra các custom React Hook tính toán logic độc lập giao diện:
    -   `useSwap.ts`: Verify logic ước lượng path slippage, parse amount inputs chuẩn xác, format giao dịch swap, và viem contract call state.
    -   `useLiquidity.ts`: Mô phỏng tính toán optimal token ratios add/remove liquidity, và tiến trình EIP-2612.
    -   `useStaking.ts`: Xác minh việc view pending reward tính toán realtime và format số lớn.
-   **E2E Testing (Lựa chọn - Optional v1):** Sử dụng Playwright nếu dự án tiến hành E2E Browser Test qua Synpress để Mock Metamask extension giả lập End-to-End User Journey.

---

## 4. Indexer Tests

BSC Indexer bắt buộc phải luôn tính toán chính xác số liệu thanh khoản, nến OHLCV sau chuỗi log blockchain. Bug ở đây sẽ làm lệch giao diện biểu đồ và stat tổng dự án.

-   **Framework Test:** Vitest (Không yêu cầu UI).

### Các Test Case Trọng Tâm

-   **Unit test CandleBuilder.ts:**
    1. Cung cấp dữ liệu Event giả lập đầu vào của `Swap(sender, amount0In, amount1In, amount0Out, amount1Out, to)`.
    2. Verify `CandleBuilder.parseSwapEvent()` dịch ngược Price dựa trên dữ liệu Decimals của Contract lưu trong PairRegistry.
    3. Kiểm tra Array Output OHLCV xem giá `open`, `high`, `low`, `close` và tổng `volume` gộp theo khung (vd: 15m) đầu ra có chính xác như kỳ vọng.
-   **Unit test PairRegistry.ts:** Mock hàm `allPairs` gọi vào RPC Address để verify mảng Pair và decimals được Sync an toàn sau reboot.
-   **Integration test File Pipeline:** Kết hợp EventListener mock → Đẩy Event giả mạo → Pipeline Candle Builder Process → Write Batch vào Test-PGSQL DB. Verify toàn bộ Indexer Process Loop.

---

## 5. Bảng Mapping & Coverage Target

| Module | Component / Thư mục dự án | Phân loại kiểm thử Framework | Coverage Target |
|---|---|---|---|
| **Smart Contracts** | `contracts/src/core/` | Foundry (Unit Tests + Invariant math test) | **>= 90%** |
| **Smart Contracts** | `contracts/src/periphery/` | Foundry (Unit Tests / Safety flow constraint) | >= 80% |
| **Smart Contracts** | `contracts/src/` | Foundry (Integration / Full Swap flow tests) | Tối thiểu Pass |
| **Backend API** | `packages/backend/src/services/` | Vitest + Mock DB/RPC (Unit Tests function) | >= 80% |
| **Backend API** | `packages/backend/src/routes/` | Vitest + Supertest (Integration HTTP test) | >= 85% |
| **BSC Indexer** | `packages/indexer/src/CandleBuilder.ts`| Vitest (Unit Tests Event OHLCV Processing) | **>= 95%** |
| **BSC Indexer** | `packages/indexer/src/` | Vitest (Integration flow / Mock Web3 Event) | >= 70% |
| **Frontend DApp** | `apps/dapp/src/hooks/` | Vitest + RTL `renderHook` (Unit Tests) | >= 80% |
| **Frontend DApp** | `apps/dapp/src/components/` | Vitest + RTL (Component Tests DOM UI) | >= 60% |
| **System** | `DApp / Admin Frontend` | Playwright (E2E Browser Extension test) | *Optional (v1)* |

> [!CAUTION]
> **Quy Trình Triển Khai Thủ Công (Manual CI Check)**
> Do hệ thống backend và blockchain hiện tại thống nhất **KHÔNG dùng CI/CD (DevOps tự động hóa)**. Do đó, tất cả DEV team phải bắt buộc tự chạy thủ công Test Suite trên hệ thống cục bộ:
> 1. `forge test --gas-report` (Cho Contracts).
> 2. `npm run test --coverage` (Cho Monorepo backend/frontend workspace).
> Bất kỳ thao tác Deploy Mainnet nào cũng phải được thông báo thông qua các Report test phủ hợp lệ trước khi được Reviewer kiểm duyệt trên nhánh chính.
