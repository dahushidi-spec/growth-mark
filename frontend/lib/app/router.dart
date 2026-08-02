import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_constants.dart';
import '../core/providers/providers.dart';
import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/honors/honors_page.dart';
import '../features/honors/honor_detail_page.dart';
import '../features/profile/family_page.dart';
import '../features/profile/profile_page.dart';
import '../features/profile/settings_page.dart';
import '../features/story/story_page.dart';
import '../features/timeline/timeline_page.dart';
import '../features/timeline/work_detail_page.dart';
import '../features/upload/upload_page.dart';
import '../shared/widgets/main_scaffold.dart';

/// 路由提供者 - 使用Riverpod管理GoRouter实例
final goRouterProvider = Provider<GoRouter>((ref) {
  // 监听认证状态
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/main/timeline',
    debugLogDiagnostics: true,

    // 路由重定向：未登录用户跳转到登录页
    redirect: (BuildContext context, GoRouterState state) {
      final isLoggedIn = authState.isLoggedIn;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      // 未登录且访问需要认证的页面 -> 跳转登录
      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }

      // 已登录但访问登录/注册页 -> 跳转首页
      if (isLoggedIn && isAuthRoute) {
        return '/main/timeline';
      }

      return null;
    },

    // 刷新监听：认证状态变化时重新评估路由
    refreshListenable: _AuthListenable(authState),

    routes: [
      // ===== 认证相关路由 =====
      GoRoute(
        path: '/login',
        name: AppConstants.routeLogin,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        name: AppConstants.routeRegister,
        builder: (context, state) => const RegisterPage(),
      ),

      // ===== 主导航（含5个Tab的ShellRoute）=====
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScaffold(navigationShell: navigationShell);
        },
        branches: [
          // Tab 1: 成长时间线
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/main/timeline',
                name: AppConstants.routeTimeline,
                builder: (context, state) => const TimelinePage(),
              ),
            ],
          ),
          // Tab 2: 荣誉墙
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/main/honors',
                name: AppConstants.routeHonors,
                builder: (context, state) => const HonorsPage(),
              ),
            ],
          ),
          // Tab 3: 上传（中间凸起按钮）
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/main/upload',
                name: AppConstants.routeUpload,
                builder: (context, state) => const UploadPage(),
              ),
            ],
          ),
          // Tab 4: 成长故事
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/main/story',
                name: AppConstants.routeStory,
                builder: (context, state) => const StoryPage(),
              ),
            ],
          ),
          // Tab 5: 我的
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/main/profile',
                name: AppConstants.routeProfile,
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),

      // ===== 详情页面 =====
      GoRoute(
        path: '/work-detail/:id',
        name: AppConstants.routeWorkDetail,
        builder: (context, state) => WorkDetailPage(
          workId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/honor-detail/:id',
        name: AppConstants.routeHonorDetail,
        builder: (context, state) => HonorDetailPage(
          honorId: state.pathParameters['id'] ?? '',
        ),
      ),

      // ===== 其他页面 =====
      GoRoute(
        path: '/family',
        name: AppConstants.routeFamily,
        builder: (context, state) => const FamilyPage(),
      ),
      GoRoute(
        path: '/settings',
        name: AppConstants.routeSettings,
        builder: (context, state) => const SettingsPage(),
      ),
    ],

    // 错误页面
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('页面未找到')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('页面不存在: ${state.error?.toString() ?? "未知错误"}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/main/timeline'),
              child: const Text('返回首页'),
            ),
          ],
        ),
      ),
    ),
  );
});

/// 认证状态监听器 - 用于触发路由刷新
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(AuthState authState) {
    _authState = authState;
  }

  AuthState _authState = AuthState.initial();

  void update(AuthState authState) {
    if (_authState.isLoggedIn != authState.isLoggedIn) {
      _authState = authState;
      notifyListeners();
    }
  }
}
