import 'package:equatable/equatable.dart';

/// 购买状态模型
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
