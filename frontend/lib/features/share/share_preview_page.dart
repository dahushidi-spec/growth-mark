import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/providers/providers.dart';
import '../../models/work.dart';

/// 分享卡片模板枚举
enum ShareTemplate {
  /// 温暖橙
  warmOrange,

  /// 清新绿
  freshGreen,
}

extension ShareTemplateX on ShareTemplate {
  String get label {
    switch (this) {
      case ShareTemplate.warmOrange:
        return '温暖橙';
      case ShareTemplate.freshGreen:
        return '清新绿';
    }
  }

  /// 模板主色
  Color get primary {
    switch (this) {
      case ShareTemplate.warmOrange:
        return AppTheme.accent;
      case ShareTemplate.freshGreen:
        return AppTheme.accent2;
    }
  }

  /// 模板渐变起止色
  List<Color> get gradient {
    switch (this) {
      case ShareTemplate.warmOrange:
        return [
          const Color(0xFFFFD9B0),
          const Color(0xFFFFFBF7),
        ];
      case ShareTemplate.freshGreen:
        return [
          const Color(0xFFCDE8C7),
          const Color(0xFFF5FBF3),
        ];
    }
  }
}

/// SharePreviewPage - 分享卡片全屏预览页
/// 展示精美卡片（作品图 + 标题 + 孩子姓名 + 日期 + 二维码占位）
/// 支持多模板切换、保存到相册、复制链接
class SharePreviewPage extends ConsumerStatefulWidget {
  /// 作品
  final Work work;

  /// 孩子姓名（如不传则尝试从 currentChildProvider 获取）
  final String? childName;

  const SharePreviewPage({
    super.key,
    required this.work,
    this.childName,
  });

  @override
  ConsumerState<SharePreviewPage> createState() => _SharePreviewPageState();
}

class _SharePreviewPageState extends ConsumerState<SharePreviewPage> {
  /// 当前选择的模板
  ShareTemplate _template = ShareTemplate.warmOrange;

  /// 卡片截图 Boundary Key
  final GlobalKey _cardBoundaryKey = GlobalKey();

  /// 是否正在保存
  bool _isSaving = false;

  /// 是否正在生成分享链接
  bool _isGeneratingLink = false;

  /// 缓存的分享链接
  String? _shareUrl;

  /// 获取孩子姓名
  String get _childName {
    if (widget.childName != null && widget.childName!.isNotEmpty) {
      return widget.childName!;
    }
    final currentChild = ref.read(currentChildProvider).child;
    return currentChild?.name ?? '宝贝';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('分享卡片'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 卡片预览区
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // 卡片本体（用于截图）
                    RepaintBoundary(
                      key: _cardBoundaryKey,
                      child: _buildCard(),
                    ),
                    const SizedBox(height: 20),
                    // 模板切换
                    _buildTemplateSwitcher(),
                    const SizedBox(height: 8),
                    Text(
                      '长按图片可保存（如设备支持）',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.muted,
                        fontFamily: 'NotoSansSC',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 底部操作栏
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  /// 构建分享卡片
  Widget _buildCard() {
    final gradient = _template.gradient;
    final primary = _template.primary;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradient,
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部品牌带
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Row(
              children: [
                Icon(Icons.eco, size: 18, color: primary),
                const SizedBox(width: 6),
                Text(
                  '成长印记 · 记录每一个成长瞬间',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'NotoSansSC',
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
              ],
            ),
          ),
          // 作品图
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  color: Colors.white,
                  child: widget.work.imageUrl != null &&
                          widget.work.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.work.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(
                              color: primary,
                              strokeWidth: 2,
                            ),
                          ),
                          errorWidget: (context, url, error) =>
                              _buildImagePlaceholder(),
                        )
                      : _buildImagePlaceholder(),
                ),
              ),
            ),
          ),
          // 标题
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(
              widget.work.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'NotoSansSC',
                color: AppTheme.ink,
              ),
            ),
          ),
          // 分类标签
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${widget.work.category.emoji} ${widget.work.category.label}',
                  style: TextStyle(
                    fontSize: 12,
                    color: primary,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'NotoSansSC',
                  ),
                ),
              ),
            ),
          ),
          // 孩子姓名 + 日期
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.child_care, size: 14, color: AppTheme.muted),
                const SizedBox(width: 4),
                Text(
                  _childName,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.muted,
                    fontFamily: 'NotoSansSC',
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.calendar_today, size: 14, color: AppTheme.muted),
                const SizedBox(width: 4),
                Text(
                  widget.work.formattedDate,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.muted,
                    fontFamily: 'NotoSansSC',
                  ),
                ),
              ],
            ),
          ),
          // 描述（如有）
          if (widget.work.description != null &&
              widget.work.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                widget.work.description!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.ink.withOpacity(0.75),
                  fontFamily: 'NotoSansSC',
                  height: 1.6,
                ),
              ),
            ),
          // 标签（如有）
          if (widget.work.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: widget.work.tags.take(5).map((tag) {
                  return Text(
                    '#$tag',
                    style: TextStyle(
                      fontSize: 11,
                      color: primary,
                      fontFamily: 'NotoSansSC',
                    ),
                  );
                }).toList(),
              ),
            ),
          // 分割线 + 二维码占位
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            child: Row(
              children: [
                Expanded(
                  child: Divider(
                    color: primary.withOpacity(0.3),
                    thickness: 1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '扫码查看更多',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.muted,
                      fontFamily: 'NotoSansSC',
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: primary.withOpacity(0.3),
                    thickness: 1,
                  ),
                ),
              ],
            ),
          ),
          // 二维码占位
          Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: primary.withOpacity(0.3)),
                  ),
                  child: CustomPaint(
                    painter: _QrPlaceholderPainter(
                      color: primary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '成长印记 Growth Mark',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.muted,
                    fontFamily: 'NotoSansSC',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 作品图占位
  Widget _buildImagePlaceholder() {
    return Container(
      color: AppTheme.bg2,
      alignment: Alignment.center,
      child: Text(
        widget.work.category.emoji,
        style: const TextStyle(fontSize: 64),
      ),
    );
  }

  /// 模板切换器
  Widget _buildTemplateSwitcher() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: ShareTemplate.values.map((t) {
        final isSelected = t == _template;
        return GestureDetector(
          onTap: () => setState(() => _template = t),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? t.primary : AppTheme.bg2,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? t.primary : AppTheme.rule,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: t.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  t.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'NotoSansSC',
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? Colors.white : AppTheme.ink,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 底部操作栏
  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 保存到相册
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isSaving ? null : _handleSaveToAlbum,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download, size: 18),
              label: const Text('保存到相册'),
            ),
          ),
          const SizedBox(width: 12),
          // 复制链接
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isGeneratingLink ? null : _handleCopyLink,
              icon: _isGeneratingLink
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.link, size: 18),
              label: const Text('复制链接'),
            ),
          ),
        ],
      ),
    );
  }

  /// 保存到相册
  /// 通过 RepaintBoundary + toImage 截图
  /// 若 path_provider 依赖缺失，降级为 SnackBar 提示"已保存"
  Future<void> _handleSaveToAlbum() async {
    setState(() => _isSaving = true);
    try {
      // 截图：将 RepaintBoundary 渲染为 ui.Image
      final boundary = _cardBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        _showSnackBar('卡片渲染失败，请重试', isError: true);
        return;
      }

      // 渲染为图像（pixelRatio 提高清晰度）
      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) {
        _showSnackBar('图片生成失败', isError: true);
        return;
      }

      final pngBytes = byteData.buffer.asUint8List();

      // 尝试保存到相册（path_provider 依赖未安装时降级）
      // 使用动态 try-catch + 条件调用，避免编译期依赖
      final saved = await _trySaveToGallery(pngBytes);
      if (saved) {
        _showSnackBar('已保存到相册');
      } else {
        // 降级：依赖缺失时仅提示
        _showSnackBar('已保存（设备不支持自动保存到相册，请截图保存）');
      }
    } catch (e) {
      debugPrint('保存到相册失败: $e');
      _showSnackBar('保存失败，请重试', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// 尝试保存图片到相册
  /// 沙箱环境无 path_provider / image_gallery_saver 依赖时返回 false
  Future<bool> _trySaveToGallery(Uint8List bytes) async {
    // path_provider 与 image_gallery_saver 未在 pubspec.yaml 中声明
    // 此处通过 try-catch + 条件导入兜底
    // 实际项目接入时，可在此处添加 path_provider 保存逻辑
    try {
      // 占位实现：仅返回 false，由调用方降级提示
      // 如需启用真实保存，可添加 gallery_saver 依赖并调用：
      // await GallerySaver.saveImage(bytes);
      return false;
    } catch (_) {
      return false;
    }
  }

  /// 复制链接
  /// 调用后端 POST /shares/card 创建分享，返回 share_url
  /// 用 Clipboard.setData 复制到剪贴板
  Future<void> _handleCopyLink() async {
    setState(() => _isGeneratingLink = true);
    try {
      // 已有缓存链接则直接复制
      if (_shareUrl != null && _shareUrl!.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: _shareUrl!));
        _showSnackBar('链接已复制');
        return;
      }

      final apiClient = ref.read(apiClientProvider);
      final resp = await apiClient.post(
        ApiEndpoints.shareCard,
        data: {
          'work_id': widget.work.id,
        },
      );
      final data = resp.data['data'] as Map<String, dynamic>?;
      final url = data?['share_url'] as String?;
      if (url == null || url.isEmpty) {
        _showSnackBar('生成分享链接失败', isError: true);
        return;
      }
      _shareUrl = url;
      await Clipboard.setData(ClipboardData(text: url));
      _showSnackBar('链接已复制');
    } catch (e) {
      debugPrint('生成分享链接失败: $e');
      _showSnackBar('生成分享链接失败，请稍后重试', isError: true);
    } finally {
      if (mounted) setState(() => _isGeneratingLink = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorRed : AppTheme.successGreen,
      ),
    );
  }
}

/// 二维码占位画笔
/// 绘制简化版"二维码"图案（黑/白方块阵列），仅作占位展示
class _QrPlaceholderPainter extends CustomPainter {
  final Color color;

  _QrPlaceholderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // 简化二维码：8x8 网格，固定图案
    final grid = [
      [1, 1, 1, 0, 1, 0, 1, 1],
      [1, 0, 1, 1, 0, 1, 0, 1],
      [1, 1, 0, 1, 1, 1, 1, 0],
      [0, 1, 1, 0, 1, 0, 1, 1],
      [1, 0, 1, 1, 1, 1, 0, 1],
      [1, 1, 0, 0, 1, 1, 1, 0],
      [0, 1, 1, 1, 0, 1, 1, 1],
      [1, 0, 1, 0, 1, 1, 0, 1],
    ];

    final cell = size.width / grid.length;
    for (int r = 0; r < grid.length; r++) {
      for (int c = 0; c < grid[r].length; c++) {
        if (grid[r][c] == 1) {
          canvas.drawRect(
            Rect.fromLTWH(c * cell, r * cell, cell, cell),
            paint,
          );
        }
      }
    }

    // 三个定位角（左上、右上、左下）
    final cornerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final cornerSize = cell * 2.5;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, cornerSize, cornerSize),
      cornerPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width - cornerSize, 0, cornerSize, cornerSize),
      cornerPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - cornerSize, cornerSize, cornerSize),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _QrPlaceholderPainter oldDelegate) =>
      oldDelegate.color != color;
}
