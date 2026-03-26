# C4 Level 1 – System Context Diagram

## LizSwap DEX

LizSwap là một Sàn giao dịch phi tập trung (DEX) triển khai trên **Binance Smart Chain (BSC)**,
sử dụng cơ chế **Automated Market Maker (AMM)** theo mô hình Uniswap V2.  
Người dùng có thể hoán đổi token ERC-20, cung cấp thanh khoản, stake LP Token,
và theo dõi biểu đồ nến realtime cho các cặp giao dịch có pool trực tiếp.

---

## Actors (Người dùng / Hệ thống ngoài)

| Actor | Loại | Mô tả |
|---|---|---|
| Trader | Người dùng | Hoán đổi token (Swap), xem biểu đồ giá |
| Liquidity Provider | Người dùng | Thêm/rút thanh khoản, nhận LP Token, stake LP |
| Manager | Người dùng nội bộ | Quản trị toàn bộ: cấu hình app, quản lý contract, phân quyền Staff |
| Staff | Người dùng nội bộ | Theo dõi hoạt động, hỗ trợ người dùng (không có quyền quản lý contract/cài đặt) |
| MetaMask | Hệ thống ngoài | Ví Web3, ký xác thực giao dịch on-chain |
| Binance Smart Chain | Hệ thống ngoài | Mạng Blockchain BSC – thực thi Smart Contract |
| BSC Price Oracle | Hệ thống ngoài | Cung cấp giá token on-chain (PancakeSwap / hệ thống pool nội bộ) |
| OHLCV Data Source | Hệ thống ngoài | Cung cấp dữ liệu nến lịch sử cho cặp có pool trực tiếp (tự index hoặc third-party) |

---

## Diagram

```mermaid
C4Context
  title System Context – LizSwap DEX (BSC)

  Person(trader, "Trader", "Hoán đổi token, xem biểu đồ nến")
  Person(lp, "Liquidity Provider", "Thêm/rút thanh khoản, stake LP Token")
  Person(manager, "Manager", "Quản trị hệ thống, hợp đồng và phân quyền")
  Person(staff, "Staff", "Theo dõi hoạt động, hỗ trợ người dùng")

  System(lizswap, "LizSwap", "DEX on BSC: Swap, Liquidity, LP Stake, Admin Dashboard, Candlestick chart")

  System_Ext(metamask, "MetaMask", "Web3 Wallet – ký và phát giao dịch BSC")
  System_Ext(bsc, "Binance Smart Chain", "Mạng Blockchain: thực thi Factory/Pair/Router contracts")
  System_Ext(priceOracle, "BSC Price Oracle", "Giá token realtime từ pool on-chain")
  System_Ext(ohlcvSource, "OHLCV Data Source", "Dữ liệu nến cho các cặp có direct pool")

  Rel(trader, lizswap, "Swap token, xem chart", "HTTPS / Web3")
  Rel(lp, lizswap, "Add/Remove liquidity, Stake LP", "HTTPS / Web3")
  Rel(manager, lizswap, "Quản trị hệ thống & hợp đồng", "HTTPS")
  Rel(staff, lizswap, "Theo dõi & hỗ trợ", "HTTPS")

  Rel(lizswap, metamask, "Yêu cầu ký giao dịch", "EIP-1193 / wagmi+viem")
  Rel(metamask, bsc, "Phát giao dịch đã ký", "JSON-RPC")
  Rel(lizswap, bsc, "Đọc trạng thái on-chain", "JSON-RPC / viem")
  Rel(lizswap, priceOracle, "Lấy giá token realtime", "JSON-RPC / HTTP")
  Rel(lizswap, ohlcvSource, "Lấy dữ liệu OHLCV (cặp direct pool)", "HTTP / WebSocket")

  UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

---

## Ghi chú thiết kế

- **Candle Chart Logic**: Chỉ hiển thị chart nến cho các cặp có **direct pool** (ví dụ: BNB/USDT).  
  Các cặp phải routing qua nhiều pool (ví dụ: ASP → BNB → JPY) sẽ hiển thị thông báo *"Không có dữ liệu chart"*.
- **Manager vs Staff**: Manager có toàn quyền (bao gồm gọi hàm admin trên Smart Contract).  
  Staff chỉ xem dashboard, không được thao tác contract hoặc thay đổi cấu hình hệ thống.