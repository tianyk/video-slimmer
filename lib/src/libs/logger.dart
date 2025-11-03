import 'dart:developer' as developer;

/// 日志级别
/// 对应 package:logging 和 dart:developer 的标准级别
enum LogLevel {
  /// 调试信息 - FINE(500)
  debug(500),

  /// 常规信息 - INFO(800)
  info(800),

  /// 警告信息 - WARNING(900)
  warning(900),

  /// 错误信息 - SEVERE(1000)
  error(1000),

  /// 关闭日志 - OFF(2000)
  none(2000);

  /// developer.log 使用的数值级别
  final int value;

  const LogLevel(this.value);
}

/// 全局日志配置
class LoggerConfig {
  static LogLevel globalLevel = LogLevel.debug;

  static void setLevel(LogLevel level) {
    globalLevel = level;
  }
}

/// 日志类
class Logger {
  final String namespace;
  final LogLevel level;

  /// 私有构造函数，只能通过 getLogger 静态方法创建实例
  Logger._(this.namespace, {this.level = LogLevel.debug});

  /// 获取 Logger 实例，自动从堆栈中获取调用文件作为命名空间
  ///
  /// 使用示例：
  /// ```dart
  /// final logger = Logger.getLogger();
  /// logger.info('这是一条日志');
  /// logger.debug('调试信息', {'key': 'value'});
  /// logger.error('错误信息', error: e, stackTrace: stackTrace);
  /// ```
  static Logger getLogger() {
    final stackTrace = StackTrace.current;
    final namespace = _extractNamespaceFromStackTrace(stackTrace);
    return Logger._(namespace, level: LoggerConfig.globalLevel);
  }

  void debug(String message, [Map<String, dynamic>? data]) {
    if (level.index <= LogLevel.debug.index) {
      _log(LogLevel.debug, message, data: data);
    }
  }

  void info(String message, [Map<String, dynamic>? data]) {
    if (level.index <= LogLevel.info.index) {
      _log(LogLevel.info, message, data: data);
    }
  }

  void warning(String message, [Map<String, dynamic>? data]) {
    if (level.index <= LogLevel.warning.index) {
      _log(LogLevel.warning, message, data: data);
    }
  }

  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {
    if (level.index <= LogLevel.error.index) {
      _log(
        LogLevel.error,
        message,
        data: data,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _log(
    LogLevel logLevel,
    String message, {
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final levelName = logLevel.name.toUpperCase();
    final dataStr = data != null ? ' | ${data.toString()}' : '';
    developer.log(
      '[$levelName] $message$dataStr',
      name: namespace,
      time: DateTime.now(),
      level: logLevel.value,
      error: error,
      stackTrace: stackTrace,
    );
    // 同时输出到控制台，便于调试
    print('$timestamp [$namespace] [$levelName] $message$dataStr');
  }
}

/// 从堆栈跟踪中提取命名空间（文件路径）
String _extractNamespaceFromStackTrace(StackTrace stackTrace) {
  final lines = stackTrace.toString().split('\n');
  // 跳过 getLogger 和 _extractNamespaceFromStackTrace 本身的堆栈帧
  // 通常第三个堆栈帧是实际调用 getLogger 的位置
  for (int i = 0; i < lines.length && i < 5; i++) {
    final line = lines[i];
    // 跳过 logger.dart 本身
    if (line.contains('logger.dart')) {
      continue;
    }
    // 尝试提取文件路径
    final namespace = _parseStackFrame(line);
    if (namespace.isNotEmpty) {
      return namespace;
    }
  }
  return 'unknown';
}

/// 解析单个堆栈帧，提取文件路径
String _parseStackFrame(String frame) {
  // Dart 堆栈帧格式通常是：
  // #0      ClassName.methodName (package:package_name/path/to/file.dart:line:column)
  // 或
  // #0      methodName (file:///absolute/path/to/file.dart:line:column)
  // 提取 package: 或 file: 路径
  final packageMatch = RegExp(r'package:[\w_]+/(.+?\.dart)').firstMatch(frame);
  if (packageMatch != null) {
    return packageMatch.group(1)!.replaceAll('/', '.');
  }
  final fileMatch = RegExp(r'file:///.*?/(lib/.+?\.dart)').firstMatch(frame);
  if (fileMatch != null) {
    return fileMatch.group(1)!.replaceAll('/', '.');
  }
  // 尝试更宽松的匹配
  final looseMatch = RegExp(r'\((.+?\.dart):\d+:\d+\)').firstMatch(frame);
  if (looseMatch != null) {
    final path = looseMatch.group(1)!;
    // 提取文件名（去掉路径）
    final fileName = path.split('/').last.replaceAll('.dart', '');
    return fileName;
  }
  return '';
}
