import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// LazyImage - 基于 CachedNetworkImage 的图片懒加载组件
///
/// 特性：
/// - 占位符：加载中显示 bg2 背景 + 小型 CircularProgressIndicator
/// - 错误图：加载失败显示 fallback（emoji 文本或默认图标）
/// - 渐入效果：图片加载完成后从透明渐入到不透明
/// - 圆角支持：通过 borderRadius 参数控制
class LazyImage extends StatefulWidget {
  /// 图片 URL（为空时显示 fallback）
  final String? imageUrl;

  /// 占位 emoji（与 fallbackEmoji 二选一）
  final String? fallbackEmoji;

  /// 自定义 fallback Widget
  final Widget? fallbackWidget;

  /// 圆角半径（默认 12）
  final double borderRadius;

  /// 宽度
  final double? width;

  /// 高度
  final double? height;

  /// BoxFit
  final BoxFit fit;

  /// 是否启用渐入效果
  final bool fadeIn;

  /// 渐入时长
  final Duration fadeInDuration;

  const LazyImage({
    super.key,
    required this.imageUrl,
    this.fallbackEmoji,
    this.fallbackWidget,
    this.borderRadius = 12,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fadeIn = true,
    this.fadeInDuration = const Duration(milliseconds: 300),
  });

  @override
  State<LazyImage> createState() => _LazyImageState();
}

class _LazyImageState extends State<LazyImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: widget.fadeInDuration,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(widget.borderRadius);

    Widget content;
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      content = _buildFallback();
    } else {
      content = CachedNetworkImage(
        imageUrl: widget.imageUrl!,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildFallback(),
        imageBuilder: widget.fadeIn
            ? (context, imageProvider) {
                if (!_loaded) {
                  _loaded = true;
                  _fadeController.forward();
                }
                return AnimatedBuilder(
                  animation: _fadeController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeController.value,
                      child: child,
                    );
                  },
                  child: Container(
                    width: widget.width,
                    height: widget.height,
                    decoration: BoxDecoration(
                      borderRadius: borderRadius,
                      image: DecorationImage(
                        image: imageProvider,
                        fit: widget.fit,
                      ),
                    ),
                  ),
                );
              }
            : null,
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: content,
      ),
    );
  }

  /// 加载中占位符
  Widget _buildPlaceholder() {
    return Container(
      color: AppTheme.bg2,
      width: widget.width,
      height: widget.height,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
          ),
        ),
      ),
    );
  }

  /// 错误/空 URL 占位图
  Widget _buildFallback() {
    if (widget.fallbackWidget != null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.fallbackWidget!,
      );
    }
    return Container(
      color: AppTheme.bg2,
      width: widget.width,
      height: widget.height,
      child: Center(
        child: Text(
          widget.fallbackEmoji ?? '🖼️',
          style: const TextStyle(fontSize: 36),
        ),
      ),
    );
  }
}
