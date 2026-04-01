# C4 Level 4 – Deployment Diagram

## LizSwap DEX – Infrastructure Deployment

Sơ đồ triển khai mô tả cách các **containers** của LizSwap được ánh xạ lên **môi trường hạ tầng thực tế**.  
Kiến trúc này hướng đến **đồ án / môi trường production nhỏ**, không dùng CI/CD — deploy thủ công.

---

## Tổng quan môi trường triển khai

**Cloud / Hosting:**
- DApp Frontend → VPS (Next.js `next start`, PM2, Nginx serve)
- Admin Dashboard → VPS (Next.js `next start`, PM2, Nginx serve)
- Backend API → VPS (Ubuntu, PM2)
- BSC Indexer → VPS (Ubuntu, PM2, cùng server)
- PostgreSQL → VPS (Docker)
- Redis → VPS (Docker)
- Smart Contracts → Binance Smart Chain (BSC Mainnet hoặc BSC Testnet)

---

## Diagram 1 – Deployment Tổng thể

```mermaid
C4Deployment
  title Deployment Diagram – LizSwap DEX (Production)

  Deployment_Node(userBrowser, "User Browser", "Chrome / Firefox / Brave") {
    Container(dappFe, "DApp Frontend", "Next.js, wagmi, viem", "Giao diện Swap, Pool, Stake, Chart")
    Container(metamaskExt, "MetaMask Extension", "Browser Extension", "Ký và phát giao dịch BSC")
  }

  Deployment_Node(adminBrowser, "Admin Browser", "Chrome (Private)") {
    Container(adminFe, "Admin Dashboard", "Next.js", "Giao diện quản trị Manager & Staff")
  }

  Deployment_Node(vps, "VPS / Cloud VM", "Ubuntu 22.04 LTS, 4 vCPU / 8 GB RAM") {

    Deployment_Node(dockerCompose, "Docker Compose", "Docker Engine 24+") {
      Container(dappApp, "lizswap-dapp", "Next.js next start :3001", "Serve DApp Frontend SSR")
      Container(adminApp, "lizswap-admin", "Next.js next start :3002", "Serve Admin Dashboard SSR")
      Container(backendApi, "lizswap-backend", "Node.js, TypeScript, Express :3000", "REST & WebSocket: giá, OHLCV, quản trị")
      Container(bscIndexer, "lizswap-indexer", "Node.js, TypeScript, viem", "Daemon index Swap/Mint/Burn → OHLCV")
      ContainerDb(postgres, "lizswap-postgres", "PostgreSQL 15 (Docker)", "Lưu ohlcv_candles, user_roles, system_config")
      ContainerDb(redis, "lizswap-redis", "Redis 7 (Docker)", "Cache giá token, pool stats, JWT blacklist")
      Container(nginxSvc, "lizswap-nginx", "nginx:alpine", "lizswap.xyz → :3001, admin → :3002, /api → :3000")
      Container(certbotSvc, "lizswap-certbot", "certbot/certbot", "Auto-renew SSL certificates")
    }
  }

  Deployment_Node(bscNetwork, "Binance Smart Chain", "BSC Mainnet / Testnet") {
    Container(factoryContract, "LizSwapFactory", "Solidity, Foundry", "Tạo và lưu Pair contracts")
    Container(pairContract, "LizSwapPair", "Solidity, Foundry", "AMM pool: reserves, LP Token, x*y=k")
    Container(routerContract, "LizSwapRouter", "Solidity, Foundry", "Routing swap & liquidity")
    Container(stakingContract, "LizSwapStaking", "Solidity, Foundry", "Stake LP Token, nhận reward")
  }

  Deployment_Node(bscRpc, "BSC RPC Nodes", "QuickNode / Ankr / BSC Public RPC") {
    Container(rpcEndpoint, "JSON-RPC Endpoint", "HTTPS + WebSocket", "Kết nối BSC: eth_call, getLogs, watchEvent")
  }

  %% User → Nginx → Frontend apps on VPS
  Rel(userBrowser, nginxSvc, "https://lizswap.xyz", "HTTPS")
  Rel(adminBrowser, nginxSvc, "https://admin.lizswap.xyz", "HTTPS")
  Rel(nginxSvc, dappApp, "Proxy → :3001", "HTTP")
  Rel(nginxSvc, adminApp, "Proxy → :3002", "HTTP")

  %% Nginx → Backend
  Rel(nginxSvc, backendApi, "Proxy /api → :3000, WSS upgrade", "HTTP / WS")

  %% Served pages run in browser
  Rel(dappApp, dappFe, "Serve Next.js SSR bundle", "HTTP")
  Rel(adminApp, adminFe, "Serve Next.js SSR bundle", "HTTP")

  %% Frontend → MetaMask → BSC
  Rel(dappFe, metamaskExt, "Yêu cầu ký giao dịch", "EIP-1193")
  Rel(metamaskExt, rpcEndpoint, "Phát tx đã ký", "JSON-RPC HTTPS")

  %% Frontend → BSC read (direct)
  Rel(dappFe, rpcEndpoint, "readContract: getReserves, balanceOf", "JSON-RPC HTTPS")
  Rel(rpcEndpoint, bscNetwork, "Forward to BSC node", "P2P")

  %% Backend → DB
  Rel(backendApi, postgres, "SQL queries", "TCP :5432")
  Rel(backendApi, redis, "Cache operations", "TCP :6379")
  Rel(backendApi, rpcEndpoint, "eth_call: getPair, reserves", "JSON-RPC HTTPS")

  %% Indexer pipeline
  Rel(bscIndexer, rpcEndpoint, "Subscribe Swap/Mint/Burn events", "WebSocket WSS")
  Rel(bscIndexer, postgres, "INSERT ohlcv_candles", "TCP :5432")
  Rel(bscIndexer, redis, "SET latest candle cache", "TCP :6379")

  %% Contracts on BSC
  Rel(routerContract, factoryContract, "getPair()", "EVM Call")
  Rel(routerContract, pairContract, "swap / mint / burn", "EVM Call")
  Rel(stakingContract, pairContract, "LP Token transferFrom", "ERC-20")

  UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

---

## Diagram 2 – Deployment Chi tiết VPS (Docker Compose)

```mermaid
C4Deployment
  title Deployment Diagram – VPS Internal Layout (Docker Compose)

  Deployment_Node(vpsDetail, "VPS / Cloud VM", "Ubuntu 22.04 LTS") {

    Deployment_Node(dockerCompose, "Docker Compose", "docker-compose.yml") {

      Deployment_Node(proxyLayer, "Reverse Proxy Layer", "Exposed ports 80/443") {
        Container(nginxD_svc, "lizswap-nginx", "nginx:alpine", "lizswap.xyz→:3001, admin→:3002, /api→:3000, WSS upgrade")
        Container(certbotD, "lizswap-certbot", "certbot/certbot", "Auto-renew SSL mỗi 12h")
      }

      Deployment_Node(appLayer, "Application Layer", "Internal network only") {
        Container(dappProc, "lizswap-dapp", "Next.js standalone :3001", "DApp Frontend SSR – Swap, Pool, Stake, Chart")
        Container(adminProc, "lizswap-admin", "Next.js standalone :3002", "Admin Dashboard SSR – Manager & Staff")
        Container(apiProc, "lizswap-backend", "Node.js + Express :3000", "Backend API – REST & Socket.IO")
        Container(indexerProc, "lizswap-indexer", "Node.js daemon", "BSC Indexer – không expose port")
      }

      Deployment_Node(dataLayer, "Data Layer", "Persistent volumes") {
        ContainerDb(pgDocker, "lizswap-postgres", "PostgreSQL 15 :5432", "Volume: lizswap-postgres-data")
        ContainerDb(redisDocker, "lizswap-redis", "Redis 7 :6379", "Volume: lizswap-redis-data, AOF persist")
      }

      Deployment_Node(envConfig, "Environment Config", ".env file") {
        Container(envFile, ".env", "Docker Compose env_file", "DATABASE_URL, REDIS_URL, BSC_RPC_*, FACTORY_ADDR, JWT_SECRET, NEXT_PUBLIC_*")
      }
    }
  }

  Rel(nginxD_svc, dappProc, "Proxy lizswap.xyz → :3001", "HTTP")
  Rel(nginxD_svc, adminProc, "Proxy admin.lizswap.xyz → :3002", "HTTP")
  Rel(nginxD_svc, apiProc, "Proxy /api → :3000, /socket.io WSS upgrade", "HTTP / WS")
  Rel(apiProc, pgDocker, "pg client", "TCP :5432")
  Rel(apiProc, redisDocker, "ioredis client", "TCP :6379")
  Rel(indexerProc, pgDocker, "pg client (write OHLCV)", "TCP :5432")
  Rel(indexerProc, redisDocker, "ioredis client (cache + pub/sub)", "TCP :6379")

  UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

---

## Diagram 3 – Smart Contract Deployment (Foundry)

```mermaid
C4Deployment
  title Deployment Diagram – Smart Contracts (Foundry Deploy)

  Deployment_Node(devMachine, "Developer Machine", "Local / Windows WSL2") {
    Deployment_Node(foundryEnv, "Foundry Toolchain", "forge, cast, anvil") {
      Container(deployScript, "Deploy Script", "Solidity Script / forge script", "DeployAll.s.sol: deploy Factory → Pair → Router → Staking")
      Container(anvilLocal, "Anvil", "Local BSC Fork", "Môi trường test local fork BSC")
    }
  }

  Deployment_Node(bscTestnet, "BSC Testnet (Chain ID: 97)", "Binance Smart Chain Testnet") {
    Container(factoryT, "LizSwapFactory (Testnet)", "Solidity", "Địa chỉ testnet: 0xFactory...")
    Container(routerT, "LizSwapRouter (Testnet)", "Solidity", "Địa chỉ testnet: 0xRouter...")
    Container(stakingT, "LizSwapStaking (Testnet)", "Solidity", "Địa chỉ testnet: 0xStaking...")
    Container(mockTokens, "Mock ERC-20 Tokens", "Solidity", "WBNB, USDT, MockToken A/B... cho demo")
  }

  Deployment_Node(bscMainnet, "BSC Mainnet (Chain ID: 56)", "Binance Smart Chain Mainnet") {
    Container(factoryM, "LizSwapFactory (Mainnet)", "Solidity", "Địa chỉ mainnet: 0xFactory...")
    Container(routerM, "LizSwapRouter (Mainnet)", "Solidity", "Địa chỉ mainnet: 0xRouter...")
    Container(stakingM, "LizSwapStaking (Mainnet)", "Solidity", "Địa chỉ mainnet: 0xStaking...")
  }

  Deployment_Node(bscScan, "BscScan", "Block Explorer") {
    Container(verifyTool, "Contract Verification", "forge verify-contract", "Verify source code, ABI public")
  }

  Rel(deployScript, anvilLocal, "forge script --fork-url http://localhost:8545", "RPC")
  Rel(deployScript, bscTestnet, "forge script --rpc-url BSC_TESTNET --broadcast", "JSON-RPC HTTPS")
  Rel(deployScript, bscMainnet, "forge script --rpc-url BSC_MAINNET --broadcast", "JSON-RPC HTTPS")
  Rel(deployScript, verifyTool, "forge verify-contract --chain bsc", "API")
  Rel(factoryT, routerT, "getPair() reference", "EVM")
  Rel(factoryM, routerM, "getPair() reference", "EVM")

  UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

---

## Bảng ánh xạ Container → Infrastructure

| Container | Docker Image / Build | Port / URL |
|---|---|---|
| `lizswap-dapp` | `apps/dapp/Dockerfile` (Next.js SSR) | `:3001` (internal) → `https://lizswap.xyz` |
| `lizswap-admin` | `apps/admin/Dockerfile` (Next.js SSR) | `:3002` (internal) → `https://admin.lizswap.xyz` |
| `lizswap-backend` | `packages/backend/Dockerfile` (Express) | `:3000` (internal) → `/api/*`, `/socket.io/*` qua Nginx |
| `lizswap-indexer` | `packages/indexer/Dockerfile` (daemon) | — (không expose port) |
| `lizswap-postgres` | `postgres:15-alpine` | `:5432` (internal only) |
| `lizswap-redis` | `redis:7-alpine` | `:6379` (internal only) |
| `lizswap-nginx` | `nginx:alpine` | `:80` → redirect `:443` TLS (exposed) |
| `lizswap-certbot` | `certbot/certbot` | — (SSL renewal daemon) |
| Smart Contracts | BSC Mainnet / Testnet | On-chain addresses |
| BSC RPC | External (QuickNode / Ankr) | Cấu hình qua `.env` (`BSC_RPC_URL`, `BSC_RPC_WS`) |

---

## Ghi chú triển khai

> [!IMPORTANT]
> **Nginx là entry point duy nhất**: Tất cả services (Backend, Frontend, Database, Cache) chỉ giao tiếp nội bộ qua Docker network `lizswap-network`. Chỉ Nginx container expose port `80`/`443` ra ngoài.

> [!IMPORTANT]
> **Smart Contract deploy thủ công (Foundry)**: Không có CI/CD. Developer dùng `forge script` để deploy. Sau khi deploy phải cập nhật địa chỉ contract vào `.env` (cho Backend/Indexer) và `NEXT_PUBLIC_*` env vars (cho Frontend — truyền qua Docker build args).

> [!NOTE]
> **BSC RPC**: Cấu hình qua biến môi trường `BSC_RPC_URL` (HTTPS) và `BSC_RPC_WS` (WebSocket) trong file `.env`. Nên dùng **QuickNode** hoặc **Ankr** thay vì public RPC để đảm bảo tốc độ và ổn định cho Indexer.

> [!NOTE]
> **Docker Compose**: Dùng `docker-compose.yml` ở root project để orchestrate toàn bộ services. Mỗi service có `restart: unless-stopped` để tự khởi động lại khi crash. Health checks được cấu hình cho PostgreSQL, Redis, Backend, và Frontend containers.

> [!NOTE]
> **SSL/TLS**: Dùng **Certbot container** tích hợp trong Docker Compose. Chạy `infra/certbot/init-letsencrypt.sh` lần đầu để lấy certificate. Certbot container tự động renew mỗi 12 giờ. Nginx xử lý TLS termination.

> [!NOTE]
> **Database Init**: Schema PostgreSQL được tạo tự động khi container khởi tạo lần đầu qua SQL scripts trong `infra/postgres/init/`. Manager đầu tiên (wallet `0x070714e05b45f236FeAe2A87Cb1A740fAfA047B4`) và default config được seed sẵn.

---

## Deploy Checklist (Docker Compose)

**Smart Contracts (thủ công – Foundry):**
- [ ] `forge build` – compile contracts
- [ ] `forge test` – chạy toàn bộ test suite
- [ ] `forge script DeployAll.s.sol --rpc-url BSC_TESTNET --broadcast` – deploy testnet
- [ ] `forge verify-contract` – verify trên BscScan
- [ ] Lưu địa chỉ contract vào `.env` (mục `FACTORY_ADDR`, `ROUTER_ADDR`, `STAKING_ADDR`)

**Docker Compose (toàn bộ services):**
- [ ] Clone repo
- [ ] `cp .env.example .env` – tạo file config
- [ ] Điền `.env`: `FACTORY_ADDR`, `ROUTER_ADDR`, `STAKING_ADDR`, `BSC_RPC_URL`, `BSC_RPC_WS`, `JWT_SECRET`, domains
- [ ] `docker compose up -d --build` – build images và khởi chạy tất cả
- [ ] Kiểm tra: `docker compose ps` – tất cả containers healthy
- [ ] Kiểm tra logs: `docker compose logs -f backend indexer`

**SSL Certificate (production):**
- [ ] Uncomment SSL lines trong `infra/nginx/conf.d/default.conf`
- [ ] `chmod +x infra/certbot/init-letsencrypt.sh`
- [ ] `./infra/certbot/init-letsencrypt.sh` – lấy certificate từ Let's Encrypt
- [ ] `docker compose restart nginx` – reload config với SSL
- [ ] Kiểm tra HTTPS: `https://lizswap.xyz`, `https://admin.lizswap.xyz`
