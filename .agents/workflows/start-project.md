---
description: Hướng dẫn khởi chạy dự án LizSwap (Development & Production)
---

# LizSwap – Khởi chạy dự án

## Yêu cầu hệ thống

- **Docker Desktop** (Windows/Mac) hoặc **Docker Engine + Docker Compose** (Linux)
- **Git**
- File `.env` đã cấu hình (xem bước 1)

---

## Bước 1: Cấu hình biến môi trường

```bash
cp .env.example .env
```

Mở file `.env` và điền các thông tin bắt buộc:

```env
# Smart Contract Addresses (đã deploy bằng Foundry)
FACTORY_ADDR=0x...your_factory_address...
ROUTER_ADDR=0x...your_router_address...
STAKING_ADDR=0x...your_staking_address...

# BSC RPC (QuickNode / Ankr / Public)
BSC_RPC_URL=https://bsc-testnet-rpc.publicnode.com
BSC_RPC_WS=wss://bsc-testnet-rpc.publicnode.com

# JWT Secret (random string)
JWT_SECRET=your_random_secret_here

# Frontend (phải giống contract addresses)
NEXT_PUBLIC_FACTORY_ADDR=0x...same_as_above...
NEXT_PUBLIC_ROUTER_ADDR=0x...same_as_above...
NEXT_PUBLIC_STAKING_ADDR=0x...same_as_above...
```

---

## 🔧 Development Mode

Development mode cho phép **hot-reload** – sửa code và thấy thay đổi ngay lập tức.

### Khởi chạy

// turbo
```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --build
```

### Đặc điểm Development Mode

| Feature | Chi tiết |
|---|---|
| **Hot-reload** | ✅ Sửa code → tự động reload (không cần rebuild image) |
| **Source mount** | Source code được mount vào container |
| **Ports exposed** | PostgreSQL `:5432`, Redis `:6379`, Backend `:3000`, DApp `:3001`, Admin `:3002` |
| **SSL** | ❌ Không (chỉ HTTP) |
| **Build** | Dùng `Dockerfile.dev` (cài devDependencies, chạy `npm run dev`) |

### Truy cập

| Service | URL |
|---|---|
| DApp Frontend | http://localhost (qua Nginx) hoặc http://localhost:3001 (trực tiếp) |
| Admin Dashboard | http://localhost:3002 |
| Backend API | http://localhost/api hoặc http://localhost:3000/api |
| PostgreSQL | `localhost:5432` (user: `lizswap`, pass: xem `.env`) |
| Redis | `localhost:6379` |

### Xem logs

// turbo
```bash
# Tất cả services
docker compose -f docker-compose.yml -f docker-compose.dev.yml logs -f

# Chỉ 1 service
docker compose -f docker-compose.yml -f docker-compose.dev.yml logs -f backend
docker compose -f docker-compose.yml -f docker-compose.dev.yml logs -f dapp
docker compose -f docker-compose.yml -f docker-compose.dev.yml logs -f indexer
```

### Dừng

// turbo
```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml down
```

### Chỉ chạy Database (cho dev local không Docker)

Nếu muốn chạy backend/frontend local bằng `npm run dev` mà không qua Docker:

// turbo
```bash
# Chỉ chạy PostgreSQL và Redis
docker compose up -d postgres redis

# Sau đó chạy local:
cd packages/backend && npm run dev    # Terminal 1
cd packages/indexer && npm run dev    # Terminal 2
cd apps/dapp && npm run dev           # Terminal 3
cd apps/admin && npm run dev          # Terminal 4
```

> **Lưu ý**: Khi chạy local, cần đổi `DATABASE_URL` trong `.env` thành `postgresql://lizswap:...@localhost:5432/lizswap` (thay `postgres` bằng `localhost`)

---

## 🚀 Production Mode

Production mode build image tối ưu, chạy ổn định, có SSL.

### Bước 1: Build và khởi chạy

// turbo
```bash
docker compose up -d --build
```

### Bước 2: Kiểm tra trạng thái

// turbo
```bash
docker compose ps
```

Tất cả containers phải ở trạng thái `Up (healthy)`.

### Bước 3: Cấu hình SSL (nếu có domain)

```bash
# 1. Sửa infra/nginx/conf.d/default.conf:
#    - Uncomment các dòng "listen 443 ssl http2"
#    - Uncomment các dòng "ssl_certificate*"
#    - Uncomment block "HTTP → HTTPS redirect"

# 2. Lấy SSL certificate
chmod +x infra/certbot/init-letsencrypt.sh
./infra/certbot/init-letsencrypt.sh

# 3. Restart nginx
docker compose restart nginx
```

### Đặc điểm Production Mode

| Feature | Chi tiết |
|---|---|
| **Build** | Multi-stage build (nhỏ gọn, tối ưu) |
| **Hot-reload** | ❌ Không (phải rebuild: `docker compose up -d --build`) |
| **Ports exposed** | Chỉ Nginx `:80` / `:443` |
| **SSL** | ✅ Let's Encrypt (auto-renew mỗi 12h) |
| **User** | Non-root user trong container |
| **Health checks** | ✅ PostgreSQL, Redis, Backend, Frontend |
| **Restart** | `unless-stopped` (tự restart khi crash) |

### Truy cập

| Service | URL |
|---|---|
| DApp Frontend | https://lizswap.xyz |
| Admin Dashboard | https://admin.lizswap.xyz |
| Backend API | https://lizswap.xyz/api |
| WebSocket | wss://lizswap.xyz/socket.io |

---

## 📋 Lệnh thường dùng

| Lệnh | Mô tả |
|---|---|
| `docker compose ps` | Xem trạng thái tất cả containers |
| `docker compose logs -f` | Xem log realtime |
| `docker compose logs -f backend indexer` | Log chỉ backend và indexer |
| `docker compose restart backend` | Restart 1 service |
| `docker compose up -d --build backend` | Rebuild và restart 1 service |
| `docker compose down` | Dừng tất cả |
| `docker compose down -v` | Dừng + xoá volumes (⚠️ mất data DB!) |
| `docker compose exec postgres psql -U lizswap` | Vào PostgreSQL CLI |
| `docker compose exec redis redis-cli` | Vào Redis CLI |

---

## 🔄 Rebuild sau khi sửa code

### Development
Không cần rebuild – hot-reload tự động cập nhật.

### Production
```bash
# Rebuild 1 service cụ thể
docker compose up -d --build backend

# Rebuild tất cả
docker compose up -d --build

# Rebuild hoàn toàn (xoá cache)
docker compose build --no-cache
docker compose up -d
```

---

## ⚠️ Troubleshooting

### Container không start
```bash
# Xem log chi tiết
docker compose logs backend
docker compose logs indexer
```

### Database connection refused
```bash
# Kiểm tra postgres đã healthy chưa
docker compose ps postgres

# Kiểm tra schema đã tạo
docker compose exec postgres psql -U lizswap -c "\dt"
```

### Reset database (mất toàn bộ data)
```bash
docker compose down
docker volume rm lizswap-postgres-data
docker compose up -d
```
