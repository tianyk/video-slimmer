# iOS 应用内购买 (IAP) 技术方案

> 本文档描述 Video Slimmer Pro 版功能的技术实现方案

## 1. 功能概述

### 1.1 业务需求

| 项目 | 说明 |
|:---|:---|
| **付费功能** | 批量压缩无限制 |
| **免费版限制** | 最多同时选择 5 个视频 |
| **Pro版权益** | 无限制批量压缩 |
| **付费模式** | 一次性买断（非消耗型商品） |
| **目标平台** | iOS |

### 1.2 触发场景

当免费用户选择超过 5 个视频时：
1. "下一步"按钮文案变为"🔓 解锁批量压缩"
2. 点击按钮弹出 Pro 介绍页（Modal Bottom Sheet）
3. 用户可在介绍页完成购买或恢复购买

---

## 2. 技术架构

### 2.1 目录结构

```
lib/src/
├── constants/
│   └── app_constants.dart          # 添加 IAP 相关常量
├── services/
│   └── purchase_service.dart       # IAP 服务封装
├── cubits/
│   └── purchase_cubit.dart         # 购买状态管理
├── models/
│   └── purchase_state.dart         # 购买状态模型
└── widgets/
    └── pro_upgrade_sheet.dart      # Pro 介绍弹窗组件
```

### 2.2 依赖包

```yaml
# pubspec.yaml
dependencies:
  in_app_purchase: ^3.1.13          # Apple IAP 官方插件
  shared_preferences: ^2.2.2        # 本地存储购买状态缓存
```

**备选方案（RevenueCat）：**
```yaml
dependencies:
  purchases_flutter: ^6.17.0        # RevenueCat SDK
```

---

## 3. 数据模型

### 3.1 常量定义

```dart
// lib/src/constants/app_constants.dart

class AppConstants {
  // ... 现有常量 ...
  
  /// 免费版最大可选视频数量
  static const int maxFreeVideoSelection = 5;
  
  /// IAP 产品ID（需与 App Store Connect 配置一致）
  static const String proProductId = 'cc.kekek.videoslimmer.pro';
  
  /// 本地存储 Key
  static const String purchaseStatusKey = 'is_pro_purchased';
}
```

### 3.2 购买状态模型

> 文件路径：`lib/src/models/purchase_state.dart`

| 字段 | 类型 | 说明 |
|:---|:---|:---|
| `isPro` | `bool` | 是否为 Pro 用户 |
| `isLoading` | `bool` | 是否正在加载（查询商品/处理购买中） |
| `priceString` | `String?` | 商品价格显示文本（如 "¥18.00"） |
| `errorMessage` | `String?` | 错误信息 |

---

## 4. 核心服务

### 4.1 购买服务

> 文件路径：`lib/src/services/purchase_service.dart`

采用单例模式封装 `InAppPurchase` 实例，提供以下核心方法：

| 方法 | 说明 |
|:---|:---|
| `initialize()` | 初始化 IAP，监听购买流，检查本地缓存状态 |
| `queryProductDetails()` | 查询商品信息，返回价格等详情 |
| `purchasePro()` | 发起非消耗型商品购买 |
| `restorePurchases()` | 恢复购买记录 |
| `isPro()` | 获取当前购买状态 |

**核心逻辑 - 购买状态处理：**

```dart
switch (purchase.status) {
  case PurchaseStatus.purchased:
  case PurchaseStatus.restored:
    await _savePurchaseStatus(true);  // 保存到本地
    onPurchaseStatusChanged?.call(true);
    break;
  case PurchaseStatus.error:
    onPurchaseError?.call(purchase.error?.message ?? '购买失败');
    break;
  case PurchaseStatus.canceled:
    break;  // 用户取消，不做处理
}
// ⚠️ 重要：必须调用，否则会重复推送购买
if (purchase.pendingCompletePurchase) {
  await _iap.completePurchase(purchase);
}
```

### 4.2 状态管理

> 文件路径：`lib/src/cubits/purchase_cubit.dart`

| 方法 | 说明 |
|:---|:---|
| `purchasePro()` | 设置 loading 状态，调用购买服务 |
| `restorePurchases()` | 设置 loading 状态，调用恢复购买 |
| `clearError()` | 清除错误信息 |

初始化时自动加载商品价格并检查本地购买状态。

---

## 5. UI 组件

### 5.1 Pro 介绍弹窗

> 文件路径：`lib/src/widgets/pro_upgrade_sheet.dart`

**组件结构：**

```
ProUpgradeSheet
├── 拖动指示条
├── 标题栏（皇冠图标 + "Video Slimmer Pro"）
├── 功能展示卡片（无限符号 + 视频图标）
├── 权益列表
│   ├── ✓ 一次购买，永久使用
│   ├── ✓ 无限批量压缩视频
│   └── ✓ 支持未来所有更新
├── 当前选择提示（已选 X 个，免费版最多 5 个）
├── 购买按钮（显示动态价格）
└── 恢复购买按钮
```

**核心逻辑：**

```dart
BlocConsumer<PurchaseCubit, PurchaseState>(
  listener: (context, state) {
    if (state.isPro) onPurchaseSuccess?.call();  // 购买成功关闭弹窗
    if (state.errorMessage != null) {
      // 显示 SnackBar 错误提示
    }
  },
  builder: (context, state) {
    // 根据 state.isLoading 控制按钮状态
    // 根据 state.priceString 显示价格
  },
)
```

---

## 6. 主屏幕集成

### 6.1 浮动按钮逻辑

> 文件路径：`lib/src/screens/home_screen.dart`

**判断逻辑：**

```dart
final exceedsLimit = selectedCount > AppConstants.maxFreeVideoSelection;
final showUpgrade = exceedsLimit && !purchaseState.isPro;

// showUpgrade = true  → 显示「解锁批量压缩」，点击弹出 ProUpgradeSheet
// showUpgrade = false → 显示「下一步 (N)」，点击进入压缩配置页
```

### 6.2 全局 Provider 注入

> 文件路径：`lib/main.dart`

在 `MultiBlocProvider` 中添加 `PurchaseCubit`：

```dart
BlocProvider<PurchaseCubit>(create: (_) => PurchaseCubit()),
```

---

## 7. App Store Connect 配置

### 7.1 创建 IAP 商品

1. 登录 [App Store Connect](https://appstoreconnect.apple.com)
2. 进入 App → 功能 → App 内购买项目
3. 点击 "+" 添加新商品
4. 选择类型：**非消耗型**
5. 填写信息：
   - 参考名称：`Video Slimmer Pro`
   - 产品 ID：`com.yourcompany.videoslimmer.pro`
   - 价格：选择价格等级（如 Tier 1 = ¥6，Tier 3 = ¥18）
   - 显示名称：`Pro 版本`
   - 描述：`解锁无限批量压缩功能`

### 7.2 沙盒测试账号

1. 用户和访问 → 沙盒 → 测试员
2. 添加测试账号（使用未注册过 Apple ID 的邮箱）
3. 在真机上登出 App Store，使用沙盒账号测试购买

---

## 8. StoreKit 本地测试配置

Xcode 提供了 StoreKit Configuration File（`.storekit`），允许在**本地模拟 IAP 购买流程**，无需连接 App Store Connect，极大提升开发效率。

### 8.1 创建配置文件

1. Xcode 菜单：**File → New → File → StoreKit Configuration File**
2. 命名为 `StoreKitConfig.storekit`，保存在 `ios/Runner/` 目录

### 8.2 配置 IAP 产品

在左侧面板 **IN-APP PURCHASES** 区域添加产品：

| 配置项 | 值 | 说明 |
|:---|:---|:---|
| **Reference Name** | Video Slimmer Pro | 产品参考名称 |
| **Product ID** | `video_slimmer_pro` | 需与代码中 `AppConstants.proProductId` 一致 |
| **Type** | Non-Consumable | 非消耗型（一次性买断） |
| **Price** | 18.00 | 测试价格（人民币） |

### 8.3 配置测试环境

在右侧面板配置测试参数：

#### Storefront and Localization（店面和本地化）

| 配置项 | 推荐值 | 说明 |
|:---|:---|:---|
| **Default Storefront** | China mainland (CNY) | 默认商店区域 |
| **Default Localization** | Chinese (Simplified) | 默认语言 |

#### Purchase Options（购买选项）

| 配置项 | 可选值 | 推荐值 | 说明 |
|:---|:---|:---|:---|
| **Subscription Renewal Rate** | Real Time / Monthly Rate / Yearly Rate | Real Time | 订阅续费速率，Real Time 表示实时续费，加速测试订阅周期 |
| **Interrupted Purchases** | Not Enabled / Enabled | Not Enabled | 模拟购买中断场景（如需要 SCA 强认证） |
| **Billing Retry** | Not Enabled / Enabled | Not Enabled | 模拟账单重试场景（支付失败后自动重试） |
| **Grace Period** | Not Enabled / 3 Days / 6 Days / 16 Days | Not Enabled | 订阅宽限期，过期后仍可使用服务的天数 |
| **Ask to Buy** | Not Enabled / Enabled | Not Enabled | 模拟家长控制"请求购买"功能 |
| **Dialogs** | Enabled / Disabled | Enabled | 是否显示系统购买确认对话框 |

> **提示**：本项目为非消耗型商品，Subscription 相关选项（Renewal Rate、Grace Period）不影响测试。

### 8.4 模拟故障场景

**Simulated StoreKit Failures** 用于测试错误处理逻辑，勾选后可模拟对应错误。

#### 故障模拟详情

| 故障项 | 可选错误 | 触发时机 | 用户体验 |
|:---|:---|:---|:---|
| ⭐⭐⭐ **Load Products** | Network Error | `queryProductDetails()` | 无法获取价格 |
| ⭐⭐⭐ **Purchase** | Product Unavailable | `buyNonConsumable()` | 购买失败，显示错误提示 |
| ⭐ **Verification** | Revoked Certificate | 收据验证时 | 付款成功但功能未解锁 |
| ⭐⭐ **App Store Sync** | Network Error | `restorePurchases()` | 恢复购买失败 |
| ⚪ **Subscription Status** | Network Error | 查询订阅状态 | *本项目不涉及* |
| ⚪ **App Transaction** | System Error | 获取交易历史 | 无法自动恢复 Pro |
| ⚪ **Manage Subscriptions** | System Error | 打开订阅管理页 | *本项目不涉及* |
| ⚪ **Refund Request** | Duplicate Request | 发起退款时 | 提示重复请求 |
| ⚪ **Offer Code Redeem** | Not Available | 兑换优惠码时 | *本项目不涉及* |

> **注意**：标记 ⚪ 的项目本项目暂不涉及，可跳过测试。

#### 8.4.10 本项目测试优先级

| 优先级 | 故障项 | 测试目的 |
|:---|:---|:---|
| ⭐⭐⭐ 必测 | **Load Products** | 验证网络异常时价格显示和错误提示 |
| ⭐⭐⭐ 必测 | **Purchase** | 验证购买失败时的 UI 反馈和状态恢复 |
| ⭐⭐ 建议 | **App Store Sync** | 验证"恢复购买"失败时的处理 |
| ⭐ 可选 | **Verification** | 验证收据验证失败的边界场景 |
| ⚪ 跳过 | 其他 | 本项目暂不涉及订阅/优惠码/退款功能 |

#### 8.4.11 测试流程示例

```
1. 打开 StoreKitConfig.storekit
2. 勾选 "Load Products" → Network Error
3. 运行应用 → 点击购买按钮
4. 预期结果：显示"未找到商品信息"错误
5. 取消勾选，继续测试下一项
```

#### 8.4.12 配置修改生效规则

StoreKit 配置修改**大部分实时生效**，无需重启应用：

| 配置类型 | 生效方式 | 说明 |
|:---|:---|:---|
| **Simulated Failures** | ✅ 实时生效 | 勾选/取消后，下次 API 调用立即生效 |
| **Purchase Options** | ✅ 实时生效 | 如 Dialogs、Ask to Buy 等 |
| **Storefront / Localization** | ⚠️ 需重新查询 | 修改后需重新调用 `queryProductDetails()` |
| **产品价格 / 信息** | ⚠️ 需重新查询 | 修改后需重新查询商品信息 |
| **新增 / 删除产品** | ⚠️ 需重新查询 | 修改后需重新查询商品列表 |
| **Scheme 关联变更** | ❌ 需重启应用 | 修改 Scheme 的 StoreKit Configuration 需重新运行 |

**实时测试流程：** 应用运行中直接修改配置 → 下次 API 调用立即生效 → 无需重启

**商品信息变更：** 修改价格/名称后需重新进入购买页面或调用 `queryProductDetails()` 刷新

### 8.5 关联 Scheme 配置

1. Xcode 菜单：**Product → Scheme → Edit Scheme**
2. 选择 **Run** → **Options** 标签
3. **StoreKit Configuration** 选择 `StoreKitConfig.storekit`

### 8.6 测试流程

1. **启动应用**：使用关联了 StoreKit 配置的 Scheme 运行
2. **触发购买**：选择超过 5 个视频，点击「解锁批量压缩」
3. **模拟支付**：系统弹出模拟购买对话框，确认即可
4. **验证状态**：`PurchaseState.isPro` 应变为 `true`
5. **恢复购买**：点击「恢复购买」测试恢复逻辑

### 8.7 测试优势

| 优势 | 说明 |
|:---|:---|
| 🚀 **无需真机** | 模拟器即可完整测试 IAP 流程 |
| 🔄 **快速迭代** | 无需等待 App Store Connect 审核 |
| ⚡ **即时验证** | 购买立即生效，无网络延迟 |
| 🐛 **错误模拟** | 可模拟各种边界场景和异常 |
| 🔒 **隔离环境** | 不产生真实交易，安全可控 |

### 8.8 注意事项

1. **Product ID 一致性**：配置文件中的 Product ID 必须与 `AppConstants.proProductId` 完全一致
2. **Scheme 关联**：每次运行需确保 Scheme 已关联 StoreKit 配置
3. **真机测试**：上线前仍需在真机使用沙盒账号进行完整测试
4. **配置同步**：StoreKit 配置不会与 App Store Connect 同步，需手动保持一致

---

## 9. 测试清单

| 测试项 | 说明 |
|:---|:---|
| ✅ 商品查询 | 能正确获取商品信息和价格 |
| ✅ 购买流程 | 完成购买后状态正确更新 |
| ✅ 恢复购买 | 换设备后能恢复购买记录 |
| ✅ 界面限制 | 免费用户选择>5个视频时显示升级按钮 |
| ✅ Pro用户 | 购买后无任何限制 |
| ✅ 网络异常 | 无网络时有友好提示 |
| ✅ 购买取消 | 用户取消购买后状态正确 |
| ✅ 购买失败 | 失败时显示错误信息 |
| ✅ StoreKit 模拟 | 本地 StoreKit 配置能正常模拟购买流程 |
| ✅ 故障模拟 | 开启故障模拟后能正确触发错误处理 |

---

## 10. 注意事项

1. **收据验证**：生产环境建议增加服务端收据验证，防止越狱设备绕过
2. **购买完成**：必须调用 `completePurchase()`，否则会重复推送购买
3. **沙盒测试**：只能在真机上测试，模拟器不支持 IAP（但 StoreKit 配置可在模拟器运行）
4. **审核要求**：
   - 必须有"恢复购买"按钮
   - 必须在购买前展示价格
   - 建议添加隐私政策和使用条款链接

---

**文档版本**: v1.2  
**更新日期**: 2025-12-11
