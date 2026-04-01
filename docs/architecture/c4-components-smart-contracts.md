# C4 Level 3 – Component Diagram: Smart Contracts

## LizSwap Smart Contracts

Đây là thiết kế bên trong lớp **Smart Contracts** của LizSwap trên BSC,
theo mô hình **Uniswap V2** với sự tách biệt rõ ràng giữa **Core** và **Periphery**.  
Tất cả contracts được viết bằng **Solidity** và triển khai bằng **Foundry**.

---

## Kiến trúc tổng quan – Core vs Periphery

```
┌─────────────────────────────────────────────────────────────────────┐
│                         PERIPHERY (Entry Points)                    │
│   ┌──────────────────────────┐   ┌──────────────────────────────┐  │
│   │      Router Contract     │   │    LP Staking Contract       │  │
│   │  (LizSwapRouter.sol)     │   │    (LizSwapStaking.sol)      │  │
│   └────────────┬─────────────┘   └──────────────────────────────┘  │
└────────────────│────────────────────────────────────────────────────┘
                 │ EVM Call
┌────────────────▼────────────────────────────────────────────────────┐
│                           CORE (Immutable)                          │
│   ┌──────────────────────────┐   ┌──────────────────────────────┐  │
│   │    Factory Contract      │──▶│      Pair Contract           │  │
│   │  (LizSwapFactory.sol)    │   │    (LizSwapPair.sol)         │  │
│   └──────────────────────────┘   └──────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Diagram 1 – Tổng thể Smart Contract Components

```mermaid
C4Component
  title Component Diagram – Smart Contracts (LizSwap DEX)

  Container(router_ext, "DApp Frontend", "Next.js, viem", "Gọi Router & Staking qua JSON-RPC")
  Container(indexer_ext, "BSC Indexer", "Node.js", "Subscribe sự kiện Swap/Mint/Burn")

  Container_Boundary(core, "Core Contracts (Immutable)") {
    Component(factory, "LizSwapFactory", "Solidity", "Tạo & lưu địa chỉ các Pair, quản lý feeTo")
    Component(pair, "LizSwapPair", "Solidity ERC-20", "AMM pool: reserves, x*y=k, LP Token, price oracle nội bộ")
    Component(erc20base, "LizSwapERC20", "Solidity ERC-20", "Base LP Token: transfer, approve, permit (EIP-2612)")
  }

  Container_Boundary(periphery, "Periphery Contracts (Replaceable Entry Points)") {
    Component(router, "LizSwapRouter", "Solidity", "Routing swap & liquidity an toàn, tính slippage, deadline")
    Component(staking, "LizSwapStaking", "Solidity", "Stake LP Token nhận reward token, tính reward theo block")
    Component(mockToken, "MockERC20", "Solidity ERC-20", "Token thử nghiệm cho môi trường dev/testnet")
  }

  %% Frontend → Periphery
  Rel(router_ext, router, "swapExactTokensForTokens / addLiquidity", "JSON-RPC / EVM")
  Rel(router_ext, staking, "stake / unstake / claimReward", "JSON-RPC / EVM")

  %% Router → Core
  Rel(router, factory, "getPair(tokenA, tokenB)", "EVM Internal Call")
  Rel(router, pair, "swap(amount0Out, amount1Out, to)", "EVM Internal Call")
  Rel(router, pair, "mint(to) / burn(to)", "EVM Internal Call")

  %% Factory → Pair
  Rel(factory, pair, "CREATE2: deploy LizSwapPair", "EVM Deploy")
  Rel(pair, factory, "feeTo() – lấy địa chỉ nhận protocol fee", "EVM Internal Call")

  %% Pair kế thừa ERC20
  Rel(pair, erc20base, "Kế thừa (inheritance)", "Solidity")

  %% Staking → Pair LP Token
  Rel(staking, pair, "transferFrom LP Token về Staking Contract", "ERC-20 Transfer")

  %% Indexer lắng nghe events
  Rel(indexer_ext, pair, "Subscribe: Swap, Mint, Burn events", "WebSocket / ABI")

  UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

---

## Diagram 2 – Chi tiết LizSwapFactory

```mermaid
C4Component
  title Component Diagram – LizSwapFactory (Core)

  Container_Boundary(factory_boundary, "LizSwapFactory.sol") {
    Component(createPair, "createPair()", "function", "Deploy Pair mới bằng CREATE2, lưu allPairs[]")
    Component(getPair, "getPair()", "mapping", "Tra cứu địa chỉ Pair từ (tokenA, tokenB)")
    Component(allPairs, "allPairs[]", "address[]", "Danh sách toàn bộ Pair đã tạo")
    Component(feeTo, "feeTo / feeToSetter", "address", "Địa chỉ nhận protocol fee (0.05%), Manager quản lý")
    Component(pairCreated, "PairCreated event", "event", "Emit khi Pair mới được tạo")
  }

  Component(router_c, "LizSwapRouter", "Solidity", "Gọi createPair hoặc getPair")
  Component(frontend_c, "DApp Frontend", "Next.js", "Gọi getPair để kiểm tra pool tồn tại")
  Component(manager_c, "Manager (via Admin Dashboard)", "Browser", "Gọi setFeeTo(), setFeeToSetter()")

  Rel(router_c, getPair, "Tra cứu địa chỉ Pair", "EVM Call")
  Rel(frontend_c, getPair, "Kiểm tra direct pool (chart logic)", "JSON-RPC")
  Rel(manager_c, feeTo, "setFeeTo() – cập nhật địa chỉ thu phí", "EVM Call")
  Rel(createPair, pairCreated, "emit PairCreated", "Solidity")
  Rel(createPair, allPairs, "push(newPair)", "Solidity")

  UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

---

## Diagram 3 – Chi tiết LizSwapPair (AMM Core)

```mermaid
C4Component
  title Component Diagram – LizSwapPair (Core AMM Pool)

  Container_Boundary(pair_boundary, "LizSwapPair.sol") {
    Component(reserves, "reserve0 / reserve1", "uint112", "Số dư token0 & token1 trong pool")
    Component(kLast, "kLast", "uint256", "Giá trị x*y trước lần cuối, dùng tính protocol fee")
    Component(swap_fn, "swap()", "function", "Thực thi hoán đổi token, kiểm tra invariant x*y=k")
    Component(mint_fn, "mint()", "function", "Thêm thanh khoản: tính LP token, trừ fee nếu feeTo != 0")
    Component(burn_fn, "burn()", "function", "Rút thanh khoản: đổi LP token → token0 + token1")
    Component(update_fn, "_update()", "function private", "Cập nhật reserves, tích luỹ price0/1CumulativeLast")
    Component(priceAccum, "price0/1CumulativeLast", "uint224", "Tích luỹ giá cho TWAP oracle nội bộ")
    Component(lock, "lock modifier", "reentrancy guard", "Ngăn chặn tấn công reentrancy")
    Component(events, "Swap / Mint / Burn events", "event", "Emit mỗi lần giao dịch (Indexer lắng nghe)")
    Component(permit_fn, "permit()", "EIP-2612", "Approve không cần tx, dùng signature")
  }

  Component(router_d, "LizSwapRouter", "Solidity", "Gọi swap/mint/burn")
  Component(indexer_d, "BSC Indexer", "Node.js", "Lắng nghe Swap/Mint/Burn events")

  Rel(router_d, swap_fn, "swap(amount0Out, amount1Out, to, data)", "EVM Call")
  Rel(router_d, mint_fn, "mint(to)", "EVM Call")
  Rel(router_d, burn_fn, "burn(to)", "EVM Call")
  Rel(swap_fn, update_fn, "Gọi sau mỗi swap", "Solidity")
  Rel(mint_fn, update_fn, "Gọi sau khi mint", "Solidity")
  Rel(burn_fn, update_fn, "Gọi sau khi burn", "Solidity")
  Rel(update_fn, reserves, "Cập nhật reserve0/reserve1", "Solidity")
  Rel(update_fn, priceAccum, "Cộng dồn price cumulative", "Solidity")
  Rel(swap_fn, events, "emit Swap()", "Solidity")
  Rel(mint_fn, events, "emit Mint()", "Solidity")
  Rel(burn_fn, events, "emit Burn()", "Solidity")
  Rel(indexer_d, events, "Subscribe & decode events", "WebSocket ABI")

  UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

---

## Diagram 4 – Chi tiết LizSwapRouter (Periphery)

```mermaid
C4Component
  title Component Diagram – LizSwapRouter (Periphery)

  Container_Boundary(router_boundary, "LizSwapRouter.sol") {
    Component(swapExact, "swapExactTokensForTokens()", "function", "Swap chính xác input, kiểm tra amountOutMin (slippage)")
    Component(swapForExact, "swapTokensForExactTokens()", "function", "Swap để nhận chính xác output, kiểm tra amountInMax")
    Component(addLiq, "addLiquidity()", "function", "Tính optimal amounts, gọi Pair.mint(), hỗ trợ slippage")
    Component(removeLiq, "removeLiquidity()", "function", "Approve LP Token, gọi Pair.burn()")
    Component(getAmounts, "getAmountsOut() / getAmountsIn()", "pure function", "Tính toán lộ trình & số lượng token qua nhiều Pair")
    Component(deadline, "ensure(deadline) modifier", "modifier", "Từ chối tx quá hạn để tránh front-running")
    Component(library, "LizSwapLibrary", "Solidity library", "Tính amount với fee 0.3%, sắp xếp token, tính path")
  }

  Component(frontend_r, "DApp Frontend", "Next.js, viem", "Gọi các hàm swap/liquidity")
  Component(factory_r, "LizSwapFactory", "Solidity", "Cung cấp địa chỉ Pair")
  Component(pair_r, "LizSwapPair", "Solidity", "Thực thi swap/mint/burn thực sự")

  Rel(frontend_r, swapExact, "swapExactTokensForTokens(..., deadline)", "JSON-RPC")
  Rel(frontend_r, addLiq, "addLiquidity(tokenA, tokenB, amounts, deadline)", "JSON-RPC")
  Rel(frontend_r, removeLiq, "removeLiquidity(tokenA, tokenB, liquidity, deadline)", "JSON-RPC")
  Rel(swapExact, getAmounts, "Tính amountsOut qua path", "Solidity")
  Rel(addLiq, library, "Tính optimal amounts", "Solidity")
  Rel(getAmounts, factory_r, "getPair(tokenA, tokenB)", "EVM Call")
  Rel(swapExact, pair_r, "pair.swap()", "EVM Call")
  Rel(addLiq, pair_r, "pair.mint()", "EVM Call")
  Rel(removeLiq, pair_r, "pair.burn()", "EVM Call")

  UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

---

## Diagram 5 – Chi tiết LizSwapStaking (Periphery)

```mermaid
C4Component
  title Component Diagram – LizSwapStaking (Periphery)

  Container_Boundary(staking_boundary, "LizSwapStaking.sol") {
    Component(stake_fn, "stake(amount)", "function", "Nhận LP Token từ user, cập nhật balance & rewardDebt")
    Component(unstake_fn, "unstake(amount)", "function", "Trả LP Token về user, tự động claim reward")
    Component(claim_fn, "claimReward()", "function", "Tính & chuyển reward token đến user")
    Component(updatePool, "updatePool()", "function", "Cập nhật accRewardPerShare theo số block đã qua")
    Component(pendingReward, "pendingReward(user)", "view", "Tính reward chưa claim của user")
    Component(userInfo, "userInfo mapping", "mapping", "Lưu amount staked & rewardDebt mỗi user")
    Component(poolInfo, "poolInfo", "struct", "lpToken addr, allocPoint, lastRewardBlock, accRewardPerShare")
    Component(rewardToken, "rewardToken", "address", "Token dùng để trả reward (Manager cấu hình)")
    Component(rewardPerBlock, "rewardPerBlock", "uint256", "Tốc độ phát reward (Manager cấu hình)")
  }

  Component(lp_user, "Liquidity Provider", "Browser + MetaMask", "Stake/Unstake/Claim")
  Component(pair_s, "LizSwapPair (LP Token)", "Solidity ERC-20", "LP Token được deposit vào Staking")
  Component(manager_s, "Manager", "Browser", "Cập nhật rewardPerBlock, thêm pool")

  Rel(lp_user, stake_fn, "stake(amount LP Token)", "JSON-RPC")
  Rel(lp_user, unstake_fn, "unstake(amount)", "JSON-RPC")
  Rel(lp_user, claim_fn, "claimReward()", "JSON-RPC")
  Rel(lp_user, pendingReward, "pendingReward(address) – view", "JSON-RPC")
  Rel(stake_fn, pair_s, "transferFrom(user, contract, amount)", "ERC-20")
  Rel(unstake_fn, pair_s, "transfer(user, amount)", "ERC-20")
  Rel(stake_fn, updatePool, "Cập nhật pool trước khi ghi", "Solidity")
  Rel(claim_fn, updatePool, "Cập nhật pool trước khi claim", "Solidity")
  Rel(manager_s, rewardPerBlock, "set() – điều chỉnh tốc độ reward", "EVM Call")
  Rel(manager_s, rewardToken, "Nạp reward token vào contract", "ERC-20 Transfer")

  UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

---

## Bảng tổng hợp Functions & Events

### LizSwapFactory
| Function / Event | Visibility | Mô tả |
|---|---|---|
| `createPair(tokenA, tokenB)` | external | Deploy Pair mới bằng CREATE2 |
| `getPair(tokenA, tokenB)` | external view | Tra cứu địa chỉ Pair |
| `allPairs(index)` | external view | Lấy Pair theo index |
| `allPairsLength()` | external view | Tổng số Pair |
| `setFeeTo(address)` | external | Manager only – địa chỉ nhận protocol fee |
| `setFeeToSetter(address)` | external | Chuyển quyền quản lý fee |
| `PairCreated(token0, token1, pair, uint)` | event | Emit khi tạo Pair mới |

### LizSwapPair
| Function / Event | Visibility | Mô tả |
|---|---|---|
| `swap(amount0Out, amount1Out, to, data)` | external lock | Thực thi swap với flash loan support |
| `mint(to)` | external lock | Add liquidity, nhận LP Token |
| `burn(to)` | external lock | Remove liquidity, đốt LP Token |
| `getReserves()` | external view | Trả về (reserve0, reserve1, blockTimestampLast) |
| `price0/1CumulativeLast` | public | Biến tích luỹ TWAP |
| `permit(owner, spender, value, deadline, v, r, s)` | external | EIP-2612 gasless approve |
| `Swap / Mint / Burn / Sync` | events | BSC Indexer subscribe |

### LizSwapRouter
| Function | Mô tả |
|---|---|
| `swapExactTokensForTokens()` | Swap theo exact input |
| `swapTokensForExactTokens()` | Swap theo exact output |
| `addLiquidity()` | Thêm thanh khoản |
| `removeLiquidity()` | Rút thanh khoản |
| `getAmountsOut() / getAmountsIn()` | Tính toán path & amounts |

### LizSwapStaking
| Function | Mô tả |
|---|---|
| `stake(uint256)` | Deposit LP Token |
| `unstake(uint256)` | Rút LP Token + claim reward |
| `claimReward()` | Claim reward token |
| `pendingReward(address)` | View reward chưa claim |
| `updatePool()` | Cập nhật accRewardPerShare |

---

## Ghi chú bảo mật

> [!IMPORTANT]
> **Reentrancy Guard**: Tất cả các hàm thay đổi state trong `LizSwapPair` phải dùng modifier `lock` để ngăn reentrancy attack.

> [!IMPORTANT]
> **Slippage & Deadline**: `LizSwapRouter` phải kiểm tra `amountOutMin`, `amountInMax` và `deadline` cho mỗi giao dịch để bảo vệ người dùng khỏi MEV/front-running.

> [!NOTE]
> **Protocol Fee**: Kích hoạt bằng cách set `feeTo != address(0)` trong Factory. Khi bật, 1/6 của 0.3% swap fee (~0.05%) được tích luỹ vào Pair và rút ra khi `mint/burn`.