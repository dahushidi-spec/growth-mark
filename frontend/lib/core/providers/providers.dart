import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../storage/local_storage.dart';

/// ========== 基础提供者 ==========

/// ApiClient提供者 - 单例
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient.instance;
});

/// LocalStorage提供者 - 单例
final localStorageProvider = Provider<LocalStorage>((ref) {
  return LocalStorage.instance;
});

/// ========== 认证状态管理 ==========

/// 认证状态数据类
class AuthState {
  final bool isLoggedIn;
  final User? user;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.isLoggedIn = false,
    this.user,
    this.isLoading = false,
    this.errorMessage,
  });

  factory AuthState.initial() => const AuthState();

  AuthState copyWith({
    bool? isLoggedIn,
    User? user,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// 认证状态管理器
class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;
  final LocalStorage _localStorage;

  AuthNotifier(this._apiClient, this._localStorage) : super(AuthState.initial()) {
    _initAuth();
  }

  /// 初始化认证状态
  Future<void> _initAuth() async {
    final isLoggedIn = await _localStorage.isLoggedIn();
    if (isLoggedIn) {
      final userId = await _localStorage.getUserId();
      // 实际项目中应从API获取用户信息
      state = state.copyWith(
        isLoggedIn: true,
        user: User(
          id: userId ?? '',
          phone: '',
          nickname: '成长记录者',
          avatarUrl: null,
        ),
      );
    }
  }

  /// 登录
  Future<bool> login(String phone, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _apiClient.post(
        '/auth/login',
        data: {'phone': phone, 'password': password},
      );

      final data = response.data['data'] as Map<String, dynamic>;
      await _localStorage.saveToken(data['access_token'] as String);
      await _localStorage.saveRefreshToken(data['refresh_token'] as String);
      await _localStorage.saveUserId(data['user']['id'].toString());

      state = AuthState(
        isLoggedIn: true,
        user: User.fromJson(data['user'] as Map<String, dynamic>),
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _extractErrorMessage(e),
      );
      return false;
    }
  }

  /// 注册：调用 /auth/register，成功后自动登录
  Future<bool> register({
    required String phone,
    required String verificationCode,
    required String password,
    required String nickname,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _apiClient.post(
        '/auth/register',
        data: {
          'phone': phone,
          'verification_code': verificationCode,
          'password': password,
          'nickname': nickname,
        },
      );

      final data = response.data['data'] as Map<String, dynamic>;
      await _localStorage.saveToken(data['access_token'] as String);
      await _localStorage.saveRefreshToken(data['refresh_token'] as String);
      await _localStorage.saveUserId(data['user']['id'].toString());

      state = AuthState(
        isLoggedIn: true,
        user: User.fromJson(data['user'] as Map<String, dynamic>),
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _extractErrorMessage(e),
      );
      return false;
    }
  }

  /// 从异常中提取可读错误信息（DioException 优先取响应消息）
  String _extractErrorMessage(Object e) {
    if (e is Exception) {
      final msg = e.toString();
      // 剥离 "Exception:" / "DioException:" 等前缀
      final colonIdx = msg.indexOf(':');
      if (colonIdx > 0 && colonIdx < 20) {
        final rest = msg.substring(colonIdx + 1).trim();
        if (rest.isNotEmpty) return rest;
      }
      return msg;
    }
    return e.toString();
  }

  /// 退出登录
  Future<void> logout() async {
    try {
      await _apiClient.post('/auth/logout');
    } catch (_) {
      // 忽略网络错误，本地清除登录状态
    }
    await _localStorage.clearAuth();
    state = AuthState.initial();
  }

  /// 更新用户信息
  void updateUser(User user) {
    state = state.copyWith(user: user);
  }
}

/// 认证提供者
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final localStorage = ref.watch(localStorageProvider);
  return AuthNotifier(apiClient, localStorage);
});

/// ========== 当前孩子管理 ==========

/// 当前孩子状态数据类
class CurrentChildState {
  final Child? child;
  final bool isLoading;

  const CurrentChildState({
    this.child,
    this.isLoading = false,
  });

  factory CurrentChildState.initial() => const CurrentChildState();

  CurrentChildState copyWith({
    Child? child,
    bool? isLoading,
  }) {
    return CurrentChildState(
      child: child ?? this.child,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 当前孩子状态管理器
class CurrentChildNotifier extends StateNotifier<CurrentChildState> {
  final ApiClient _apiClient;
  final LocalStorage _localStorage;

  CurrentChildNotifier(this._apiClient, this._localStorage)
      : super(CurrentChildState.initial()) {
    _initChild();
  }

  /// 初始化当前孩子
  Future<void> _initChild() async {
    final childId = await _localStorage.getCurrentChildId();
    if (childId != null) {
      // 实际项目中应从API获取孩子信息
      state = state.copyWith(
        child: Child(
          id: childId,
          userId: '',
          name: '宝贝',
          gender: 1,
          birthDate: DateTime(2020, 1, 1),
          avatarUrl: null,
        ),
      );
    }
  }

  /// 切换当前孩子
  Future<void> switchChild(Child child) async {
    await _localStorage.saveCurrentChildId(child.id);
    state = state.copyWith(child: child);
  }
}

/// 当前孩子提供者
final currentChildProvider =
    StateNotifierProvider<CurrentChildNotifier, CurrentChildState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final localStorage = ref.watch(localStorageProvider);
  return CurrentChildNotifier(apiClient, localStorage);
});

/// ========== 孩子档案列表 ==========

/// 孩子列表 FutureProvider
/// 用于上传页/个人中心加载当前用户的所有孩子档案
final childrenProvider =
    FutureProvider<List<Child>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  try {
    final response = await apiClient.get(ApiEndpoints.children);
    final body = response.data as Map<String, dynamic>;
    final list = body['data'] as List<dynamic>;
    return list
        .map((e) => Child.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (e) {
    // 后端未启动或未登录时返回空列表
    return [];
  }
});
