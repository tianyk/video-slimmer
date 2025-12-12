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
class LiveActivityService {
  static const _appGroupId = 'group.cc.kekek.videoslimmer';
  static const _uuid = Uuid();

  final LiveActivities _liveActivities = LiveActivities();
  String? _currentActivityId;
  String? _currentCustomId;
  bool _isInitialized = false;

  /// 上次更新的数据快照，用于节流
  int? _lastProgress;
  int? _lastRemainingSeconds;
  String? _lastStatus;

  /// 初始化 Live Activity 服务
  Future<void> init() async {
    if (!Platform.isIOS) return;
    if (_isInitialized) return;

    try {
      await _liveActivities.init(appGroupId: _appGroupId);
      _isInitialized = true;
      _logger.info('Live Activity 服务初始化成功');
    } catch (e) {
      _logger.warning('Live Activity 初始化失败', {'error': e.toString()});
    }
  }

  /// 开始 Live Activity
  Future<void> startActivity(LiveActivityData data) async {
    if (!await _isSupported()) return;

    // 如果已有活动，先结束
    if (_currentActivityId != null) {
      await endActivity();
    }

    try {
      // 生成唯一的 customId
      _currentCustomId = _uuid.v4();

      _currentActivityId = await _liveActivities.createActivity(
        _currentCustomId!,
        data.toMap(),
        removeWhenAppIsKilled: true,
      );

      // 重置节流快照
      _lastProgress = (data.progress * 100).toInt();
      _lastRemainingSeconds = data.remainingSeconds;
      _lastStatus = data.status;

      _logger.info('Live Activity 已启动', {
        'activityId': _currentActivityId,
        'customId': _currentCustomId,
        'status': data.status,
      });
    } catch (e) {
      _logger.warning('启动 Live Activity 失败', {'error': e.toString()});
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

    try {
      await _liveActivities.updateActivity(
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

    try {
      await _liveActivities.endActivity(_currentActivityId!);
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
    try {
      await _liveActivities.endAllActivities();
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
    if (!Platform.isIOS) return false;
    if (!_isInitialized) return false;

    try {
      return await _liveActivities.areActivitiesEnabled();
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
