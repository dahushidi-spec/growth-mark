import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/honors/honors_page.dart';
import '../../features/story/story_page.dart';
import '../../features/timeline/timeline_page.dart';
import '../network/api_client.dart';
import '../network/connectivity_service.dart';
import '../network/upload_queue.dart';
import '../providers/providers.dart';

/// SyncState - 同步控制器状态
class SyncState {
  /// 是否在线
  final bool isOnline;

  /// 是否正在同步队列
  final bool isSyncing;

  /// 上一次同步完成时间
  final DateTime? lastSyncedAt;

  /// 队列中待上传任务数
  final int pendingCount;

  const SyncState({
    this.isOnline = true,
    this.isSyncing = false,
    this.lastSyncedAt,
    this.pendingCount = 0,
  });

  SyncState copyWith({
    bool? isOnline,
    bool? isSyncing,
    DateTime? lastSyncedAt,
    int? pendingCount,
  }) {
    return SyncState(
      isOnline: isOnline ?? this.isOnline,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pendingCount: pendingCount ?? this.pendingCount,
    );
  }
}

/// SyncController - 离线/在线同步控制器
///
/// 监听 ConnectivityService.onConnectivityChanged：
/// - 从离线变在线时：自动调用 UploadQueueService.processQueue 重试上传
/// - 上传完成后刷新时间线/荣誉 Provider
class SyncController extends StateNotifier<SyncState> {
  final ConnectivityService _connectivity;
  final UploadQueueService _uploadQueue;
  final ApiClient _apiClient;
  final Ref _ref;

  StreamSubscription<bool>? _connectivitySub;
  bool _initialized = false;

  SyncController(
    this._connectivity,
    this._uploadQueue,
    this._apiClient,
    this._ref,
  ) : super(const SyncState());

  /// 初始化：启动监听
  void init() {
    if (_initialized) return;
    _initialized = true;
    _refreshPendingCount();

    _connectivitySub = _connectivity.onConnectivityChanged.listen((online) {
      final wasOffline = !state.isOnline;
      state = state.copyWith(isOnline: online);

      if (online && wasOffline) {
        // 从离线变在线，触发同步
        _syncOnReconnect();
      }
    });
  }

  /// 刷新队列中待处理任务数
  Future<void> _refreshPendingCount() async {
    try {
      final pending = await _uploadQueue.getPending();
      if (mounted) {
        state = state.copyWith(pendingCount: pending.length);
      }
    } catch (_) {}
  }

  /// 网络恢复后执行同步
  Future<void> _syncOnReconnect() async {
    await _processQueueInternal();
    await _refreshProviders();
    await _refreshPendingCount();
  }

  /// 处理上传队列（内部）
  Future<void> _processQueueInternal() async {
    if (state.isSyncing) return;
    state = state.copyWith(isSyncing: true);
    try {
      await _uploadQueue.processQueue(_apiClient);
      if (mounted) {
        state = state.copyWith(
          isSyncing: false,
          lastSyncedAt: DateTime.now(),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔄 [SyncController] 同步失败: $e');
      }
      if (mounted) {
        state = state.copyWith(isSyncing: false);
      }
    }
  }

  /// 刷新相关 Provider：时间线、荣誉、故事
  Future<void> _refreshProviders() async {
    try {
      // 通过 invalidate 触发相关 Provider 重新加载
      _ref.invalidate(timelineProvider);
      _ref.invalidate(honorsProvider);
      _ref.invalidate(storyProvider);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔄 [SyncController] 刷新 Provider 失败: $e');
      }
    }
  }

  /// 手动触发同步（用户下拉刷新或点击重试时调用）
  Future<void> syncNow() async {
    await _processQueueInternal();
    await _refreshProviders();
    await _refreshPendingCount();
  }

  /// 入队任务后刷新 pendingCount
  Future<void> notifyEnqueued() async {
    await _refreshPendingCount();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
    super.dispose();
  }
}

/// 同步控制器 Provider
final syncControllerProvider =
    StateNotifierProvider<SyncController, SyncState>((ref) {
  final connectivity = ref.watch(connectivityServiceProvider);
  final uploadQueue = ref.watch(uploadQueueServiceProvider);
  final apiClient = ref.watch(apiClientProvider);
  final controller =
      SyncController(connectivity, uploadQueue, apiClient, ref);
  controller.init();
  return controller;
});

/// timeline/honors/story Provider 由各 feature 文件定义，
/// 上方 import 已引入，便于 _refreshProviders 中 invalidate 触发重新加载。
