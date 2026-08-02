import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/providers/providers.dart';
import '../../models/work.dart';
import '../../shared/widgets/lazy_image.dart';
import '../../shared/widgets/loading_widget.dart';
import '../share/share_sheet.dart';
import 'timeline_page.dart';

/// 作品详情状态
class WorkDetailState {
  final Work? work;
  final bool isLoading;
  final String? error;

  const WorkDetailState({
    this.work,
    this.isLoading = false,
    this.error,
  });

  WorkDetailState copyWith({
    Work? work,
    bool? isLoading,
    String? error,
  }) {
    return WorkDetailState(
      work: work ?? this.work,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 作品详情状态管理器
class WorkDetailNotifier extends StateNotifier<WorkDetailState> {
  final ApiClient _apiClient;

  WorkDetailNotifier(this._apiClient) : super(const WorkDetailState());

  /// 加载作品详情：调用 GET /works/{id}
  Future<void> loadWork(String workId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response =
          await _apiClient.get(ApiEndpoints.workDetail(workId));
      final body = response.data as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>? ?? const {};

      state = WorkDetailState(
        isLoading: false,
        work: Work.fromJson(data),
      );
    } catch (e) {
      // 加载失败时设置 error 状态
      state = state.copyWith(
        isLoading: false,
        error: '加载失败：$e',
      );
    }
  }
}

final workDetailProvider =
    StateNotifierProvider.family<WorkDetailNotifier, WorkDetailState, String>(
        (ref, workId) {
  final apiClient = ref.watch(apiClientProvider);
  return WorkDetailNotifier(apiClient);
});

/// WorkDetailPage - 作品详情页
class WorkDetailPage extends ConsumerStatefulWidget {
  final String workId;

  const WorkDetailPage({
    super.key,
    required this.workId,
  });

  @override
  ConsumerState<WorkDetailPage> createState() => _WorkDetailPageState();
}

class _WorkDetailPageState extends ConsumerState<WorkDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(workDetailProvider(widget.workId).notifier).loadWork(widget.workId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workDetailProvider(widget.workId));

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('作品详情'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          // 分享入口：弹出 ShareSheet（作品未加载时禁用）
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: '分享',
            onPressed: state.work == null
                ? null
                : () => _openShareSheet(state.work!),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () => _showMoreMenu(context),
          ),
        ],
      ),
      body: state.isLoading
          ? const LoadingWidget(text: '加载中...')
          : state.work == null
              ? const Center(child: Text('作品不存在'))
              : _buildContent(state.work!),
      bottomNavigationBar: state.work == null
          ? null
          : _buildBottomBar(state.work!),
    );
  }

  /// 内容区域
  Widget _buildContent(Work work) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 大图展示
          _buildBigImage(work),
          // 作品信息
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                Text(
                  work.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'NotoSansSC',
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 12),
                // 日期、年龄、分类
                _buildMetaInfo(work),
                const SizedBox(height: 20),
                // 创作故事
                if (work.description != null) _buildStoryCard(work),
                const SizedBox(height: 20),
                // 标签
                if (work.tags.isNotEmpty) _buildTags(work.tags),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 大图展示（F16：使用 LazyImage 实现懒加载与渐入）
  Widget _buildBigImage(Work work) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        color: AppTheme.bg2,
        child: LazyImage(
          imageUrl: work.imageUrl,
          fallbackEmoji: work.category.emoji,
          borderRadius: 0,
          fit: BoxFit.cover,
          fadeIn: true,
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(WorkCategory category) {
    return Center(
      child: Text(
        category.emoji,
        style: const TextStyle(fontSize: 80),
      ),
    );
  }

  /// 元信息
  Widget _buildMetaInfo(Work work) {
    final categoryColor = AppTheme.getCategoryColor(work.category.label);
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        // 分类标签
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: categoryColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${work.category.emoji} ${work.category.label}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: categoryColor,
              fontFamily: 'NotoSansSC',
            ),
          ),
        ),
        // 日期
        _buildMetaItem(Icons.calendar_today, work.formattedDate),
        // 年龄
        _buildMetaItem(Icons.cake, work.childAge),
      ],
    );
  }

  Widget _buildMetaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.muted),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.muted,
            fontFamily: 'NotoSansSC',
          ),
        ),
      ],
    );
  }

  /// 创作故事卡片
  Widget _buildStoryCard(Work work) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_stories, size: 20, color: AppTheme.accent),
                const SizedBox(width: 8),
                Text(
                  '创作故事',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'NotoSansSC',
                    color: AppTheme.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              work.description!,
              style: const TextStyle(
                fontSize: 15,
                fontFamily: 'NotoSansSC',
                color: AppTheme.ink,
                height: 1.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 标签
  Widget _buildTags(List<String> tags) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.bg2,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '#$tag',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.muted,
              fontFamily: 'NotoSansSC',
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 底部操作栏
  Widget _buildBottomBar(Work work) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // 点赞
            _buildActionButton(
              icon: Icons.favorite_outline,
              count: work.likeCount,
              onTap: () {},
            ),
            const SizedBox(width: 16),
            // 评论
            _buildActionButton(
              icon: Icons.chat_bubble_outline,
              count: work.commentCount,
              onTap: () {},
            ),
            const Spacer(),
            // 编辑
            OutlinedButton.icon(
              onPressed: () {
                // TODO: 编辑作品
              },
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('编辑'),
            ),
            const SizedBox(width: 12),
            // 分享：弹出 ShareSheet
            ElevatedButton.icon(
              onPressed: () => _openShareSheet(work),
              icon: const Icon(Icons.share, size: 18),
              label: const Text('分享'),
            ),
          ],
        ),
      ),
    );
  }

  /// 打开分享面板
  void _openShareSheet(Work work) {
    ShareSheet.show(context, work);
  }

  Widget _buildActionButton({
    required IconData icon,
    required int count,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppTheme.muted),
          const SizedBox(width: 4),
          Text(
          '$count',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.muted,
              fontFamily: 'NotoSansSC',
            ),
          ),
        ],
      ),
    );
  }

  /// 更多菜单
  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('编辑作品'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('保存到相册'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: AppTheme.errorRed),
                title: const Text('删除作品',
                    style: TextStyle(color: AppTheme.errorRed)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// 确认删除
  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: const Text('确定要删除这个作品吗？删除后不可恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _deleteWork();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorRed,
              ),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  /// 调用 DELETE /works/{id} 删除作品，成功后刷新时间线并跳转
  Future<void> _deleteWork() async {
    final work = ref.read(workDetailProvider(widget.workId)).work;
    if (work == null) return;
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.delete(ApiEndpoints.workDetail(work.id));
      // 刷新时间线，确保跳转后展示最新列表
      ref.invalidate(timelineProvider);
      if (!mounted) return;
      context.go('/main/timeline');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('删除失败：$e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }
}
