import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

/// ConnectivityService - 网络连接状态服务
///
/// 由于不能新增依赖（connectivity_plus 不在 pubspec），采用轮询策略：
/// 每 5 秒通过 ApiClient 访问 /health 端点，根据响应是否成功判断在线状态。
class ConnectivityService {
  static ConnectivityService? _instance;

  /// 单例实例
  static ConnectivityService get instance {
    _instance ??= ConnectivityService._();
    return _instance!;
  }

  ConnectivityService._();

  final ApiClient _apiClient = ApiClient.instance;

  /// 轮询间隔：5 秒
  static const Duration _pollInterval = Duration(seconds: 5);

  /// 健康检查端点（相对 baseUrl）
  static const String _healthPath = 'health';

  bool _isOnline = true; // 默认假设在线，首次轮询失败后修正
  bool _disposed = false;
  Timer? _timer;
  StreamController<bool>? _controller;

  /// 当前是否在线（同步值，最近一次轮询结果）
  bool get isOnlineSync => _isOnline;

  /// 当前是否在线（异步，方便外部 await）
  Future<bool> get isOnline async {
    // 若尚未启动轮询，立即探测一次
    if (_controller == null) {
      await _checkOnce();
    }
    return _isOnline;
  }

  /// 在线状态变化流
  Stream<bool> get onConnectivityChanged {
    _controller ??= StreamController<bool>.broadcast();
    _startPolling();
    return _controller!.stream;
  }

  /// 启动轮询
  void _startPolling() {
    if (_timer != null && _timer!.isActive) return;
    // 立即探测一次
    _checkOnce();
    _timer = Timer.periodic(_pollInterval, (_) => _checkOnce());
  }

  /// 单次健康检查
  Future<void> _checkOnce() async {
    if (_disposed) return;
    bool online = false;
    try {
      // 使用较短超时的健康检查请求
      final response = await _apiClient.get(
        _healthPath,
        options: Options(
          sendTimeout: const Duration(milliseconds: 3000),
          receiveTimeout: const Duration(milliseconds: 3000),
          extra: const {'skipAuth': true},
        ),
      );
      online = response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🌐 [Connectivity] 健康检查失败: $e');
      }
      online = false;
    }

    if (_isOnline != online) {
      _isOnline = online;
      _controller?.add(online);
    }
  }

  /// 手动触发一次检查
  Future<bool> checkNow() async {
    await _checkOnce();
    return _isOnline;
  }

  /// 释放资源
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _controller?.close();
    _controller = null;
  }
}

/// 连接服务 Provider
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService.instance;
  ref.onDispose(service.dispose);
  return service;
});

/// 在线状态 StreamProvider
final isOnlineProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.onConnectivityChanged;
});
