import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../storage/local_storage.dart';
import 'mock_data.dart';

/// ApiClient - Dio网络请求单例封装
/// 负责配置Dio实例、拦截器（请求/响应/错误处理）、Token管理
class ApiClient {
  static ApiClient? _instance;
  late final Dio _dio;
  final LocalStorage _localStorage = LocalStorage.instance;

  // Token刷新锁，防止并发刷新
  bool _isRefreshing = false;
  final List<void Function(String)> _pendingRequests = [];

  ApiClient._() {
    // 初始化 Mock 开关
    MockData.useMock = AppConstants.useMockData;
    _dio = Dio(_baseOptions);
    _setupInterceptors();
  }

  /// 获取单例实例
  static ApiClient get instance {
    _instance ??= ApiClient._();
    return _instance!;
  }

  /// 获取Dio实例
  Dio get dio => _dio;

  /// 基础配置
  BaseOptions get _baseOptions => BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout:
            const Duration(milliseconds: AppConstants.connectTimeout),
        receiveTimeout:
            const Duration(milliseconds: AppConstants.receiveTimeout),
        sendTimeout: const Duration(milliseconds: AppConstants.sendTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        responseType: ResponseType.json,
      );

  /// 配置拦截器
  void _setupInterceptors() {
    // ===== 请求拦截器：附加JWT Token =====
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Mock 数据切换：命中则直接返回 Mock 响应
          if (MockData.useMock &&
              MockData.hasMock(options.method, options.path)) {
            final response = Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
            );
            MockData.tryMatch(options.method, options.path, response);
            if (kDebugMode) {
              debugPrint('🎭 [MOCK] ${options.method} ${options.path}');
            }
            handler.resolve(response);
            return;
          }

          // 从本地存储读取Token
          final token = await _localStorage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          // 添加当前孩子ID（如有）
          final childId = await _localStorage.getCurrentChildId();
          if (childId != null && childId.isNotEmpty) {
            options.headers['X-Child-Id'] = childId;
          }

          if (kDebugMode) {
            debugPrint('📤 [REQUEST] ${options.method} ${options.uri}');
            debugPrint('📤 [HEADERS] ${options.headers}');
            if (options.data != null) {
              debugPrint('📤 [DATA] ${options.data}');
            }
          }

          handler.next(options);
        },
      ),
    );

    // ===== 响应拦截器：统一处理响应和错误 =====
    _dio.interceptors.add(
      InterceptorsWrapper(
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint(
                '📥 [RESPONSE] ${response.statusCode} ${response.requestOptions.uri}');
          }

          // 统一处理业务错误码
          final data = response.data;
          if (data is Map<String, dynamic>) {
            final code = data['code'] as int?;
            if (code != null && code != 200) {
              handler.reject(
                DioException(
                  requestOptions: response.requestOptions,
                  response: response,
                  error: data['message'] ?? '请求失败',
                  type: DioExceptionType.badResponse,
                ),
              );
              return;
            }
          }

          handler.next(response);
        },
        onError: (error, handler) async {
          if (kDebugMode) {
            debugPrint('❌ [ERROR] ${error.type} ${error.message}');
          }

          // 处理401未授权 - 尝试刷新Token
          if (error.response?.statusCode == 401) {
            final refreshed = await _tryRefreshToken();
            if (refreshed) {
              // Token刷新成功，重试原请求
              final newToken = await _localStorage.getToken();
              error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
              try {
                final response = await _dio.fetch(error.requestOptions);
                handler.resolve(response);
                return;
              } catch (e) {
                handler.next(error);
                return;
              }
            } else {
              // Token刷新失败，清除登录状态，跳转登录页
              await _localStorage.clearAuth();
              _navigateToLogin();
              handler.next(error);
              return;
            }
          }

          handler.next(error);
        },
      ),
    );
  }

  /// 尝试刷新Token
  Future<bool> _tryRefreshToken() async {
    if (_isRefreshing) return false;
    _isRefreshing = true;

    try {
      final refreshToken = await _localStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        return false;
      }

      final response = await Dio(_baseOptions).post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        final newToken = response.data['data']['access_token'] as String;
        final newRefreshToken =
            response.data['data']['refresh_token'] as String;
        await _localStorage.saveToken(newToken);
        await _localStorage.saveRefreshToken(newRefreshToken);
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Token刷新失败: $e');
      }
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  /// 跳转登录页（通过全局路由）
  void _navigateToLogin() {
    // 在实际项目中，这里会通过路由管理器跳转
    // 例如：goRouter.go('/login');
    debugPrint('🔄 跳转登录页');
  }

  // ===== 便捷请求方法 =====

  /// GET请求
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// POST请求
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// PUT请求
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// DELETE请求
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// 上传文件
  Future<Response<T>> upload<T>(
    String path, {
    required FormData formData,
    Options? options,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) {
    return _dio.post<T>(
      path,
      data: formData,
      options: options,
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    );
  }

  /// 下载文件
  Future<Response> download(
    String urlPath,
    savePath, {
    ProgressCallback? onReceiveProgress,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    bool deleteOnError = true,
  }) {
    return _dio.download(
      urlPath,
      savePath,
      onReceiveProgress: onReceiveProgress,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      deleteOnError: deleteOnError,
    );
  }
}
