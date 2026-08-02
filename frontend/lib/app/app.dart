import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';

/// GrowthMarkApp - 成长印记应用根组件
/// 使用 MaterialApp.router 配合 go_router 进行路由管理
class GrowthMarkApp extends ConsumerWidget {
  const GrowthMarkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 获取路由配置
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: '成长印记',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      builder: (context, child) {
        // 全局文字缩放及媒体查询设置
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(1.0),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
