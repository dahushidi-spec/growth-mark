import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// SuccessCheckAnimation - 上传成功对勾动画
///
/// 对勾从短到长绘制 + 圆形背景淡入放大，配合完成态色彩反馈。
/// 默认动画时长 800ms，适合保存成功后短暂展示再跳转。
class SuccessCheckAnimation extends StatefulWidget {
  /// 动画总时长
  final Duration duration;

  /// 完成回调（动画结束时触发）
  final VoidCallback? onComplete;

  /// 对勾颜色
  final Color color;

  /// 背景遮罩透明度
  final double backgroundOpacity;

  const SuccessCheckAnimation({
    super.key,
    this.duration = const Duration(milliseconds: 800),
    this.onComplete,
    this.color = AppTheme.successGreen,
    this.backgroundOpacity = 0.4,
  });

  @override
  State<SuccessCheckAnimation> createState() => _SuccessCheckAnimationState();
}

class _SuccessCheckAnimationState extends State<SuccessCheckAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _circleScale;
  late final Animation<double> _circleFade;
  late final Animation<double> _checkProgress;
  late final Animation<double> _checkFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // 圆形背景：0~40% 放大并淡入
    _circleScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
      ),
    );
    _circleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
      ),
    );

    // 对勾：35%~85% 绘制路径，同步淡入
    _checkProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
      ),
    );
    _checkFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.55, curve: Curves.easeIn),
      ),
    );

    _controller.forward().then((_) {
      if (widget.onComplete != null) widget.onComplete!();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(widget.backgroundOpacity),
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Opacity(
              opacity: _circleFade.value,
              child: Transform.scale(
                scale: _circleScale.value,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withOpacity(0.4),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    painter: _CheckPainter(
                      progress: _checkProgress.value,
                      fade: _checkFade.value,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 对勾路径绘制画笔
class _CheckPainter extends CustomPainter {
  final double progress;
  final double fade;

  _CheckPainter({required this.progress, required this.fade});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(fade.clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 对勾三点坐标（基于 96x96 画布）
    const p1 = Offset(30, 50);
    const p2 = Offset(43, 63);
    const p3 = Offset(67, 35);

    if (progress <= 0) return;

    // 第一段：p1 -> p2，占总长度的 40%
    final seg1End = 0.4;
    if (progress <= seg1End) {
      final t = progress / seg1End;
      canvas.drawLine(p1, Offset.lerp(p1, p2, t)!, paint);
    } else {
      // 第一段完整绘制
      canvas.drawLine(p1, p2, paint);
      // 第二段：p2 -> p3，占总长度的 60%
      final t = (progress - seg1End) / (1.0 - seg1End);
      canvas.drawLine(p2, Offset.lerp(p2, p3, t)!, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.fade != fade;
}

/// PullRefreshHeader - 下拉刷新自定义头部
///
/// 状态切换：下拉刷新 / 释放刷新 / 加载中
class PullRefreshHeader extends StatelessWidget {
  /// 下拉进度（0~1，>1 表示已超过触发阈值）
  final double offset;

  /// 触发刷新的阈值
  final double threshold;

  /// 是否处于刷新中
  final bool isRefreshing;

  const PullRefreshHeader({
    super.key,
    required this.offset,
    this.threshold = 60,
    this.isRefreshing = false,
  });

  @override
  Widget build(BuildContext context) {
    final String text;
    final Widget indicator;
    if (isRefreshing) {
      text = '加载中';
      indicator = SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
        ),
      );
    } else if (offset >= threshold) {
      text = '释放刷新';
      indicator = Icon(Icons.arrow_upward, size: 18, color: AppTheme.accent);
    } else {
      text = '下拉刷新';
      indicator =
          Icon(Icons.arrow_downward, size: 18, color: AppTheme.muted);
    }

    return Container(
      height: isRefreshing ? threshold : offset.clamp(0.0, threshold),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          indicator,
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'NotoSansSC',
              color: isRefreshing ? AppTheme.accent : AppTheme.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// FadeInItem - 列表项淡入上移动效
///
/// 用于时间线/荣誉墙列表，子项首次构建时执行淡入 + 向上平移。
class FadeInItem extends StatefulWidget {
  final Widget child;

  /// 动画时长
  final Duration duration;

  /// 起始向上偏移量（正值表示从下方上移）
  final double offset;

  /// 错开延迟（用于列表连续动画）
  final int index;

  /// 单项最大延迟数（超过则不再延迟）
  final int maxStagger;

  const FadeInItem({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 350),
    this.offset = 16,
    this.index = 0,
    this.maxStagger = 8,
  });

  @override
  State<FadeInItem> createState() => _FadeInItemState();
}

class _FadeInItemState extends State<FadeInItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _slide = Tween<Offset>(
      begin: Offset(0, widget.offset / 100),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    // 错开延迟，每项 60ms，最多 maxStagger 项
    final delay = (widget.index.clamp(0, widget.maxStagger)) * 60;
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

/// TapScaleEffect - 点击缩放回弹效果
///
/// 用 GestureDetector 包裹子组件，按下时 scale=0.95，松开回到 1.0，
/// 适合卡片、按钮等可点击元素的触摸反馈。
class TapScaleEffect extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;

  /// 点击动画时长
  final Duration duration;

  const TapScaleEffect({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.95,
    this.duration = const Duration(milliseconds: 120),
  });

  @override
  State<TapScaleEffect> createState() => _TapScaleEffectState();
}

class _TapScaleEffectState extends State<TapScaleEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _scale = Tween<double>(begin: 1.0, end: widget.scaleDown).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// BreathingEffect - 轻微呼吸缩放动效
///
/// 用于荣誉墙奖牌图标等装饰元素，scale 1.0 -> 1.05 -> 1.0 循环。
class BreathingEffect extends StatefulWidget {
  final Widget child;

  /// 最大放大倍数
  final double maxScale;

  /// 单次呼吸时长
  final Duration duration;

  const BreathingEffect({
    super.key,
    required this.child,
    this.maxScale = 1.05,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<BreathingEffect> createState() => _BreathingEffectState();
}

class _BreathingEffectState extends State<BreathingEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: widget.maxScale).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) {
        return Transform.scale(
          scale: _scale.value,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
