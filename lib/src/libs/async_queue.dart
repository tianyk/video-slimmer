import 'dart:async';
import 'dart:collection';

class AsyncQueue<T> {
  final Queue<T> _queue = Queue<T>();
  // 等待者的消费者，每个消费者给他一个 Future，当有任务时，就完成这个 Future
  final Queue<Completer<T>> _waiters = Queue<Completer<T>>();

  // 添加任务
  void add(T item) {
    if (_waiters.isNotEmpty) {
      // 如果有消费者在等待，则直接完成第一个等待者的 Future
      _waiters.removeFirst().complete(item);
    } else {
      // 如果没有消费者在等待，则将任务添加到队列中
      _queue.add(item);
    }
  }

  void addAll(Iterable<T> items) {
    for (final item in items) {
      add(item);
    }
  }

  // 异步获取任务
  Future<T> take() {
    if (_queue.isNotEmpty) {
      // 如果队列不为空，则直接返回队列的第一个元素
      return Future.value(_queue.removeFirst());
    } else {
      final completer = Completer<T>();
      // 如果队列空，则返回一个 Future，当有任务时，就完成这个 Future
      _waiters.add(completer);
      // 返回一个 Future，当有任务时，就完成这个 Future，否则等待
      return completer.future;
    }
  }

  // ✅ 删除指定任务
  bool remove(T item) {
    return _queue.remove(item);
  }

  // ✅ 根据条件删除任务
  void removeWhere(bool Function(T) test) {
    _queue.removeWhere(test);
  }

  // ✅ 清空所有任务
  void clear() {
    _queue.clear();
    // 取消所有等待者
    while (_waiters.isNotEmpty) {
      _waiters.removeFirst().completeError(StateError('Queue cleared'));
    }
  }

  // 获取队列长度
  int get length => _queue.length;

  // 检查是否为空
  bool get isEmpty => _queue.isEmpty;

  // 查看所有任务(不移除)
  List<T> get items => _queue.toList();
}
