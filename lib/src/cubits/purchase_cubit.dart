import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/purchase_state.dart';
import '../services/purchase_service.dart';

/// 购买状态管理
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
    _purchaseService.onLoadingChanged = (isLoading) {
      emit(state.copyWith(isLoading: isLoading));
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
