import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/purchase_event.dart';
import '../models/purchase_state.dart';
import '../services/purchase_service.dart';

/// 购买状态管理
class PurchaseCubit extends Cubit<PurchaseState> {
  /// 购买服务（由 Cubit 创建和管理生命周期）
  final PurchaseService _purchaseService = PurchaseService();

  /// 事件流订阅（统一管理）
  StreamSubscription<PurchaseEvent>? _subscription;

  PurchaseCubit() : super(const PurchaseState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    // 订阅购买事件流，使用模式匹配处理不同事件
    _subscription = _purchaseService.events.listen((event) {
      switch (event) {
        case PurchaseStatusChanged(:final isPro):
          emit(state.copyWith(isPro: isPro, isLoading: false));
        case PurchaseError(:final message):
          emit(state.copyWith(errorMessage: message, isLoading: false));
        case PurchaseLoading(:final isLoading):
          emit(state.copyWith(isLoading: isLoading));
      }
    });
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
    _subscription?.cancel();
    _purchaseService.dispose();
    return super.close();
  }
}
