import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/providers/providers.dart';
import '../../core/storage/offline_cache.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading_widget.dart';

/// 成长报告类型
enum ReportType { quarterly, yearly }

/// 成长报告模型
class GrowthReport {
  final String id;
  final String childId;
  final String period; // "2025" 或 "2025-Q1"
  final String content; // 报告正文
  final int workCount;
  final int honorCount;
  final DateTime generatedAt;

  GrowthReport({
    required this.id,
    required this.childId,
    required this.period,
    required this.content,
    required this.workCount,
    required this.honorCount,
    required this.generatedAt,
  });

  factory GrowthReport.fromJson(Map<String, dynamic> json) {
    return GrowthReport(
      id: (json['id'] ?? '').toString(),
      childId: (json['child_id'] ?? '').toString(),
      period: json['period'] as String? ?? '',
      content: json['content'] as String? ?? '',
      workCount: (json['work_count'] as num?)?.toInt() ?? 0,
      honorCount: (json['honor_count'] as num?)?.toInt() ?? 0,
      generatedAt: json['generated_at'] != null
          ? (DateTime.tryParse(json['generated_at'] as String) ??
              DateTime.now())
          : DateTime.now(),
    );
  }

  /// 序列化为 JSON（用于离线缓存）
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'child_id': childId,
      'period': period,
      'content': content,
      'work_count': workCount,
      'honor_count': honorCount,
      'generated_at': generatedAt.toIso8601String(),
    };
  }

  // 派生字段
  bool get isYearly => !period.contains('-Q');

  String get title => isYearly ? '$period年度成长报告' : '$period季度报告';

  /// 报告起始日期（按 period 解析）
  DateTime get startDate {
    final parts = period.split('-');
    final year = int.tryParse(parts.first) ?? DateTime.now().year;
    if (isYearly) return DateTime(year, 1, 1);
    final q = parts.length > 1
        ? (int.tryParse(parts[1].replaceAll('Q', '')) ?? 1)
        : 1;
    return DateTime(year, (q - 1) * 3 + 1, 1);
  }

  /// 报告结束日期（按 period 解析）
  DateTime get endDate {
    final parts = period.split('-');
    final year = int.tryParse(parts.first) ?? DateTime.now().year;
    if (isYearly) return DateTime(year, 12, 31);
    final q = parts.length > 1
        ? (int.tryParse(parts[1].replaceAll('Q', '')) ?? 1)
        : 1;
    final endMonth = q * 3;
    // 该月最后一天
    final lastDay = DateTime(year, endMonth + 1, 0).day;
    return DateTime(year, endMonth, lastDay);
  }
}

/// 成长故事状态
class StoryState {
  final List<GrowthReport> reports;
  final bool isLoading;
  final bool isGenerating;

  /// 是否离线模式
  final bool isOffline;

  const StoryState({
    this.reports = const [],
    this.isLoading = false,
    this.isGenerating = false,
    this.isOffline = false,
  });

  StoryState copyWith({
    List<GrowthReport>? reports,
    bool? isLoading,
    bool? isGenerating,
    bool? isOffline,
  }) {
    return StoryState(
      reports: reports ?? this.reports,
      isLoading: isLoading ?? this.isLoading,
      isGenerating: isGenerating ?? this.isGenerating,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

/// 成长故事状态管理器
class StoryNotifier extends StateNotifier<StoryState> {
  final ApiClient _apiClient;
  final Ref _ref;
  final OfflineCacheService _cache;

  StoryNotifier(this._apiClient, this._ref, this._cache)
      : super(const StoryState());

  /// 获取当前孩子ID（优先当前孩子，其次第一个孩子）
  String? _getCurrentChildId() {
    final currentChild = _ref.read(currentChildProvider).child;
    if (currentChild != null) return currentChild.id;
    final children = _ref.read(childrenProvider).maybeWhen(
          data: (list) => list,
          orElse: () => const [],
        );
    if (children.isNotEmpty) return children.first.id;
    return null;
  }

  /// 加载报告列表
  Future<void> loadReports() async {
    state = state.copyWith(isLoading: true, isOffline: false);
    try {
      final queryParams = <String, dynamic>{
        'page': 1,
        'size': AppConstants.pageSize,
      };
      final childId = _getCurrentChildId();
      if (childId != null) {
        queryParams['child_id'] = int.tryParse(childId) ?? childId;
      }

      final response = await _apiClient.get(
        ApiEndpoints.reports,
        queryParameters: queryParams,
      );
      final body = response.data as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>? ?? [])
          .map((e) => GrowthReport.fromJson(e as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        reports: items,
        isLoading: false,
        isOffline: false,
      );

      // 网络成功后写入缓存
      try {
        final rawItems = items.map((r) => r.toJson()).toList();
        await _cache.cacheReports(rawItems);
      } catch (_) {}
    } catch (e) {
      // 网络失败，降级读取缓存
      try {
        final cachedRaw = await _cache.getReports();
        if (cachedRaw.isNotEmpty) {
          final cachedReports = cachedRaw
              .map((m) => GrowthReport.fromJson(m as Map<String, dynamic>))
              .toList();
          state = state.copyWith(
            reports: cachedReports,
            isLoading: false,
            isOffline: true,
          );
          return;
        }
      } catch (_) {}

      // 错误时返回空列表
      state = state.copyWith(reports: const [], isLoading: false, isOffline: true);
    }
  }

  /// 生成报告
  /// 返回 null 表示成功，返回字符串表示错误信息
  Future<String?> generateReport(ReportType type) async {
    final childIdStr = _getCurrentChildId();
    if (childIdStr == null) {
      return '请先创建孩子档案';
    }
    final childId = int.tryParse(childIdStr) ?? 0;

    state = state.copyWith(isGenerating: true);
    try {
      final now = DateTime.now();
      final body = <String, dynamic>{
        'child_id': childId,
        'period': type == ReportType.yearly ? 'yearly' : 'quarterly',
        'year': now.year,
      };
      if (type == ReportType.quarterly) {
        body['quarter'] = (now.month - 1) ~/ 3 + 1;
      }

      final response = await _apiClient.post(
        ApiEndpoints.reportsGenerate,
        data: body,
      );
      final respBody = response.data as Map<String, dynamic>;
      final data = respBody['data'] as Map<String, dynamic>;
      final newReport = GrowthReport.fromJson(data);

      state = state.copyWith(
        reports: [newReport, ...state.reports],
        isGenerating: false,
      );
      return null;
    } catch (e) {
      state = state.copyWith(isGenerating: false);
      return '生成失败，请稍后重试';
    }
  }

  /// 删除报告
  /// 返回 null 表示成功，返回字符串表示错误信息
  Future<String?> deleteReport(String id) async {
    try {
      await _apiClient.delete(ApiEndpoints.reportDetail(id));
      state = state.copyWith(
        reports: state.reports.where((r) => r.id != id).toList(),
      );
      return null;
    } catch (e) {
      return '删除失败，请稍后重试';
    }
  }
}

final storyProvider =
    StateNotifierProvider<StoryNotifier, StoryState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final cache = ref.watch(offlineCacheServiceProvider);
  return StoryNotifier(apiClient, ref, cache);
});

/// StoryPage - 成长故事页面
class StoryPage extends ConsumerStatefulWidget {
  const StoryPage({super.key});

  @override
  ConsumerState<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends ConsumerState<StoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(storyProvider.notifier).loadReports();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(storyProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('成长故事'),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 离线提示条
              if (state.isOffline) _buildOfflineBanner(),
              Expanded(
                child: state.isLoading
                    ? const LoadingWidget(text: '加载中...')
                    : state.reports.isEmpty
                        ? EmptyState(
                            emoji: '📖',
                            title: '还没有成长报告',
                            description: '点击下方按钮，\n生成宝贝的成长报告吧！',
                            actionText: '生成报告',
                            onAction: () => _showGenerateDialog(),
                          )
                        : RefreshIndicator(
                            onRefresh: () =>
                                ref.read(storyProvider.notifier).loadReports(),
                            color: AppTheme.accent,
                            child: ListView.builder(
                              padding: const EdgeInsets.only(bottom: 80),
                              itemCount: state.reports.length,
                              itemBuilder: (context, index) {
                                return _buildReportCard(state.reports[index]);
                              },
                            ),
                          ),
              ),
            ],
          ),
          // 生成中遮罩
          if (state.isGenerating)
            const LoadingWidget.aiRecognizing(text: '正在生成成长报告...'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showGenerateDialog,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('生成报告'),
      ),
    );
  }

  /// 离线模式提示条
  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.warningYellow.withOpacity(0.15),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 16, color: AppTheme.warningYellow),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '离线模式 - 显示缓存数据',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'NotoSansSC',
                color: AppTheme.ink,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => ref.read(storyProvider.notifier).loadReports(),
            child: Text(
              '重试',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'NotoSansSC',
                fontWeight: FontWeight.w600,
                color: AppTheme.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 报告卡片
  Widget _buildReportCard(GrowthReport report) {
    final isYearly = report.isYearly;
    final gradientColors = isYearly
        ? [AppTheme.accent3, AppTheme.accent]
        : [AppTheme.accent2, AppTheme.accent3];

    return Dismissible(
      key: ValueKey('report_${report.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) => _confirmDelete(report),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // TODO: 查看报告详情
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 头部
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: gradientColors,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isYearly ? Icons.calendar_view_day : Icons.date_range,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'NotoSansSC',
                              color: AppTheme.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_formatDate(report.startDate)} - ${_formatDate(report.endDate)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.muted,
                              fontFamily: 'NotoSansSC',
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 类型标签
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isYearly
                                ? AppTheme.accent3
                                : AppTheme.accent2)
                            .withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isYearly ? '年度' : '季度',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isYearly ? AppTheme.accent3 : AppTheme.accent2,
                          fontFamily: 'NotoSansSC',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 统计数据
                Row(
                  children: [
                    _buildReportStat('作品', '${report.workCount}件'),
                    Container(
                        width: 1,
                        height: 24,
                        color: AppTheme.rule,
                        margin: const EdgeInsets.symmetric(horizontal: 16)),
                    _buildReportStat('荣誉', '${report.honorCount}项'),
                  ],
                ),
                const SizedBox(height: 12),
                // 报告正文
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.bg2,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    report.content,
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'NotoSansSC',
                      color: AppTheme.ink,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 确认删除报告
  Future<bool> _confirmDelete(GrowthReport report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除报告',
            style: TextStyle(fontFamily: 'NotoSansSC')),
        content: Text(
          '确定要删除「${report.title}」吗？',
          style: const TextStyle(fontFamily: 'NotoSansSC'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    final error =
        await ref.read(storyProvider.notifier).deleteReport(report.id);
    if (error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false; // 取消删除，恢复原位
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('报告已删除'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return false; // 由状态更新驱动列表移除，不使用 Dismissible 自身移除
  }

  Widget _buildReportStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'NotoSansSC',
            color: AppTheme.accent,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.muted,
            fontFamily: 'NotoSansSC',
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month}.${date.day}';
  }

  /// 生成报告对话框
  void _showGenerateDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '生成成长报告',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'NotoSansSC',
                    color: AppTheme.ink,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // 季度报告
                _buildGenerateOption(
                  icon: Icons.date_range,
                  title: '季度报告',
                  description: '生成最近一个季度的成长报告',
                  onTap: () => _onGenerate(ReportType.quarterly),
                ),
                const SizedBox(height: 12),
                // 年度报告
                _buildGenerateOption(
                  icon: Icons.calendar_view_day,
                  title: '年度报告',
                  description: '生成全年的成长报告',
                  onTap: () => _onGenerate(ReportType.yearly),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 执行生成报告
  Future<void> _onGenerate(ReportType type) async {
    Navigator.pop(context); // 关闭底部弹窗
    final error = await ref.read(storyProvider.notifier).generateReport(type);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildGenerateOption({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bg2,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'NotoSansSC',
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.muted,
                      fontFamily: 'NotoSansSC',
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.muted),
          ],
        ),
      ),
    );
  }
}
