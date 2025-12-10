import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../libs/logger.dart';

final _logger = Logger.getLogger();

/// IAP 购买服务
/// 处理应用内购买的所有逻辑
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

  /// 加载状态变化回调
  Function(bool isLoading)? onLoadingChanged;

  /// 初始化 IAP
  Future<void> initialize() async {
    final bool available = await _iap.isAvailable();
    if (!available) {
      _logger.warning('IAP 不可用');
      onPurchaseError?.call('应用内购买不可用');
      return;
    }
    _logger.info('IAP 初始化成功');
    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (error) {
        _logger.error('IAP 购买流错误', error: error);
        onPurchaseError?.call(error.toString());
      },
    );
    await _checkLocalPurchaseStatus();
  }

  /// 释放资源
  void dispose() {
    _subscription?.cancel();
  }

  /// 查询商品信息
  Future<ProductDetails?> queryProductDetails() async {
    _logger.info('查询商品信息: ${AppConstants.proProductId}');
    final ProductDetailsResponse response = await _iap.queryProductDetails(
      {AppConstants.proProductId},
    );
    if (response.error != null) {
      _logger.error('查询商品失败', error: response.error);
      onPurchaseError?.call(response.error!.message);
      return null;
    }
    if (response.productDetails.isEmpty) {
      _logger.warning('未找到商品信息');
      onPurchaseError?.call('未找到商品信息');
      return null;
    }
    final product = response.productDetails.first;
    _logger.info('商品信息: ${product.title}, 价格: ${product.price}');
    return product;
  }

  /// 发起购买
  Future<void> purchasePro() async {
    onLoadingChanged?.call(true);
    final product = await queryProductDetails();
    if (product == null) {
      onLoadingChanged?.call(false);
      return;
    }
    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: product,
    );
    _logger.info('发起购买: ${product.id}');
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// 恢复购买
  Future<void> restorePurchases() async {
    _logger.info('恢复购买');
    onLoadingChanged?.call(true);
    await _iap.restorePurchases();
  }

  /// 处理购买更新
  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      _logger.info('购买更新: ${purchase.productID}, 状态: ${purchase.status}');
      if (purchase.productID != AppConstants.proProductId) continue;
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _logger.info('购买处理中...');
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _logger.info('购买成功或已恢复');
          await _verifyAndDeliver(purchase);
          break;
        case PurchaseStatus.error:
          _logger.error('购买失败', error: purchase.error);
          onPurchaseError?.call(purchase.error?.message ?? '购买失败');
          onLoadingChanged?.call(false);
          break;
        case PurchaseStatus.canceled:
          _logger.info('用户取消购买');
          onLoadingChanged?.call(false);
          break;
      }
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
        _logger.info('完成购买流程');
      }
    }
  }

  /// 验证并交付商品
  Future<void> _verifyAndDeliver(PurchaseDetails purchase) async {
    if (purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored) {
      await _savePurchaseStatus(true);
      onPurchaseStatusChanged?.call(true);
      onLoadingChanged?.call(false);
      _logger.info('Pro 功能已解锁');
    }
  }

  /// 检查本地购买状态缓存
  Future<void> _checkLocalPurchaseStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isPro = prefs.getBool(AppConstants.purchaseStatusKey) ?? false;
    _logger.info('本地购买状态: isPro=$isPro');
    onPurchaseStatusChanged?.call(isPro);
  }

  /// 保存购买状态到本地
  Future<void> _savePurchaseStatus(bool isPro) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.purchaseStatusKey, isPro);
    _logger.info('保存购买状态: isPro=$isPro');
  }

  /// 获取当前购买状态
  Future<bool> isPro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.purchaseStatusKey) ?? false;
  }
}
