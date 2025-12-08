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
  static const String proProductId = 'com.yourcompany.videoslimmer.pro';
  
  /// 本地存储 Key
  static const String purchaseStatusKey = 'is_pro_purchased';
}
```

### 3.2 购买状态模型

```dart
// lib/src/models/purchase_state.dart

import 'package:equatable/equatable.dart';

/// 购买状态
class PurchaseState extends Equatable {
  /// 是否为Pro用户
  final bool isPro;
  
  /// 是否正在加载（查询商品/处理购买中）
  final bool isLoading;
  
  /// 商品价格显示文本（如 "¥18.00"）
  final String? priceString;
  
  /// 错误信息
  final String? errorMessage;

  const PurchaseState({
    this.isPro = false,
    this.isLoading = false,
    this.priceString,
    this.errorMessage,
  });

  PurchaseState copyWith({
    bool? isPro,
    bool? isLoading,
    String? priceString,
    String? errorMessage,
  }) {
    return PurchaseState(
      isPro: isPro ?? this.isPro,
      isLoading: isLoading ?? this.isLoading,
      priceString: priceString ?? this.priceString,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [isPro, isLoading, priceString, errorMessage];
}
```

---

## 4. 核心服务

### 4.1 购买服务

```dart
// lib/src/services/purchase_service.dart

import 'dart:async';
import 'dart:io';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class PurchaseService {
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;
  PurchaseService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  
  /// 购买状态变化回调
  Function(bool isPro)? onPurchaseStatusChanged;
  
  /// 错误回调
  Function(String error)? onPurchaseError;

  /// 初始化 IAP
  Future<void> initialize() async {
    final bool available = await _iap.isAvailable();
    if (!available) {
      onPurchaseError?.call('应用内购买不可用');
      return;
    }

    // 监听购买流
    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (error) => onPurchaseError?.call(error.toString()),
    );

    // 检查本地缓存的购买状态
    await _checkLocalPurchaseStatus();
  }

  /// 释放资源
  void dispose() {
    _subscription?.cancel();
  }

  /// 查询商品信息
  Future<ProductDetails?> queryProductDetails() async {
    final ProductDetailsResponse response = await _iap.queryProductDetails(
      {AppConstants.proProductId},
    );
    
    if (response.error != null) {
      onPurchaseError?.call(response.error!.message);
      return null;
    }
    
    if (response.productDetails.isEmpty) {
      onPurchaseError?.call('未找到商品信息');
      return null;
    }
    
    return response.productDetails.first;
  }

  /// 发起购买
  Future<void> purchasePro() async {
    final product = await queryProductDetails();
    if (product == null) return;

    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: product,
    );
    
    // 非消耗型商品
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// 恢复购买
  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  /// 处理购买更新
  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != AppConstants.proProductId) continue;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          // 购买处理中
          break;
          
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // 购买成功或恢复成功
          await _verifyAndDeliver(purchase);
          break;
          
        case PurchaseStatus.error:
          onPurchaseError?.call(purchase.error?.message ?? '购买失败');
          break;
          
        case PurchaseStatus.canceled:
          // 用户取消，不做处理
          break;
      }

      // 完成购买流程（重要：必须调用）
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  /// 验证并交付商品
  Future<void> _verifyAndDeliver(PurchaseDetails purchase) async {
    // TODO: 生产环境应进行服务端收据验证
    // 本地简单验证：检查购买状态
    if (purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored) {
      await _savePurchaseStatus(true);
      onPurchaseStatusChanged?.call(true);
    }
  }

  /// 检查本地购买状态缓存
  Future<void> _checkLocalPurchaseStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isPro = prefs.getBool(AppConstants.purchaseStatusKey) ?? false;
    onPurchaseStatusChanged?.call(isPro);
  }

  /// 保存购买状态到本地
  Future<void> _savePurchaseStatus(bool isPro) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.purchaseStatusKey, isPro);
  }

  /// 获取当前购买状态（同步）
  Future<bool> isPro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.purchaseStatusKey) ?? false;
  }
}
```

### 4.2 状态管理

```dart
// lib/src/cubits/purchase_cubit.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/purchase_state.dart';
import '../services/purchase_service.dart';

class PurchaseCubit extends Cubit<PurchaseState> {
  final PurchaseService _purchaseService;

  PurchaseCubit({PurchaseService? purchaseService})
      : _purchaseService = purchaseService ?? PurchaseService(),
        super(const PurchaseState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    _purchaseService.onPurchaseStatusChanged = (isPro) {
      emit(state.copyWith(isPro: isPro, isLoading: false));
    };
    
    _purchaseService.onPurchaseError = (error) {
      emit(state.copyWith(errorMessage: error, isLoading: false));
    };

    await _purchaseService.initialize();
    await _loadProductInfo();
  }

  /// 加载商品信息（获取价格）
  Future<void> _loadProductInfo() async {
    final product = await _purchaseService.queryProductDetails();
    if (product != null) {
      emit(state.copyWith(priceString: product.price));
    }
  }

  /// 购买 Pro
  Future<void> purchasePro() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    await _purchaseService.purchasePro();
  }

  /// 恢复购买
  Future<void> restorePurchases() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    await _purchaseService.restorePurchases();
  }

  /// 清除错误信息
  void clearError() {
    emit(state.copyWith(errorMessage: null));
  }

  @override
  Future<void> close() {
    _purchaseService.dispose();
    return super.close();
  }
}
```

---

## 5. UI 组件

### 5.1 Pro 介绍弹窗

```dart
// lib/src/widgets/pro_upgrade_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../constants/app_constants.dart';
import '../constants/app_theme.dart';
import '../cubits/purchase_cubit.dart';
import '../libs/localization.dart';
import '../models/purchase_state.dart';

class ProUpgradeSheet extends StatelessWidget {
  final int selectedCount;
  final VoidCallback? onPurchaseSuccess;

  const ProUpgradeSheet({
    super.key,
    required this.selectedCount,
    this.onPurchaseSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PurchaseCubit, PurchaseState>(
      listener: (context, state) {
        // 购买成功后关闭弹窗
        if (state.isPro) {
          onPurchaseSuccess?.call();
        }
        // 显示错误提示
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Colors.red,
            ),
          );
          context.read<PurchaseCubit>().clearError();
        }
      },
      builder: (context, state) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.prosperityGray,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 拖动指示条
                _buildDragHandle(),
                const SizedBox(height: 16),
                
                // 标题
                _buildTitle(),
                const SizedBox(height: 24),
                
                // 功能展示卡片
                _buildFeatureCard(),
                const SizedBox(height: 24),
                
                // 权益列表
                _buildBenefitsList(),
                const SizedBox(height: 24),
                
                // 当前选择提示
                _buildSelectionHint(),
                const SizedBox(height: 24),
                
                // 购买按钮
                _buildPurchaseButton(context, state),
                const SizedBox(height: 12),
                
                // 恢复购买
                _buildRestoreButton(context, state),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppTheme.prosperityLightGray,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildTitle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.star, color: AppTheme.prosperityGold, size: 28),
        const SizedBox(width: 8),
        Text(
          'Video Slimmer Pro',
          style: AppTheme.titleLarge,
        ),
      ],
    );
  }

  Widget _buildFeatureCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.prosperityBlack,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.prosperityGold.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          // 视频图标排列
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: List.generate(
              8,
              (index) => const Icon(
                Icons.videocam,
                color: AppTheme.prosperityGold,
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr('批量压缩，无限视频'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.prosperityLightGold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsList() {
    final benefits = [
      tr('一次购买，永久使用'),
      tr('无限批量压缩视频'),
      tr('支持未来所有更新'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: benefits.map((benefit) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppTheme.prosperityGold,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  benefit,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.prosperityLightGold,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSelectionHint() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.prosperityDarkGold.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.info_outline,
            color: AppTheme.prosperityGold,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            tr('当前已选择 {count} 个视频，免费版最多支持 {max} 个')
                .replaceAll('{count}', '$selectedCount')
                .replaceAll('{max}', '${AppConstants.maxFreeVideoSelection}'),
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.prosperityLightGold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseButton(BuildContext context, PurchaseState state) {
    final buttonText = state.priceString != null
        ? '${tr('立即解锁')} - ${state.priceString}'
        : tr('立即解锁');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: state.isLoading
              ? null
              : () => context.read<PurchaseCubit>().purchasePro(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.prosperityGold,
            foregroundColor: AppTheme.prosperityBlack,
            disabledBackgroundColor: AppTheme.prosperityGold.withOpacity(0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: state.isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.prosperityBlack,
                    ),
                  ),
                )
              : Text(
                  buttonText,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildRestoreButton(BuildContext context, PurchaseState state) {
    return TextButton(
      onPressed: state.isLoading
          ? null
          : () => context.read<PurchaseCubit>().restorePurchases(),
      child: Text(
        tr('恢复购买'),
        style: TextStyle(
          fontSize: 14,
          color: state.isLoading
              ? AppTheme.prosperityLightGray
              : AppTheme.prosperityGold,
        ),
      ),
    );
  }
}
```

---

## 6. 主屏幕集成

### 6.1 修改浮动按钮逻辑

```dart
// lib/src/screens/home_screen.dart (部分代码)

Widget _buildFloatingButtonContent() {
  return BlocBuilder<VideoSelectionCubit, Set<String>>(
    builder: (context, selectionState) {
      if (selectionState.isEmpty) {
        return const SizedBox.shrink();
      }

      final selectedCount = selectionState.length;
      
      return BlocBuilder<PurchaseCubit, PurchaseState>(
        builder: (context, purchaseState) {
          final isPro = purchaseState.isPro;
          final exceedsLimit = selectedCount > AppConstants.maxFreeVideoSelection;
          final showUpgrade = exceedsLimit && !isPro;

          return Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: showUpgrade
                  ? () => _showProUpgradeSheet(context, selectedCount)
                  : _onNextPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.prosperityGold,
                foregroundColor: AppTheme.prosperityBlack,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (showUpgrade) ...[
                    const Icon(Icons.lock_open, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      tr('解锁批量压缩'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else ...[
                    Text(
                      '${tr('下一步')} ($selectedCount)',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

void _showProUpgradeSheet(BuildContext context, int selectedCount) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => BlocProvider.value(
      value: context.read<PurchaseCubit>(),
      child: ProUpgradeSheet(
        selectedCount: selectedCount,
        onPurchaseSuccess: () {
          Navigator.pop(context);
          // 可选：购买成功后自动进入下一步
          // _onNextPressed();
        },
      ),
    ),
  );
}
```

### 6.2 全局 Provider 注入

```dart
// lib/main.dart

void main() {
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<PurchaseCubit>(
          create: (_) => PurchaseCubit(),
        ),
        // ... 其他 Provider
      ],
      child: const MyApp(),
    ),
  );
}
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

## 8. 测试清单

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

---

## 9. 注意事项

1. **收据验证**：生产环境建议增加服务端收据验证，防止越狱设备绕过
2. **购买完成**：必须调用 `completePurchase()`，否则会重复推送购买
3. **沙盒测试**：只能在真机上测试，模拟器不支持 IAP
4. **审核要求**：
   - 必须有"恢复购买"按钮
   - 必须在购买前展示价格
   - 建议添加隐私政策和使用条款链接

---

**文档版本**: v1.0  
**更新日期**: 2025-12-08
