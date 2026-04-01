# Error Handling Strategy – LizSwap

Tài liệu này định nghĩa chiến lược quản lý lỗi (Error Handling) toàn diện cho LizSwap, bao gồm các tầng Backend API, BSC Indexer, Frontend, và Health Checks, nhằm đảm bảo hệ thống vận hành ổn định, dễ debug và cung cấp trải nghiệm tốt cho người dùng.

Tham chiếu:
- [REST API Specification](../api/rest-api.md)
- [C4 Backend Architecture](./c4-components-backend.md)
- [C4 Frontend Architecture](./c4-components-frontend.md)
- [Tech Stack](./techstack.md)

---

## 1. Backend API Error Handling

### 1.1. Thống nhất Error Response Format
Tất cả lỗi từ Backend (Express REST API) đều phải trả về định dạng chuẩn (đã định nghĩa trong `rest-api.md`):

```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Mô tả lỗi chi tiết cho user/developer"
  }
}
```

### 1.2. Error Codes theo Module
Hệ thống sử dụng các Error Codes rõ ràng, được chia nhóm theo module:

**`AUTH_*` (Xác thực và phân quyền):**
- `INVALID_SIGNATURE`: Chữ ký MetaMask (EIP-191) không khớp.
- `TOKEN_EXPIRED`: JWT token đã quá hạn.
- `TOKEN_BLACKLISTED`: JWT đã bị vô hiệu hoá (logout).
- `INSUFFICIENT_ROLE`: User không có đủ quyền (`manager` / `staff`).

**`POOL_*` (Dữ liệu Pool/Cặp giao dịch):**
- `PAIR_NOT_FOUND`: Địa chỉ pair không tồn tại trên hệ thống.
- `NO_DIRECT_POOL`: Không có direct pool cho cặp token (trường hợp tính chart OHLCV).

**`VALIDATION_*` (Xác thực dữ liệu đầu vào):**
- `INVALID_PARAMS`: Params, Query, hoặc Body không hợp lệ (sai kiểu, thiếu field, ngoài phạm vi).
- `MISSING_REQUIRED_FIELD`: Trường bắt buộc bị thiếu.

**`SYSTEM_*` (Lỗi dịch vụ và hạ tầng):**
- `DB_ERROR`: Lỗi thao tác với PostgreSQL (timeout, connection refused).
- `REDIS_ERROR`: Không thể kết nối hoặc đọc/ghi Redis.
- `BSC_RPC_ERROR`: Node BSC Public/Private không phản hồi hoặc timeout.
- `INTERNAL_ERROR`: Lỗi hệ thống chung (Catch-all 500).

### 1.3. Express Error Middleware
Mọi exception trong các route / controllers sẽ được đẩy qua hàm `next(err)`. Express error middleware trung tâm sẽ:
1. Xác định phân loại lỗi và gán HTTP Status code tương ứng (`400`, `401`, `403`, `404`, `500`).
2. Ghi log ngoại lệ vào PM2 logs (kèm stack trace cụ thể nếu là lỗi `500`).
3. Transform lỗi về định dạng `error.code` và `error.message` đồng nhất gửi về Client.

### 1.4. Input Validation
Bắt buộc Validate mọi tham số (Params, Query, Body) bằng thư viện **Zod** trước khi thực thi logic trong controller.
- Express validation middleware sẽ catch Zod Error và tự động sinh mã lỗi `VALIDATION_*: INVALID_PARAMS` / `MISSING_REQUIRED_FIELD` với danh sách các field không hợp lệ cụ thể.

### 1.5. Security & CORS
- **CORS Config**: Giới hạn origins nghiêm ngặt trên môi trường Production, chỉ cho phép `https://lizswap.xyz` và `https://admin.lizswap.xyz`. Tuyệt đối không dùng `Access-Control-Allow-Origin: *`.
- **Security Headers**: Sử dụng `Helmet.js` làm middleware mặc định để bảo vệ Express app khỏi các rủi ro web phổ biến thông qua việc cấu hình chính xác http payload headers.

---

## 2. BSC Indexer Error Handling

Indexer hoạt động độc lập như một Worker Daemon, yêu cầu cơ chế tự phục hồi cao do môi trường on-chain thường không phản hồi ổn định.

### 2.1. RPC Disconnect → Reconnect Strategy
- Nếu websocket event listener của `viem` bị ngắt kết nối (ví dụ: timeout từ nhà cung cấp RPC, internet flap), Indexer áp dụng thuật toán **Exponential Backoff** để reconnect.
- Thử kết nối lại vào các mốc `1s, 2s, 4s, 8s, 16s...` nhằm tránh bị cấm IP kết nối tạm thời do spam node.

### 2.2. Missed Blocks → Catch-up Mechanism
- Mỗi lần index thành công, indexer ghi block đã xử lý (last processed block) vào PostgreSQL/Redis.
- Khi Indexer reconnect thành công hoặc khởi động lại (restart/crash recovery), hệ thống so sánh chiều cao block thực tại với `last_processed_block`.
- Fetch (bằng JSON-RPC `eth_getLogs`) bù lại những khoảng khối lượng events bị hụt giữa thời gian ngắt kết nối (Missed blocks detection) và catch-up lại DB trước khi tiếp tục theo luồng WebSocket real-time.

### 2.3. Duplicate Event Handling
- Nguy cơ từ sự đồng bộ lặp lại sẽ sinh ra multiple copies block/event. Indexer xử lý bằng kĩ thuật **Idempotent INSERT**.
- Lập trình database ở table `ohlcv_candles` áp dụng ràng buộc `ON CONFLICT (pair_address, interval, open_time) DO NOTHING` để chắc chắn không lưu chồng lấp records do duplicate updates sinh ra.

### 2.4. Crash Recovery
- Bất kì runtime crash nào cũng được process manager (`PM2`) tự động khởi chạy lại ứng dụng bằng cơ chế restart-hook.
- Indexer tự động resume từ `last_processed_block` (Cơ chế Catch-up 2.2). Lỗi đọc logic đối với một contract lỗi sẽ được báo động cho Engineer ở Error Log mức "ERROR", nhưng vòng lặp Event Daemon luôn có bẫy Catch Event lỗi đó, rồi skip block/Log này để duyệt tiếp các cặp Pool khả dụng khác, chống lại single point of failure.

---

## 3. Frontend Error Handling

### 3.1. On-chain Transaction Errors
- Dịch lỗi on-chain (ví dụ như `execution reverted`, `insufficient liquidity` hay slippage limit chênh quá đà). System Frontend (`viem`/`wagmi`) cần Parse những Error Objects thành message thân thiện.
- Ưu tiên hiện nguyên nhân mạch lạc bằng tiếng Việt: *“Giao dịch thất bại: Trượt giá lớn hơn mức chấp nhận”* / *“Thất bại: Không đủ hạn mức phê duyệt Token XYZ”* thay vì mã lỗi hexadecimal dài dòng.

### 3.2. API Errors Mapping
- Cấu hình Dictionary map tất cả Error Codes trả về từ REST API (như `NO_DIRECT_POOL`, `AUTH_TOKEN_EXPIRED`, v.v) thành thông báo cho users bằng **Tiếng Việt**.
- *VD:* Khi nhận lỗi `NO_DIRECT_POOL` từ Backend `/api/ohlcv`, Trading Chart không được hiển thị blank canvas hư hỏng mà hiển thị *“Không có dữ liệu Chart cho cặp Token này”*.

### 3.3. Network Errors & Retry Mode
- Nếu requests HTTP/WS thất bại do đường truyền tạm chập chờn (`AxiosNetworkError` / WS Close), cơ chế API Client tiến hành tự động thử lại (Retry / Polling x times limit).
- Hiện **Offline Indicator / Đang mất kết nối** (Biểu tượng rớt mạng UI) trên góc màn hình nếu retry chạm mốc thất bại cuối.

### 3.4. React Error Boundaries
- Bố trí các Error Boundaries chặn những luồng Rendering Error phát sinh cục bộ — nhất là liên quan đến DOM Chart hoặc state từ Custom Hooks wagmi.
- Khi bị sự cố tại một cụm component, Error Boundary tránh gián đoạn toàn app bằng các Error Fallback thân thiện kèm nút “Reload Phần này”. 

### 3.5. TxToast Notification States
- Mỗi Transaction đẩy lên chain có TxToast phụ trách theo dõi hành trình giao dịch theo pipeline sau:
  1. `pending`: Wallet MetaMask Modal chuẩn bị gọi User Sign.
  2. `confirming` (loading/spinner): Trạng thái lệnh hash hợp lệ gửi lên network, Node đang broadcast/mining block.
  3. Xong giao dịch (hoặc Lỗi) => Đặt vào toast `success` (Màu xanh Success) hoặc `failed` (Màu cam Red Warning + CTA thử lại/Tăng slippage).

---

## 4. Health Check

Health check API không chỉ thông báo HTTP 200 đơn thuần, mà cung cấp real-time status của những Node dependencies chủ chốt. Cụ thể:

**`GET /api/health`**

```json
{
  "status": "ok",
  "db": true,
  "redis": true,
  "indexer": {
    "lastBlock": 37492102,
    "lag": 2
  }
}
```

- Trả lời `status` `ok` nếu mọi dependency khoẻ.
- `db` và `redis`: True nếu kết nối live `ping`/`SELECT 1` thành công.
- Theo dõi Lag mảng Indexer theo thời gian khối mạng BSC (`lastBlock` đã xử lý & đếm khoảng `lag` thời khoảng thời gian block gần nhất hiện tại `Ns`). Monitor tools đọc API `/api/health` hỏng hoặc `lag > max_number_thresold` sẽ cảnh báo tức thì ngay cho Backend / DevOps Team nắm thông tin.
