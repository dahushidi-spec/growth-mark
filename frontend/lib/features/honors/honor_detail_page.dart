import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/providers/providers.dart';
import '../../models/honor.dart';
import '../../shared/widgets/loading_widget.dart';

/// 荣誉详情状态
class HonorDetailState {
  final Honor? honor;
  final bool isLoading;
  final bool hasError;

  const HonorDetailState({
    this.honor,
    this.isLoading = false,
    this.hasError = false,
  });

  HonorDetailState copyWith({
    Honor? honor,
    bool? isLoading,
    bool? hasError,
  }) {
    return HonorDetailState(
      honor: honor ?? this.honor,
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
    );
  }
}

/// 荣誉详情状态管理器
class HonorDetailNotifier extends StateNotifier<HonorDetailState> {
  final ApiClient _apiClient;

  HonorDetailNotifier(this._apiClient) : super(const HonorDetailState());

  /// 加载荣誉详情：调用 GET /honors/{id}
  Future<void> loadHonor(String honorId) async {
    state = state.copyWith(isLoading: true, hasError: false);

    try {
      final response =
          await _apiClient.get(ApiEndpoints.honorDetail(honorId));
      final body = response.data as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>? ?? const {};

      state = HonorDetailState(
        isLoading: false,
        honor: Honor.fromJson(data),
        hasError: false,
      );
    } catch (e) {
      // 加载失败时保持无荣誉状态
      state = state.copyWith(
        isLoading: false,
        hasError: true,
      );
    }
  }
}

final honorDetailProvider =
    StateNotifierProvider.family<HonorDetailNotifier, HonorDetailState, String>(
        (ref, honorId) {
  final apiClient = ref.watch(apiClientProvider);
  return HonorDetailNotifier(apiClient);
});

/// HonorDetailPage - 荣誉详情页
class HonorDetailPage extends ConsumerStatefulWidget {
  final String honorId;

  const HonorDetailPage({
    super.key,
    required this.honorId,
  });

  @override
  ConsumerState<HonorDetailPage> createState() => _HonorDetailPageState();
}

class _HonorDetailPageState extends ConsumerState<HonorDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(honorDetailProvider(widget.honorId).notifier)
          .loadHonor(widget.honorId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(honorDetailProvider(widget.honorId));

    // 监听加载失败，弹出 SnackBar 提示
    ref.listen<HonorDetailState>(honorDetailProvider(widget.honorId),
        (previous, next) {
      if (next.hasError && !(previous?.hasError ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('加载失败'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('荣誉详情'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: 分享荣誉
            },
          ),
        ],
      ),
      body: state.isLoading
          ? const LoadingWidget(text: '加载中...')
          : state.honor == null
              ? const Center(child: Text('荣誉不存在'))
              : _buildContent(state.honor!),
    );
  }

  Widget _buildContent(Honor honor) {
    final levelColor = _getLevelColor(honor.level);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 奖牌展示
          _buildMedalDisplay(honor, levelColor),
          const SizedBox(height: 24),
          // 荣誉信息卡片
          _buildInfoCard(honor, levelColor),
          const SizedBox(height: 24),
          // 获奖说明
          if (honor.description != null) _buildDescriptionCard(honor),
          const SizedBox(height: 32),
          // 操作按钮
          _buildActionButtons(),
        ],
      ),
    );
  }

  /// 奖牌展示
  Widget _buildMedalDisplay(Honor honor, Color levelColor) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  levelColor.withOpacity(0.3),
                  levelColor.withOpacity(0.1),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: levelColor.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Text(
                honor.level.emoji,
                style: const TextStyle(fontSize: 64),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            honor.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'NotoSansSC',
              color: AppTheme.ink,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: levelColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              honor.level.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: levelColor,
                fontFamily: 'NotoSansSC',
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 信息卡片
  Widget _buildInfoCard(Honor honor, Color levelColor) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow(
              Icons.category,
              '类别',
              honor.category ?? '未分类',
            ),
            const Divider(),
            _buildInfoRow(
              Icons.calendar_today,
              '获奖日期',
              honor.formattedAwardDate,
            ),
            const Divider(),
            _buildInfoRow(
              Icons.business,
              '颁发机构',
              honor.organization ?? '未知',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.muted),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.muted,
              fontFamily: 'NotoSansSC',
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: 'NotoSansSC',
              color: AppTheme.ink,
            ),
          ),
        ],
      ),
    );
  }

  /// 获奖说明卡片
  Widget _buildDescriptionCard(Honor honor) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, size: 20, color: AppTheme.accent),
                const SizedBox(width: 8),
                Text(
                  '获奖说明',
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
              honor.description!,
              style: const TextStyle(
                fontSize: 14,
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

  /// 操作按钮
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              // TODO: 编辑
            },
            icon: const Icon(Icons.edit),
            label: const Text('编辑'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              // TODO: 分享
            },
            icon: const Icon(Icons.share),
            label: const Text('分享'),
          ),
        ),
      ],
    );
  }

  Color _getLevelColor(HonorLevel level) {
    switch (level) {
      case HonorLevel.national:
        return const Color(0xFFD4AF37);
      case HonorLevel.provincial:
        return AppTheme.accent;
      case HonorLevel.municipal:
        return AppTheme.accent3;
      case HonorLevel.school:
        return AppTheme.accent2;
    }
  }
}
