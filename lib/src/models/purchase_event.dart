/// 购买事件（统一事件流）
///
/// 使用 sealed class 实现类型安全的事件分发，
/// 支持模式匹配，避免回调函数被覆盖的问题。
sealed class PurchaseEvent {
  const PurchaseEvent();
}

/// 购买状态变化事件
class PurchaseStatusChanged extends PurchaseEvent {
  final bool isPro;

  const PurchaseStatusChanged(this.isPro);

  @override
  String toString() => 'PurchaseStatusChanged(isPro: $isPro)';
}

/// 购买错误事件
class PurchaseError extends PurchaseEvent {
  final String message;

  const PurchaseError(this.message);

  @override
  String toString() => 'PurchaseError(message: $message)';
}

/// 购买加载状态事件
class PurchaseLoading extends PurchaseEvent {
  final bool isLoading;

  const PurchaseLoading(this.isLoading);

  @override
  String toString() => 'PurchaseLoading(isLoading: $isLoading)';
}
