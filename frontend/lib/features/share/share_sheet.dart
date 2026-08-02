import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/providers/providers.dart';
import '../../models/work.dart';
import 'share_preview_page.dart';

/// ShareSheet - 底部弹出分享面板
/// 提供四个分享渠道：家庭群分享、朋友圈、生成卡片、复制链接
class ShareSheet extends ConsumerStatefulWidget {
  /// 待分享的作品
  final Work work;

  const ShareSheet({
    super.key,
    required this.work,
  });

  /// 便捷方法：以 BottomSheet 形式弹出
  static Future<void> show(BuildContext context, Work work) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ShareSheet(work: work),
    );
  }

  @override
  ConsumerState<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<ShareSheet> {
  /// 是否正在生成链接
  bool _isGeneratingLink = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部拖动指示器
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.rule,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 标题
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '分享到',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'NotoSansSC',
                  color: AppTheme.ink,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // 四个分享渠道
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildShareOption(
                    icon: Icons.group,
                    label: '家庭群',
                    color: AppTheme.accent3,
                    onTap: _shareToFamilyGroup,
                  ),
                  _buildShareOption(
                    icon: Icons.camera_alt_outlined,
                    label: '朋友圈',
                    color: AppTheme.accent2,
                    onTap: _shareToMoments,
                  ),
                  _buildShareOption(
                    icon: Icons.dashboard_customize,
                    label: '生成卡片',
                    color: AppTheme.accent,
                    onTap: _openCardPreview,
                  ),
                  _buildShareOption(
                    icon: Icons.link,
                    label: '复制链接',
                    color: const Color(0xFF8E44AD),
                    onTap: _copyLink,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 取消按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.rule),
                  ),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'NotoSansSC',
                      color: AppTheme.muted,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  /// 单个分享渠道按钮
  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'NotoSansSC',
              color: AppTheme.ink,
            ),
          ),
        ],
      ),
    );
  }

  /// 分享到家庭群
  /// share_plus 未集成时，使用 Clipboard 占位
  Future<void> _shareToFamilyGroup() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    navigator.maybePop();
    final url = await _ensureShareUrl();
    final text = '看看 ${widget.work.title} 这件作品～ $url';
    await Clipboard.setData(ClipboardData(text: text));
    _showSnackBarWith('已复制到剪贴板，请前往家庭群粘贴', messenger: messenger);
  }

  /// 分享到朋友圈
  /// share_plus 未集成时，使用 Clipboard 占位
  Future<void> _shareToMoments() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    navigator.maybePop();
    final url = await _ensureShareUrl();
    final text = '记录宝贝成长的瞬间：${widget.work.title} $url';
    await Clipboard.setData(ClipboardData(text: text));
    _showSnackBarWith('已复制到剪贴板，请前往朋友圈粘贴', messenger: messenger);
  }

  /// 生成卡片：打开全屏预览页
  Future<void> _openCardPreview() async {
    final navigator = Navigator.of(context);
    await navigator.maybePop();
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => SharePreviewPage(work: widget.work),
      ),
    );
  }

  /// 复制链接
  /// 调用后端 POST /shares/card 创建分享，返回 share_url
  Future<void> _copyLink() async {
    if (_isGeneratingLink) return;
    setState(() => _isGeneratingLink = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final url = await _ensureShareUrl();
      if (url.isEmpty) {
        _showSnackBarWith('生成分享链接失败，请稍后重试',
            isError: true, messenger: messenger);
        return;
      }
      await Clipboard.setData(ClipboardData(text: url));
      navigator.maybePop();
      _showSnackBarWith('链接已复制', messenger: messenger);
    } finally {
      if (mounted) setState(() => _isGeneratingLink = false);
    }
  }

  /// 确保已生成分享链接，若未生成则调用后端创建
  /// 失败时返回空字符串
  Future<String> _ensureShareUrl() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final resp = await apiClient.post(
        ApiEndpoints.shareCard,
        data: {'work_id': widget.work.id},
      );
      final data = resp.data['data'] as Map<String, dynamic>?;
      return data?['share_url'] as String? ?? '';
    } catch (e) {
      debugPrint('生成分享链接失败: $e');
      return '';
    }
  }

  void _showSnackBarWith(
    String message, {
    bool isError = false,
    required ScaffoldMessengerState messenger,
  }) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorRed : AppTheme.successGreen,
      ),
    );
  }
}
