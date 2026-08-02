import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// SafeAreaScaffold - 封装 SafeArea 处理刘海屏/异形屏
///
/// 自动处理 top/bottom 安全区，避免内容被状态栏、底部手势条遮挡。
/// 在 Scaffold 基础上对 body 内容统一加 SafeArea 包裹。
class SafeAreaScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;

  /// 是否启用顶部安全区
  final bool top;

  /// 是否启用底部安全区
  final bool bottom;

  const SafeAreaScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
    this.top = true,
    this.bottom = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor ?? AppTheme.bg,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: SafeArea(
        top: top,
        bottom: bottom,
        child: body,
      ),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );
  }
}

/// AdaptivePadding - 根据平台返回不同 padding
///
/// iOS：水平 16，垂直 12（符合 HIG 间距规范）
/// Android：水平 16，垂直 14（Material 间距略大）
/// 默认值可通过参数覆盖。
class AdaptivePadding extends StatelessWidget {
  final Widget child;
  final double horizontal;
  final double verticalIOS;
  final double verticalAndroid;
  final double verticalFallback;

  const AdaptivePadding({
    super.key,
    required this.child,
    this.horizontal = 16,
    this.verticalIOS = 12,
    this.verticalAndroid = 14,
    this.verticalFallback = 12,
  });

  @override
  Widget build(BuildContext context) {
    // Web 使用 fallback；移动端按 iOS/Android 规范
    double v;
    if (kIsWeb) {
      v = verticalFallback;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      v = verticalIOS;
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      v = verticalAndroid;
    } else {
      v = verticalFallback;
    }
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontal,
        vertical: v,
      ),
      child: child,
    );
  }
}
