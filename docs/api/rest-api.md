# LizSwap REST API Specification

> **Base URL**: `https://lizswap.xyz/api`
> **Protocol**: HTTPS (TLS 1.2+)
> **Content-Type**: `application/json`
> **Backend**: Node.js + TypeScript + Express (port `:3000`, proxied qua Nginx)

---

## Mục lục

1. [Quy ước chung](#quy-ước-chung)
2. [Authentication](#authentication)
3. [Public Endpoints](#public-endpoints)
4. [Auth Endpoints](#auth-endpoints)
5. [Admin Endpoints](#admin-endpoints)

---

## Quy ước chung

### Base URL

Tất cả endpoints đều có prefix `/api`. Nginx reverse-proxy `*/api/*` → Backend API (`:3000`).

### Response Format — Thành công

```json
{
  "success": true,
  "data": { ... }
}
```

Với list endpoints có phân trang:

```json
{
  "success": true,
  "data": [ ... ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 150
  }
}
```

### Error Response Format — Thống nhất

Tất cả lỗi đều trả về cùng format:

```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Mô tả lỗi chi tiết"
  }
}
```

**Bảng Error Codes thường gặp:**

| HTTP Status | Error Code | Mô tả |
|---|---|---|
| `400` | `INVALID_PARAMS` | Thiếu hoặc sai tham số |
| `400` | `INVALID_INTERVAL` | Interval không hỗ trợ (chỉ `1m`, `5m`, `1h`, `1d`) |
| `400` | `INVALID_ADDRESS` | Địa chỉ token/pair không hợp lệ |
| `400` | `INVALID_SIGNATURE` | Chữ ký wallet không khớp |
| `401` | `UNAUTHORIZED` | Chưa đăng nhập hoặc JWT hết hạn |
| `401` | `TOKEN_BLACKLISTED` | JWT đã bị invalidate (logout/revoke) |
| `403` | `FORBIDDEN` | Không đủ quyền (role không phù hợp) |
| `404` | `NOT_FOUND` | Resource không tồn tại |
| `404` | `TOKEN_NOT_FOUND` | Token không tồn tại trên hệ thống |
| `404` | `POOL_NOT_FOUND` | Pool không tồn tại |
| `404` | `USER_NOT_FOUND` | User không tồn tại |
| `404` | `NO_DIRECT_POOL` | Không có direct pool cho cặp token (không hiển thị chart) |
| `409` | `USER_EXISTS` | Wallet address đã tồn tại trong hệ thống |
| `429` | `RATE_LIMIT_EXCEEDED` | Vượt quá giới hạn request |
| `500` | `INTERNAL_ERROR` | Lỗi server nội bộ |

### Rate Limiting

Mỗi response đều chứa rate limiting headers:

| Header | Mô tả |
|---|---|
| `X-RateLimit-Limit` | Số request tối đa trong window (VD: `100`) |
| `X-RateLimit-Remaining` | Số request còn lại trong window hiện tại |

Khi vượt giới hạn, server trả `429 Too Many Requests`:

```json
{
  "success": false,
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Too many requests. Please try again later."
  }
}
```

**Rate limits mặc định:**

| Nhóm | Limit |
|---|---|
| Public endpoints | 100 requests / phút / IP |
| Auth endpoints | 10 requests / phút / IP |
| Admin endpoints | 60 requests / phút / JWT |

### Pagination

Các list endpoints hỗ trợ query params phân trang:

| Param | Type | Default | Mô tả |
|---|---|---|---|
| `page` | integer | `1` | Số trang (bắt đầu từ 1) |
| `limit` | integer | `20` | Số item trên mỗi trang (tối đa `100`) |

### Timestamp Convention

- Tất cả query params `from` và `to` sử dụng **Unix timestamp (seconds)**.
- Tất cả response fields liên quan timestamp cũng trả về Unix timestamp (seconds).

### Interval

Chỉ hỗ trợ 4 giá trị: `1m`, `5m`, `1h`, `1d`.

---

## Authentication

LizSwap sử dụng **wallet-based authentication** (EIP-191):

1. Manager/Staff kết nối MetaMask, ký message bằng private key
2. Backend xác thực chữ ký → cấp **JWT token** với payload `{ wallet_address, role, exp }`
3. JWT được gửi qua header `Authorization: Bearer <token>`
4. Logout → JWT được lưu vào **Redis blacklist** (invalidate)

**JWT Payload:**

```json
{
  "wallet_address": "0x1234...abcd",
  "role": "manager",
  "iat": 1711929600,
  "exp": 1712016000
}
```

---

## Public Endpoints

### `GET /api/prices/:token`

Lấy giá hiện tại của một token (tính bằng USDT/BUSD).

**Auth**: None

#### Request

| Phần | Tên | Type | Required | Mô tả |
|---|---|---|---|---|
| Path | `token` | string | ✅ | Địa chỉ token contract (checksummed hoặc lowercase) |

**Headers:**

| Header | Value |
|---|---|
| `Accept` | `application/json` |

#### Response

**`200 OK`** — Thành công

```json
{
  "success": true,
  "data": {
    "token": "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
    "symbol": "WBNB",
    "decimals": 18,
    "price_usd": "312.45",
    "price_bnb": "1.0",
    "last_updated": 1711929600,
    "source": "pool_reserves"
  }
}
```

**`400 Bad Request`** — Địa chỉ không hợp lệ

```json
{
  "success": false,
  "error": {
    "code": "INVALID_ADDRESS",
    "message": "Token address is not a valid BSC address."
  }
}
```

**`404 Not Found`** — Token không tồn tại

```json
{
  "success": false,
  "error": {
    "code": "TOKEN_NOT_FOUND",
    "message": "Token not found in any active pool."
  }
}
```

**`500 Internal Server Error`**

```json
{
  "success": false,
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "Failed to fetch token price from BSC RPC."
  }
}
```

#### Ví dụ

```bash
# Request
GET /api/prices/0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c

# Response 200
{
  "success": true,
  "data": {
    "token": "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
    "symbol": "WBNB",
    "decimals": 18,
    "price_usd": "312.45",
    "price_bnb": "1.0",
    "last_updated": 1711929600,
    "source": "pool_reserves"
  }
}
```

> [!NOTE]
> **Luồng nội bộ**: `PriceService` kiểm tra Redis cache trước. Nếu cache miss → đọc reserves on-chain qua `BSCClient` (viem) → tính giá → cache vào Redis (TTL ~2s).

---

### `GET /api/pools`

Danh sách tất cả pools và thống kê cơ bản.

**Auth**: None

#### Request

**Query Params:**

| Param | Type | Required | Default | Mô tả |
|---|---|---|---|---|
| `page` | integer | ❌ | `1` | Trang |
| `limit` | integer | ❌ | `20` | Số pool mỗi trang (max `100`) |

**Headers:**

| Header | Value |
|---|---|
| `Accept` | `application/json` |

#### Response

**`200 OK`**

```json
{
  "success": true,
  "data": [
    {
      "pair_address": "0xabc123...def456",
      "token0": {
        "address": "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
        "symbol": "WBNB",
        "decimals": 18
      },
      "token1": {
        "address": "0x55d398326f99059fF775485246999027B3197955",
        "symbol": "USDT",
        "decimals": 18
      },
      "reserve0": "15000.123456789",
      "reserve1": "4686038.50",
      "tvl_usd": "9372077.00",
      "volume_24h_usd": "1250000.00",
      "apr": "42.5",
      "tx_count_24h": 3420,
      "created_at": 1711843200
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 35
  }
}
```

**`500 Internal Server Error`**

```json
{
  "success": false,
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "Failed to fetch pool data."
  }
}
```

#### Ví dụ

```bash
# Request
GET /api/pools?page=1&limit=10

# Response 200
{
  "success": true,
  "data": [
    {
      "pair_address": "0xabc123...def456",
      "token0": {
        "address": "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
        "symbol": "WBNB",
        "decimals": 18
      },
      "token1": {
        "address": "0x55d398326f99059fF775485246999027B3197955",
        "symbol": "USDT",
        "decimals": 18
      },
      "reserve0": "15000.123456789",
      "reserve1": "4686038.50",
      "tvl_usd": "9372077.00",
      "volume_24h_usd": "1250000.00",
      "apr": "42.5",
      "tx_count_24h": 3420,
      "created_at": 1711843200
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 10,
    "total": 35
  }
}
```

> [!NOTE]
> **Nguồn dữ liệu**: `PoolService` query từ PostgreSQL (TVL, volume), cache kết quả vào Redis. Reserves đọc on-chain qua `BSCClient`.

---

### `GET /api/pools/:pair/stats`

Thống kê chi tiết của một pool: TVL, volume, APR.

**Auth**: None

#### Request

| Phần | Tên | Type | Required | Mô tả |
|---|---|---|---|---|
| Path | `pair` | string | ✅ | Địa chỉ Pair contract |

**Headers:**

| Header | Value |
|---|---|
| `Accept` | `application/json` |

#### Response

**`200 OK`**

```json
{
  "success": true,
  "data": {
    "pair_address": "0xabc123...def456",
    "token0": {
      "address": "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
      "symbol": "WBNB",
      "decimals": 18,
      "reserve": "15000.123456789"
    },
    "token1": {
      "address": "0x55d398326f99059fF775485246999027B3197955",
      "symbol": "USDT",
      "decimals": 18,
      "reserve": "4686038.50"
    },
    "tvl_usd": "9372077.00",
    "volume_24h_usd": "1250000.00",
    "volume_7d_usd": "8750000.00",
    "fee_24h_usd": "3750.00",
    "apr": "42.5",
    "tx_count_24h": 3420,
    "total_supply_lp": "265000.00",
    "created_at": 1711843200
  }
}
```

**`400 Bad Request`**

```json
{
  "success": false,
  "error": {
    "code": "INVALID_ADDRESS",
    "message": "Pair address is not a valid BSC address."
  }
}
```

**`404 Not Found`**

```json
{
  "success": false,
  "error": {
    "code": "POOL_NOT_FOUND",
    "message": "Pool with the given pair address does not exist."
  }
}
```

**`500 Internal Server Error`**

```json
{
  "success": false,
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "Failed to fetch pool stats."
  }
}
```

#### Ví dụ

```bash
# Request
GET /api/pools/0xabc123def456.../stats

# Response 200
{
  "success": true,
  "data": {
    "pair_address": "0xabc123...def456",
    "token0": {
      "address": "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
      "symbol": "WBNB",
      "decimals": 18,
      "reserve": "15000.123456789"
    },
    "token1": {
      "address": "0x55d398326f99059fF775485246999027B3197955",
      "symbol": "USDT",
      "decimals": 18,
      "reserve": "4686038.50"
    },
    "tvl_usd": "9372077.00",
    "volume_24h_usd": "1250000.00",
    "volume_7d_usd": "8750000.00",
    "fee_24h_usd": "3750.00",
    "apr": "42.5",
    "tx_count_24h": 3420,
    "total_supply_lp": "265000.00",
    "created_at": 1711843200
  }
}
```

> [!NOTE]
> **Frontend reference**: `PoolsMonitorPage` (Admin) gọi endpoint này qua `adminApiClient`. `PoolPage` (DApp) cũng sử dụng khi hiển thị chi tiết từng pool.

---

### `GET /api/ohlcv`

Lấy dữ liệu OHLCV (candlestick) cho một cặp token. Chỉ trả dữ liệu nếu cặp token có **direct pool** trên Factory.

**Auth**: None

#### Request

**Query Params:**

| Param | Type | Required | Mô tả |
|---|---|---|---|
| `token0` | string | ✅ | Địa chỉ token0 |
| `token1` | string | ✅ | Địa chỉ token1 |
| `interval` | string | ✅ | Khung thời gian: `1m`, `5m`, `1h`, `1d` |
| `from` | integer | ❌ | Unix timestamp (seconds) — thời điểm bắt đầu |
| `to` | integer | ❌ | Unix timestamp (seconds) — thời điểm kết thúc |

> [!IMPORTANT]
> `from` và `to` dùng **Unix timestamp (seconds)**, không phải milliseconds.
> `interval` chỉ chấp nhận: `1m`, `5m`, `1h`, `1d`. Giá trị khác sẽ trả `400 INVALID_INTERVAL`.

**Headers:**

| Header | Value |
|---|---|
| `Accept` | `application/json` |

#### Response

**`200 OK`** — Có direct pool, trả dữ liệu nến

```json
{
  "success": true,
  "data": {
    "pair_address": "0xabc123...def456",
    "token0": "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
    "token1": "0x55d398326f99059fF775485246999027B3197955",
    "interval": "1h",
    "candles": [
      {
        "open_time": 1711926000,
        "open": "312.10",
        "high": "313.50",
        "low": "311.80",
        "close": "312.45",
        "volume": "125.678",
        "tx_count": 42
      },
      {
        "open_time": 1711929600,
        "open": "312.45",
        "high": "314.20",
        "low": "312.00",
        "close": "313.80",
        "volume": "98.234",
        "tx_count": 35
      }
    ]
  }
}
```

**`400 Bad Request`** — Tham số thiếu hoặc không hợp lệ

```json
{
  "success": false,
  "error": {
    "code": "INVALID_PARAMS",
    "message": "Missing required query parameters: token0, token1, interval."
  }
}
```

```json
{
  "success": false,
  "error": {
    "code": "INVALID_INTERVAL",
    "message": "Interval must be one of: 1m, 5m, 1h, 1d."
  }
}
```

**`404 Not Found`** — Không có direct pool

```json
{
  "success": false,
  "error": {
    "code": "NO_DIRECT_POOL",
    "message": "No direct pool exists for the given token pair. Chart data unavailable."
  }
}
```

> [!IMPORTANT]
> **Direct Pool Check**: `OHLCVService.validateDirectPool()` gọi `Factory.getPair(token0, token1)` on-chain. Nếu trả `address(0)` → trả `404 NO_DIRECT_POOL`. Frontend nhận lỗi này sẽ hiển thị *"Không có dữ liệu chart"* thay vì render biểu đồ.

**`500 Internal Server Error`**

```json
{
  "success": false,
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "Failed to query OHLCV data."
  }
}
```

#### Ví dụ

```bash
# Request
GET /api/ohlcv?token0=0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c&token1=0x55d398326f99059fF775485246999027B3197955&interval=1h&from=1711900000&to=1711929600

# Response 200
{
  "success": true,
  "data": {
    "pair_address": "0xabc123...def456",
    "token0": "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
    "token1": "0x55d398326f99059fF775485246999027B3197955",
    "interval": "1h",
    "candles": [
      {
        "open_time": 1711926000,
        "open": "312.10",
        "high": "313.50",
        "low": "311.80",
        "close": "312.45",
        "volume": "125.678",
        "tx_count": 42
      }
    ]
  }
}
```

> [!NOTE]
> **Luồng nội bộ**: `OHLCVService` → kiểm tra cache Redis (key `pair:interval:from:to`) → cache miss → query bảng `ohlcv_candles` (PostgreSQL) với composite index `(pair_address, interval, open_time)`.

---

## Auth Endpoints

### `POST /api/auth/login`

Đăng nhập bằng wallet signature (EIP-191). Server xác thực chữ ký → trả JWT token.

**Auth**: None

#### Request

**Headers:**

| Header | Value |
|---|---|
| `Content-Type` | `application/json` |

**Body:**

```json
{
  "wallet_address": "0x1234567890abcdef1234567890abcdef12345678",
  "message": "Sign in to LizSwap Admin\nNonce: a1b2c3d4e5\nTimestamp: 1711929600",
  "signature": "0xabcdef1234567890..."
}
```

| Field | Type | Required | Mô tả |
|---|---|---|---|
| `wallet_address` | string | ✅ | Địa chỉ ví BSC (42 ký tự, bắt đầu `0x`) |
| `message` | string | ✅ | Message đã ký (bao gồm nonce và timestamp) |
| `signature` | string | ✅ | Chữ ký EIP-191 từ MetaMask |

#### Response

**`200 OK`** — Đăng nhập thành công

```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "expires_at": 1712016000,
    "user": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "wallet_address": "0x1234567890abcdef1234567890abcdef12345678",
      "role": "manager",
      "is_active": true
    }
  }
}
```

**`400 Bad Request`** — Thiếu tham số

```json
{
  "success": false,
  "error": {
    "code": "INVALID_PARAMS",
    "message": "Missing required fields: wallet_address, message, signature."
  }
}
```

**`400 Bad Request`** — Chữ ký không hợp lệ

```json
{
  "success": false,
  "error": {
    "code": "INVALID_SIGNATURE",
    "message": "Wallet signature verification failed. Address does not match."
  }
}
```

**`403 Forbidden`** — Wallet không có quyền admin

```json
{
  "success": false,
  "error": {
    "code": "FORBIDDEN",
    "message": "Wallet address is not registered as Manager or Staff."
  }
}
```

**`403 Forbidden`** — Tài khoản bị vô hiệu hoá

```json
{
  "success": false,
  "error": {
    "code": "FORBIDDEN",
    "message": "Account has been deactivated."
  }
}
```

**`500 Internal Server Error`**

```json
{
  "success": false,
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "Authentication service unavailable."
  }
}
```

#### Ví dụ

```bash
# Request
POST /api/auth/login
Content-Type: application/json

{
  "wallet_address": "0x1234567890abcdef1234567890abcdef12345678",
  "message": "Sign in to LizSwap Admin\nNonce: a1b2c3d4e5\nTimestamp: 1711929600",
  "signature": "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab1c"
}

# Response 200
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "expires_at": 1712016000,
    "user": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "wallet_address": "0x1234567890abcdef1234567890abcdef12345678",
      "role": "manager",
      "is_active": true
    }
  }
}
```

> [!NOTE]
> **Auth Flow**: Frontend (Admin Dashboard `LoginPage`) ký message bằng MetaMask (EIP-191) → gửi signature đến backend → backend dùng `ethers.verifyMessage()` hoặc `viem.verifyMessage()` để recover address → so khớp với bảng `user_roles` → cấp JWT.

---

### `POST /api/auth/logout`

Invalidate JWT token hiện tại. Token sẽ được thêm vào Redis blacklist.

**Auth**: JWT (Bearer Token)

#### Request

**Headers:**

| Header | Value |
|---|---|
| `Authorization` | `Bearer <jwt_token>` |

**Body:** Không có body.

#### Response

**`200 OK`**

```json
{
  "success": true,
  "data": {
    "message": "Logged out successfully."
  }
}
```

**`401 Unauthorized`** — JWT thiếu hoặc không hợp lệ

```json
{
  "success": false,
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Missing or invalid authorization token."
  }
}
```

**`500 Internal Server Error`**

```json
{
  "success": false,
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "Failed to invalidate token."
  }
}
```

#### Ví dụ

```bash
# Request
POST /api/auth/logout
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...

# Response 200
{
  "success": true,
  "data": {
    "message": "Logged out successfully."
  }
}
```

> [!NOTE]
> **Blacklist**: JWT được thêm vào Redis set `jwt:blacklist` với TTL bằng thời gian hết hạn còn lại của token. `JWTVerifier` middleware phải kiểm tra blacklist trước khi chấp nhận token.

---

## Admin Endpoints

> [!IMPORTANT]
> Tất cả admin endpoints yêu cầu header `Authorization: Bearer <jwt_token>`.
> Role guard phải enforce ở **cả Backend API** (403 Forbidden) lẫn **Frontend UI** (ẩn/hiện). Xem chi tiết phân quyền tại [AGENT.md — mục 4](../../AGENT.md).

### `GET /api/admin/users`

Danh sách tất cả users với role và trạng thái.

**Auth**: Manager + Staff

#### Request

**Headers:**

| Header | Value |
|---|---|
| `Authorization` | `Bearer <jwt_token>` |

**Query Params:**

| Param | Type | Required | Default | Mô tả |
|---|---|---|---|---|
| `page` | integer | ❌ | `1` | Trang |
| `limit` | integer | ❌ | `20` | Số user mỗi trang (max `100`) |

#### Response

**`200 OK`**

```json
{
  "success": true,
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "wallet_address": "0x1234567890abcdef1234567890abcdef12345678",
      "role": "manager",
      "is_active": true,
      "created_by": null,
      "created_at": 1711843200
    },
    {
      "id": "550e8400-e29b-41d4-a716-446655440001",
      "wallet_address": "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
      "role": "staff",
      "is_active": true,
      "created_by": "550e8400-e29b-41d4-a716-446655440000",
      "created_at": 1711929600
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 5
  }
}
```

**`401 Unauthorized`**

```json
{
  "success": false,
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Missing or invalid authorization token."
  }
}
```

**`403 Forbidden`**

```json
{
  "success": false,
  "error": {
    "code": "FORBIDDEN",
    "message": "Insufficient permissions. Manager or Staff role required."
  }
}
```

**`500 Internal Server Error`**

```json
{
  "success": false,
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "Failed to fetch users."
  }
}
```

#### Ví dụ

```bash
# Request
GET /api/admin/users?page=1&limit=10
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...

# Response 200
{
  "success": true,
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "wallet_address": "0x1234...5678",
      "role": "manager",
      "is_active": true,
      "created_by": null,
      "created_at": 1711843200
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 10,
    "total": 5
  }
}
```

---

### `POST /api/admin/users`

Thêm Staff mới vào hệ thống.

**Auth**: **Manager only**

#### Request

**Headers:**

| Header | Value |
|---|---|
| `Authorization` | `Bearer <jwt_token>` |
| `Content-Type` | `application/json` |

**Body:**

```json
{
  "wallet_address": "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
  "role": "staff"
}
```

| Field | Type | Required | Mô tả |
|---|---|---|---|
| `wallet_address` | string | ✅ | Địa chỉ ví BSC của Staff mới (42 ký tự) |
| `role` | string | ✅ | Role: `staff` (chỉ Manager mới có thể tạo Staff) |

#### Response

**`201 Created`**

```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440002",
    "wallet_address": "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
    "role": "staff",
    "is_active": true,
    "created_by": "550e8400-e29b-41d4-a716-446655440000",
    "created_at": 1711929600
  }
}
```

**`400 Bad Request`** — Thiếu tham số hoặc address không hợp lệ

```json
{
  "success": false,
  "error": {
    "code": "INVALID_PARAMS",
    "message": "wallet_address is required and must be a valid BSC address."
  }
}
```

**`401 Unauthorized`**

```json
{
  "success": false,
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Missing or invalid authorization token."
  }
}
```

**`403 Forbidden`** — Không phải Manager

```json
{
  "success": false,
  "error": {
    "code": "FORBIDDEN",
    "message": "Only Manager can create new users."
  }
}
```

**`409 Conflict`** — Wallet đã tồn tại

```json
{
  "success": false,
  "error": {
    "code": "USER_EXISTS",
    "message": "A user with this wallet address already exists."
  }
}
```

**`500 Internal Server Error`**

```json
{
  "success": false,
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "Failed to create user."
  }
}
```

#### Ví dụ

```bash
# Request
POST /api/admin/users
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
Content-Type: application/json

{
  "wallet_address": "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
  "role": "staff"
}

# Response 201
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440002",
    "wallet_address": "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
    "role": "staff",
    "is_active": true,
    "created_by": "550e8400-e29b-41d4-a716-446655440000",
    "created_at": 1711929600
  }
}
```

---

### `PUT /api/admin/users/:id/role`

Cập nhật role của một user.

**Auth**: **Manager only**

#### Request

| Phần | Tên | Type | Required | Mô tả |
|---|---|---|---|---|
| Path | `id` | string (UUID) | ✅ | ID của user cần cập nhật |

**Headers:**

| Header | Value |
|---|---|
| `Authorization` | `Bearer <jwt_token>` |
| `Content-Type` | `application/json` |

**Body:**

```json
{
  "role": "manager"
}
```

| Field | Type | Required | Mô tả |
|---|---|---|---|
| `role` | string | ✅ | Role mới: `manager` hoặc `staff` |

#### Response

**`200 OK`**

```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440001",
    "wallet_address": "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
    "role": "manager",
    "is_active": true,
    "updated_at": 1711933200
  }
}
```

**`400 Bad Request`** — Role không hợp lệ

```json
{
  "success": false,
  "error": {
    "code": "INVALID_PARAMS",
    "message": "Role must be 'manager' or 'staff'."
  }
}
```

**`401 Unauthorized`**

```json
{
  "success": false,
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Missing or invalid authorization token."
  }
}
```

**`403 Forbidden`**

```json
{
  "success": false,
  "error": {
    "code": "FORBIDDEN",
    "message": "Only Manager can update user roles."
  }
}
```

**`404 Not Found`**

```json
{
  "success": false,
  "error": {
    "code": "USER_NOT_FOUND",
    "message": "User with the given ID does not exist."
  }
}
```

**`500 Internal Server Error`**

```json
{
  "success": false,
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "Failed to update user role."
  }
}
```

#### Ví dụ

```bash
# Request
PUT /api/admin/users/550e8400-e29b-41d4-a716-446655440001/role
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
Content-Type: application/json

{
  "role": "manager"
}

# Response 200
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440001",
    "wallet_address": "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
    "role": "manager",
    "is_active": true,
    "updated_at": 1711933200
  }
}
```

---

### `DELETE /api/admin/users/:id`

Vô hiệu hoá tài khoản (soft-delete: `is_active = false`). **Không xoá record** khỏi database.

**Auth**: **Manager only**

#### Request

| Phần | Tên | Type | Required | Mô tả |
|---|---|---|---|---|
| Path | `id` | string (UUID) | ✅ | ID của user cần vô hiệu hoá |

**Headers:**

| Header | Value |
|---|---|
| `Authorization` | `Bearer <jwt_token>` |

**Body:** Không có body.

#### Response

**`200 OK`**

```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440001",
    "wallet_address": "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
    "is_active": false,
    "deactivated_at": 1711933200
  }
}
```

**`401 Unauthorized`**

```json
{
  "success": false,
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Missing or invalid authorization token."
  }
}
```

**`403 Forbidden`**

```json
{
  "success": false,
  "error": {
    "code": "FORBIDDEN",
    "message": "Only Manager can deactivate users."
  }
}
```

**`404 Not Found`**

```json
{
  "success": false,
  "error": {
    "code": "USER_NOT_FOUND",
    "message": "User with the given ID does not exist."
  }
}
```

**`500 Internal Server Error`**

```json
{
  "success": false,
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "Failed to deactivate user."
  }
}
```

#### Ví dụ

```bash
# Request
DELETE /api/admin/users/550e8400-e29b-41d4-a716-446655440001
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...

# Response 200
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440001",
    "wallet_address": "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
    "is_active": false,
    "deactivated_at": 1711933200
  }
}
```

> [!NOTE]
> **Soft Delete**: Khi tài khoản bị vô hiệu hoá, JWT hiện tại của user đó nên được thêm vào blacklist. User sẽ không thể đăng nhập lại (`POST /api/auth/login` trả `403`).

---

### `GET /api/admin/config`

Xem toàn bộ cấu hình hệ thống.

**Auth**: Manager + Staff

#### Request

**Headers:**

| Header | Value |
|---|---|
| `Authorization` | `Bearer <jwt_token>` |

#### Response

**`200 OK`**

```json
{
  "success": true,
  "data": {
    "configs": [
      {
        "key": "protocol_fee_enabled",
        "value": true,
        "updated_by": "0x1234...5678",
        "updated_at": 1711929600
      },
      {
        "key": "fee_to_address",
        "value": "0xfee0...1234",
        "updated_by": "0x1234...5678",
        "updated_at": 1711929600
      },
      {
        "key": "reward_per_block",
        "value": "0.5",
        "updated_by": "0x1234...5678",
        "updated_at": 1711843200
      },
      {
        "key": "indexer_poll_interval_ms",
        "value": 2000,
        "updated_by": "0x1234...5678",
        "updated_at": 1711843200
      }
    ]
  }
}
```

**`401 Unauthorized`**

```json
{
  "success": false,
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Missing or invalid authorization token."
  }
}
```

**`403 Forbidden`**

```json
{
  "success": false,
  "error": {
    "code": "FORBIDDEN",
    "message": "Insufficient permissions. Manager or Staff role required."
  }
}
```

**`500 Internal Server Error`**

```json
{
  "success": false,
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "Failed to fetch system configuration."
  }
}
```

#### Ví dụ

```bash
# Request
GET /api/admin/config
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...

# Response 200
{
  "success": true,
  "data": {
    "configs": [
      {
        "key": "protocol_fee_enabled",
        "value": true,
        "updated_by": "0x1234...5678",
        "updated_at": 1711929600
      },
      {
        "key": "reward_per_block",
        "value": "0.5",
        "updated_by": "0x1234...5678",
        "updated_at": 1711843200
      }
    ]
  }
}
```

> [!NOTE]
> **Database reference**: Dữ liệu lưu trong bảng `system_config` (PostgreSQL) với cấu trúc `{ key: VARCHAR PK, value: JSONB, updated_by: VARCHAR, updated_at: TIMESTAMP }`.

---

### `PUT /api/admin/config`

Cập nhật cấu hình hệ thống.

**Auth**: **Manager only**

#### Request

**Headers:**

| Header | Value |
|---|---|
| `Authorization` | `Bearer <jwt_token>` |
| `Content-Type` | `application/json` |

**Body:**

```json
{
  "configs": [
    {
      "key": "reward_per_block",
      "value": "0.75"
    },
    {
      "key": "protocol_fee_enabled",
      "value": false
    }
  ]
}
```

| Field | Type | Required | Mô tả |
|---|---|---|---|
| `configs` | array | ✅ | Danh sách các config cần cập nhật |
| `configs[].key` | string | ✅ | Tên config (phải tồn tại trong `system_config`) |
| `configs[].value` | any | ✅ | Giá trị mới (JSONB) |

#### Response

**`200 OK`**

```json
{
  "success": true,
  "data": {
    "updated": [
      {
        "key": "reward_per_block",
        "value": "0.75",
        "updated_by": "0x1234...5678",
        "updated_at": 1711933200
      },
      {
        "key": "protocol_fee_enabled",
        "value": false,
        "updated_by": "0x1234...5678",
        "updated_at": 1711933200
      }
    ]
  }
}
```

**`400 Bad Request`** — Key không tồn tại

```json
{
  "success": false,
  "error": {
    "code": "INVALID_PARAMS",
    "message": "Config key 'invalid_key' does not exist."
  }
}
```

**`401 Unauthorized`**

```json
{
  "success": false,
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Missing or invalid authorization token."
  }
}
```

**`403 Forbidden`**

```json
{
  "success": false,
  "error": {
    "code": "FORBIDDEN",
    "message": "Only Manager can update system configuration."
  }
}
```

**`500 Internal Server Error`**

```json
{
  "success": false,
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "Failed to update configuration."
  }
}
```

#### Ví dụ

```bash
# Request
PUT /api/admin/config
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
Content-Type: application/json

{
  "configs": [
    { "key": "reward_per_block", "value": "0.75" }
  ]
}

# Response 200
{
  "success": true,
  "data": {
    "updated": [
      {
        "key": "reward_per_block",
        "value": "0.75",
        "updated_by": "0x1234...5678",
        "updated_at": 1711933200
      }
    ]
  }
}
```

---

### `GET /api/admin/activity`

Lịch sử giao dịch on-chain (Swap, Mint, Burn events). Hỗ trợ filter theo pair và khoảng thời gian.

**Auth**: Manager + Staff

#### Request

**Headers:**

| Header | Value |
|---|---|
| `Authorization` | `Bearer <jwt_token>` |

**Query Params:**

| Param | Type | Required | Default | Mô tả |
|---|---|---|---|---|
| `pair` | string | ❌ | — | Địa chỉ pair contract để filter |
| `event_type` | string | ❌ | — | Filter loại event: `swap`, `mint`, `burn` |
| `from` | integer | ❌ | — | Unix timestamp (seconds) — thời điểm bắt đầu |
| `to` | integer | ❌ | — | Unix timestamp (seconds) — thời điểm kết thúc |
| `page` | integer | ❌ | `1` | Trang |
| `limit` | integer | ❌ | `20` | Số item mỗi trang (max `100`) |

#### Response

**`200 OK`**

```json
{
  "success": true,
  "data": [
    {
      "id": 12345,
      "event_type": "swap",
      "pair_address": "0xabc123...def456",
      "token0_symbol": "WBNB",
      "token1_symbol": "USDT",
      "sender": "0xuser1...addr",
      "amount0_in": "1.5",
      "amount1_in": "0",
      "amount0_out": "0",
      "amount1_out": "468.675",
      "tx_hash": "0xtxhash123...abc",
      "block_number": 38500001,
      "timestamp": 1711929600
    },
    {
      "id": 12344,
      "event_type": "mint",
      "pair_address": "0xabc123...def456",
      "token0_symbol": "WBNB",
      "token1_symbol": "USDT",
      "sender": "0xuser2...addr",
      "amount0": "10.0",
      "amount1": "3124.50",
      "liquidity": "176.77",
      "tx_hash": "0xtxhash456...def",
      "block_number": 38499990,
      "timestamp": 1711929500
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 1250
  }
}
```

**`401 Unauthorized`**

```json
{
  "success": false,
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Missing or invalid authorization token."
  }
}
```

**`403 Forbidden`**

```json
{
  "success": false,
  "error": {
    "code": "FORBIDDEN",
    "message": "Insufficient permissions. Manager or Staff role required."
  }
}
```

**`500 Internal Server Error`**

```json
{
  "success": false,
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "Failed to fetch activity log."
  }
}
```

#### Ví dụ

```bash
# Request — Filter Swap events của pair WBNB/USDT trong 24h qua
GET /api/admin/activity?pair=0xabc123...def456&event_type=swap&from=1711843200&to=1711929600&page=1&limit=50
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...

# Response 200
{
  "success": true,
  "data": [
    {
      "id": 12345,
      "event_type": "swap",
      "pair_address": "0xabc123...def456",
      "token0_symbol": "WBNB",
      "token1_symbol": "USDT",
      "sender": "0xuser1...addr",
      "amount0_in": "1.5",
      "amount1_in": "0",
      "amount0_out": "0",
      "amount1_out": "468.675",
      "tx_hash": "0xtxhash123...abc",
      "block_number": 38500001,
      "timestamp": 1711929600
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 50,
    "total": 342
  }
}
```

> [!NOTE]
> **Frontend reference**: `ActivityPage` (Admin Dashboard) gọi endpoint này với filter theo pair và thời gian. Dữ liệu nguồn từ BSC Indexer đã index sẵn vào PostgreSQL.

---

### `GET /api/admin/stats`

Thống kê tổng quan hệ thống: 24h volume, TVL, số active wallets.

**Auth**: Manager + Staff

#### Request

**Headers:**

| Header | Value |
|---|---|
| `Authorization` | `Bearer <jwt_token>` |

#### Response

**`200 OK`**

```json
{
  "success": true,
  "data": {
    "total_tvl_usd": "25000000.00",
    "volume_24h_usd": "5200000.00",
    "volume_7d_usd": "36400000.00",
    "total_pools": 35,
    "active_pools_24h": 28,
    "active_wallets_24h": 1250,
    "total_swaps_24h": 8420,
    "total_mints_24h": 320,
    "total_burns_24h": 150,
    "protocol_fees_24h_usd": "5200.00",
    "timestamp": 1711929600
  }
}
```

**`401 Unauthorized`**

```json
{
  "success": false,
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Missing or invalid authorization token."
  }
}
```

**`403 Forbidden`**

```json
{
  "success": false,
  "error": {
    "code": "FORBIDDEN",
    "message": "Insufficient permissions. Manager or Staff role required."
  }
}
```

**`500 Internal Server Error`**

```json
{
  "success": false,
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "Failed to compute system statistics."
  }
}
```

#### Ví dụ

```bash
# Request
GET /api/admin/stats
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...

# Response 200
{
  "success": true,
  "data": {
    "total_tvl_usd": "25000000.00",
    "volume_24h_usd": "5200000.00",
    "volume_7d_usd": "36400000.00",
    "total_pools": 35,
    "active_pools_24h": 28,
    "active_wallets_24h": 1250,
    "total_swaps_24h": 8420,
    "total_mints_24h": 320,
    "total_burns_24h": 150,
    "protocol_fees_24h_usd": "5200.00",
    "timestamp": 1711929600
  }
}
```

> [!NOTE]
> **Frontend reference**: `DashboardPage` (Admin Dashboard) gọi endpoint này cùng với `GET /api/pools` để hiển thị tổng quan hệ thống.

---

## Tham chiếu Database Schema

Các endpoint trên ghi/đọc dữ liệu từ 3 bảng chính trong PostgreSQL. Chi tiết schema tại [c4-components-backend.md](../architecture/c4-components-backend.md#database-schema-tham-chiếu).

| Bảng | Endpoints liên quan |
|---|---|
| `ohlcv_candles` | `GET /api/ohlcv`, `GET /api/admin/activity`, `GET /api/admin/stats` |
| `user_roles` | `POST /api/auth/login`, `GET/POST/PUT/DELETE /api/admin/users` |
| `system_config` | `GET/PUT /api/admin/config` |

---

## Tham chiếu Frontend Components

Bảng mapping component Frontend → endpoint API. Chi tiết tại [c4-components-frontend.md](../architecture/c4-components-frontend.md).

| Frontend Component | Endpoint(s) gọi |
|---|---|
| `SwapPage` (DApp) | `GET /api/prices/:token` |
| `CandlestickChart` (DApp) | `GET /api/ohlcv` |
| `PoolPage` (DApp) | `GET /api/pools` |
| `PoolsMonitorPage` (Admin) | `GET /api/pools/:pair/stats` |
| `LoginPage` (Admin) | `POST /api/auth/login` |
| `DashboardPage` (Admin) | `GET /api/pools`, `GET /api/admin/stats` |
| `UsersPage` (Admin) | `GET/POST /api/admin/users`, `PUT /api/admin/users/:id/role`, `DELETE /api/admin/users/:id` |
| `ConfigPage` (Admin) | `GET/PUT /api/admin/config` |
| `ActivityPage` (Admin) | `GET /api/admin/activity` |

---

## Tham chiếu tài liệu kiến trúc

| Tài liệu | Mô tả |
|---|---|
| [AGENT.md — mục 5](../../AGENT.md) | Bảng endpoints tổng quan, WebSocket events, Auth flow |
| [c4-components-backend.md](../architecture/c4-components-backend.md) | Component diagram, database schema, service architecture |
| [c4-components-frontend.md](../architecture/c4-components-frontend.md) | Frontend components gọi API, page map |
