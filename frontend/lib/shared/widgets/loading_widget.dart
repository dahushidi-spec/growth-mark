import 'dart:math' as math show sin, cos, pi;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// LoadingWidget - 加载指示器组件
/// 支持自定义文字和不同样式
class LoadingWidget extends StatelessWidget {
  /// 加载提示文字
  final String? text;

  /// 加载指示器大小
  final double size;

  /// 加载指示器颜色
  final Color? color;

  /// 是否使用全屏覆盖模式
  final bool fullscreen;

  /// 背景遮罩透明度（全屏模式有效）
  final double backgroundOpacity;

  const LoadingWidget({
    super.key,
    this.text,
    this.size = 32,
    this.color,
    this.fullscreen = false,
    this.backgroundOpacity = 0.3,
  });

  /// 全屏加载指示器
  const LoadingWidget.fullscreen({
    super.key,
    this.text = '加载中...',
    this.size = 40,
    this.color,
    this.backgroundOpacity = 0.3,
  })  : fullscreen = true;

  /// AI识别中加载指示器（成长树生长动效）
  /// 实际动效由 AiRecognizingLoading 组件渲染，这里返回占位 widget
  /// 由调用方在使用时直接使用 AiRecognizingLoading 替代
  const LoadingWidget.aiRecognizing({
    super.key,
    this.text = 'AI 正在识别作品...',
    this.size = 40,
    this.color,
    this.backgroundOpacity = 0.45,
  })  : fullscreen = true;

  @override
  Widget build(BuildContext context) {
    final loadingColor = color ?? AppTheme.accent;

    if (fullscreen) {
      return Container(
        color: Colors.black.withOpacity(backgroundOpacity),
        child: _buildLoadingContent(loadingColor, true),
      );
    }

    return _buildLoadingContent(loadingColor, false);
  }

  Widget _buildLoadingContent(Color loadingColor, bool isFullscreen) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: isFullscreen ? MainAxisSize.min : MainAxisSize.max,
        children: [
          // 加载指示器
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(loadingColor),
              backgroundColor: loadingColor.withOpacity(0.2),
            ),
          ),
          // 提示文字
          if (text != null) ...[
            const SizedBox(height: 16),
            Text(
              text!,
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'NotoSansSC',
                fontWeight: FontWeight.w500,
                color: isFullscreen ? Colors.white : AppTheme.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// AI识别专用 Loading 组件
/// 成长树生长动效：树苗从下方生长、淡入，配合旋转光晕与缩放，传递 AI 正在"孕育"识别结果的视觉隐喻
class AiRecognizingLoading extends StatefulWidget {
  /// 主提示文字
  final String text;

  /// 副提示文字
  final String? subtitle;

  /// 背景遮罩透明度
  final double backgroundOpacity;

  const AiRecognizingLoading({
    super.key,
    this.text = 'AI 正在识别作品...',
    this.subtitle = '正在为你的作品生成分类与标签',
    this.backgroundOpacity = 0.45,
  });

  @override
  State<AiRecognizingLoading> createState() => _AiRecognizingLoadingState();
}

class _AiRecognizingLoadingState extends State<AiRecognizingLoading>
    with TickerProviderStateMixin {
  late final AnimationController _growController;
  late final AnimationController _rotateController;
  late final AnimationController _pulseController;

  late final Animation<double> _growAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _rotateAnimation;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // 成长动画：树苗反复生长，时长 1400ms
    _growController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // 树苗生长曲线：先慢后快，营造破土向上感
    _growAnimation = CurvedAnimation(
      parent: _growController,
      curve: Curves.easeOutCubic,
    );
    _fadeAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _growController, curve: Curves.easeIn),
    );

    // 光晕旋转：持续顺时针旋转
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _rotateAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );

    // 脉冲缩放：底部光圈呼吸效果
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _growController.dispose();
    _rotateController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(widget.backgroundOpacity),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 成长树动效
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 底部脉冲光圈
                  Positioned(
                    bottom: 12,
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: child,
                        );
                      },
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.accent2.withOpacity(0.35),
                              AppTheme.accent.withOpacity(0.15),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 旋转光晕
                  AnimatedBuilder(
                    animation: _rotateAnimation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _rotateAnimation.value * 2 * math.pi,
                        child: child,
                      );
                    },
                    child: SizedBox(
                      width: 110,
                      height: 110,
                      child: CustomPaint(
                        painter: _HaloPainter(
                          color: AppTheme.accent.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ),
                  // 成长树（树苗+叶子）
                  AnimatedBuilder(
                    animation: Listenable.merge([_growAnimation, _fadeAnimation]),
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeAnimation.value,
                        child: Transform.translate(
                          offset: Offset(
                            0,
                            24 * (1 - _growAnimation.value),
                          ),
                          child: Transform.scale(
                            scale: 0.5 + 0.5 * _growAnimation.value,
                            alignment: Alignment.bottomCenter,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: const _GrowingTree(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // 主提示文字
            Text(
              widget.text,
              style: const TextStyle(
                fontSize: 15,
                fontFamily: 'NotoSansSC',
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                widget.subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'NotoSansSC',
                  color: Colors.white.withOpacity(0.75),
                ),
              ),
            ],
            const SizedBox(height: 18),
            // 进度小点动画
            const _DotsIndicator(),
          ],
        ),
      ),
    );
  }
}

/// 成长树图标：底部树干 + 顶部三层叶子（不同绿色），传递"成长"意象
class _GrowingTree extends StatelessWidget {
  const _GrowingTree();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: 80,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // 树干
          Positioned(
            bottom: 0,
            child: Container(
              width: 8,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5A2B),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          // 底层叶子（深绿，最大）
          Positioned(
            bottom: 22,
            child: Container(
              width: 56,
              height: 36,
              decoration: const BoxDecoration(
                color: AppTheme.accent2,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
            ),
          ),
          // 中层叶子（中绿）
          Positioned(
            bottom: 38,
            child: Container(
              width: 42,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF7CB342),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(21),
                  topRight: Radius.circular(21),
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent2.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          // 顶层叶子（浅绿，最小）
          Positioned(
            bottom: 56,
            child: Container(
              width: 28,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xFFAED581),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFAED581).withOpacity(0.4),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
          // 顶部小果实（橙色圆点）
          Positioned(
            bottom: 70,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppTheme.accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withOpacity(0.5),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 旋转光晕画笔：绘制半圆弧虚线，旋转产生扫描感
class _HaloPainter extends CustomPainter {
  final Color color;

  _HaloPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.width / 2 - 2;

    // 绘制两段相对的弧
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      1.2,
      false,
      paint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      1.2,
      false,
      paint,
    );

    // 内圈虚线点
    final dotPaint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 6; i++) {
      final angle = (i / 6) * 2 * math.pi;
      final dx = center.dx + (radius - 8) * math.cos(angle);
      final dy = center.dy + (radius - 8) * math.sin(angle);
      canvas.drawCircle(Offset(dx, dy), 1.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HaloPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 三个进度小点：依次淡入淡出
class _DotsIndicator extends StatefulWidget {
  const _DotsIndicator();

  @override
  State<_DotsIndicator> createState() => _DotsIndicatorState();
}

class _DotsIndicatorState extends State<_DotsIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            // 每个点错开 0.2 周期
            final t = (_controller.value - index * 0.2) % 1.0;
            // 用正弦曲线模拟明暗
            final opacity = 0.3 + 0.7 * (math.sin(t * math.pi).abs());
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(opacity.clamp(0.0, 1.0)),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

/// 内联加载指示器（用于列表底部加载更多）
class InlineLoadingWidget extends StatelessWidget {
  final String? text;

  const InlineLoadingWidget({
    super.key,
    this.text = '加载更多...',
  });

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
              ),
            ),
            SizedBox(width: 8),
            Text(
              '加载更多...',
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'NotoSansSC',
                color: AppTheme.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
