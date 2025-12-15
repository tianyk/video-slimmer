import 'dart:io';

import 'package:live_activities/live_activities.dart';
import 'package:uuid/uuid.dart';

import '../libs/logger.dart';
import '../models/live_activity_data.dart';

final _logger = Logger.getLogger();

/// Live Activity 服务
///
/// 负责管理 iOS Live Activity 的生命周期，
/// 在压缩任务进行时显示灵动岛/锁屏进度。
///
/// 参考：https://pub.dev/packages/live_activities
class LiveActivityService {
  static const _appGroupId = 'group.cc.kekek.videoslimmer';
  static const _uuid = Uuid();

  // 延迟初始化，避免在模拟器上创建时崩溃
  LiveActivities? _liveActivities;
  String? _currentActivityId;
  String? _currentCustomId;
  bool _isInitialized = false;
  bool _initFailed = false; // 标记初始化是否失败

  /// 上次更新的数据快照，用于节流
  int? _lastProgress;
  int? _lastRemainingSeconds;
  String? _lastStatus;

  /// 初始化 Live Activity 服务
  Future<void> init() async {
    _logger.info('Live Activity init() 开始', {
      'platform': Platform.operatingSystem,
      'isIOS': Platform.isIOS,
      'isInitialized': _isInitialized,
    });

    if (!Platform.isIOS) {
      _logger.info('非 iOS 平台，跳过 Live Activity 初始化');
      return;
    }
    if (_isInitialized) {
      _logger.info('Live Activity 已初始化，跳过');
      return;
    }
    if (_initFailed) {
      _logger.info('Live Activity 之前初始化失败，跳过');
      return;
    }

    try {
      // 延迟创建 LiveActivities 对象
      _logger.info('正在创建 LiveActivities 对象...');
      _liveActivities = LiveActivities();

      _logger.info('正在调用 _liveActivities.init()', {
        'appGroupId': _appGroupId,
      });
      await _liveActivities!.init(appGroupId: _appGroupId);
      _isInitialized = true;
      _logger.info('Live Activity 服务初始化成功 ✅');

      // 检查是否支持
      final isEnabled = await _liveActivities!.areActivitiesEnabled();
      _logger.info('Live Activity 支持状态', {'isEnabled': isEnabled});
    } catch (e, stackTrace) {
      _initFailed = true;
      _liveActivities = null;
      _logger.warning('Live Activity 初始化失败 ❌', {
        'error': e.toString(),
        'stackTrace': stackTrace.toString(),
      });
    }
  }

  /// 开始 Live Activity
  Future<void> startActivity(LiveActivityData data) async {
    _logger.info('🚀 startActivity() 被调用', {
      'data': data.toMap(),
    });

    final isSupported = await _isSupported();
    _logger.info('Live Activity 支持检查结果', {'isSupported': isSupported});

    if (!isSupported) {
      _logger.warning('⚠️ Live Activity 不支持，跳过启动');
      return;
    }

    // 如果已有活动，先结束
    if (_currentActivityId != null) {
      _logger.info('已有活动，先结束', {'oldActivityId': _currentActivityId});
      await endActivity();
    }

    try {
      // 生成唯一的 customId，用于标识此 Activity
      _currentCustomId = _uuid.v4();

      _logger.info('正在调用 createActivity()', {
        'customId': _currentCustomId,
        'dataMap': data.toMap(),
      });

      // live_activities v2.x API: createActivity(String activityId, Map data, ...)
      _currentActivityId = await _liveActivities!.createActivity(
        _currentCustomId!,
        data.toMap(),
        removeWhenAppIsKilled: true,
      );

      // 重置节流快照
      _lastProgress = (data.progress * 100).toInt();
      _lastRemainingSeconds = data.remainingSeconds;
      _lastStatus = data.status;

      _logger.info('✅ Live Activity 已启动成功', {
        'activityId': _currentActivityId,
        'customId': _currentCustomId,
        'status': data.status,
      });
    } catch (e, stackTrace) {
      _logger.warning('❌ 启动 Live Activity 失败', {
        'error': e.toString(),
        'stackTrace': stackTrace.toString(),
      });
      _currentCustomId = null;
    }
  }

  /// 更新进度
  ///
  /// 使用节流机制，只有进度百分比、剩余时间或状态变化时才更新。
  Future<void> updateActivity(LiveActivityData data) async {
    if (_currentActivityId == null) return;

    // 节流：只有进度百分比、剩余时间或状态变化时才更新
    final newProgress = (data.progress * 100).toInt();
    if (newProgress == _lastProgress &&
        data.remainingSeconds == _lastRemainingSeconds &&
        data.status == _lastStatus) {
      return;
    }

    if (_liveActivities == null) return;

    try {
      await _liveActivities!.updateActivity(
        _currentActivityId!,
        data.toMap(),
      );

      // 更新快照
      _lastProgress = newProgress;
      _lastRemainingSeconds = data.remainingSeconds;
      _lastStatus = data.status;
    } catch (e) {
      _logger.warning('更新 Live Activity 失败', {'error': e.toString()});
    }
  }

  /// 结束 Live Activity
  Future<void> endActivity() async {
    if (_currentActivityId == null) return;
    if (_liveActivities == null) return;

    try {
      await _liveActivities!.endActivity(_currentActivityId!);
      _logger.info('Live Activity 已结束', {'activityId': _currentActivityId});
    } catch (e) {
      _logger.warning('结束 Live Activity 失败', {'error': e.toString()});
    } finally {
      _currentActivityId = null;
      _currentCustomId = null;
      _resetThrottleSnapshot();
    }
  }

  /// 结束所有 Live Activity
  Future<void> endAllActivities() async {
    if (_liveActivities == null) return;

    try {
      await _liveActivities!.endAllActivities();
      _logger.info('所有 Live Activity 已结束');
    } catch (e) {
      _logger.warning('结束所有 Live Activity 失败', {'error': e.toString()});
    } finally {
      _currentActivityId = null;
      _currentCustomId = null;
      _resetThrottleSnapshot();
    }
  }

  /// 检查是否支持 Live Activity
  Future<bool> _isSupported() async {
    _logger.info('_isSupported() 检查中...', {
      'isIOS': Platform.isIOS,
      'isInitialized': _isInitialized,
      'liveActivitiesNotNull': _liveActivities != null,
    });

    if (!Platform.isIOS) {
      _logger.info('非 iOS 平台，不支持');
      return false;
    }
    if (!_isInitialized || _liveActivities == null) {
      _logger.warning('⚠️ Live Activity 服务未初始化！');
      return false;
    }

    try {
      final enabled = await _liveActivities!.areActivitiesEnabled();
      _logger.info('areActivitiesEnabled() 返回', {'enabled': enabled});
      return enabled;
    } catch (e) {
      _logger.warning('检查 Live Activity 支持状态失败', {'error': e.toString()});
      return false;
    }
  }

  /// 重置节流快照
  void _resetThrottleSnapshot() {
    _lastProgress = null;
    _lastRemainingSeconds = null;
    _lastStatus = null;
  }

  /// 是否有活跃的 Activity
  bool get hasActiveActivity => _currentActivityId != null;
}
