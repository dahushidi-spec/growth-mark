import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/providers/providers.dart';
import '../../core/storage/offline_cache.dart';
import '../../models/honor.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading_widget.dart';
import '../../shared/widgets/micro_animations.dart';

/// 级别筛选Provider
final _levelFilterProvider = StateProvider<String>((ref) => '全部');

/// 荣誉墙状态
class HonorsState {
  final List<Honor> honors;
  final bool isLoading;
  final int totalCount;
  final int yearCount;
  final int aboveMunicipalCount;
  final bool hasError;

  /// 是否离线模式
  final bool isOffline;

  const HonorsState({
    this.honors = const [],
    this.isLoading = false,
    this.totalCount = 0,
    this.yearCount = 0,
    this.aboveMunicipalCount = 0,
    this.hasError = false,
    this.isOffline = false,
  });

  HonorsState copyWith({
    List<Honor>? honors,
    bool? isLoading,
    int? totalCount,
    int? yearCount,
    int? aboveMunicipalCount,
    bool? hasError,
    bool? isOffline,
  }) {
    return HonorsState(
      honors: honors ?? this.honors,
      isLoading: isLoading ?? this.isLoading,
      totalCount: totalCount ?? this.totalCount,
      yearCount: yearCount ?? this.yearCount,
      aboveMunicipalCount:
          aboveMunicipalCount ?? this.aboveMunicipalCount,
      hasError: hasError ?? this.hasError,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

/// 荣誉墙状态管理器
class HonorsNotifier extends StateNotifier<HonorsState> {
  final ApiClient _apiClient;
  final OfflineCacheService _cache;

  HonorsNotifier(this._apiClient, this._cache) : super(const HonorsState());

  /// 加载荣誉数据：并行获取统计和列表
  /// [level] 级别筛选，传中文值（国家级/省级/市级/校级），"全部"不传 level 参数
  Future<void> loadHonors({String level = '全部'}) async {
    state = state.copyWith(isLoading: true, hasError: false, isOffline: false);

    try {
      // 构建荣誉列表查询参数：分页 + 级别筛选
      final queryParams = <String, dynamic>{
        'page': AppConstants.defaultPage,
        'size': AppConstants.pageSize,
      };
      if (level != '全部') {
        queryParams['level'] = level;
      }

      // 并行调用统计接口和列表接口
      final results = await Future.wait([
        _apiClient.get(ApiEndpoints.honorsStats),
        _apiClient.get(ApiEndpoints.honors, queryParameters: queryParams),
      ]);

      // 解析统计数据：total / this_year / high_level
      final statsBody = results[0].data as Map<String, dynamic>;
      final statsData =
          statsBody['data'] as Map<String, dynamic>? ?? const {};
      final totalCount = statsData['total'] as int? ?? 0;
      final yearCount = statsData['this_year'] as int? ?? 0;
      final aboveMunicipalCount = statsData['high_level'] as int? ?? 0;

      // 解析荣誉列表
      final listBody = results[1].data as Map<String, dynamic>;
      final listData =
          listBody['data'] as Map<String, dynamic>? ?? const {};
      final items = (listData['items'] as List<dynamic>? ?? const [])
          .map((e) => Honor.fromJson(e as Map<String, dynamic>))
          .toList();

      state = HonorsState(
        honors: items,
        isLoading: false,
        totalCount: totalCount,
        yearCount: yearCount,
        aboveMunicipalCount: aboveMunicipalCount,
        hasError: false,
        isOffline: false,
      );

      // 网络成功后写入缓存
      try {
        final rawItems = items.map((h) => h.toJson()).toList();
        await _cache.cacheHonors(rawItems);
      } catch (_) {}
    } catch (e) {
      // 网络失败，降级读取缓存
      try {
        final cachedRaw = await _cache.getHonors();
        if (cachedRaw.isNotEmpty) {
          final cachedHonors = cachedRaw
              .map((m) => Honor.fromJson(m as Map<String, dynamic>))
              .toList();
          state = state.copyWith(
            honors: cachedHonors,
            isLoading: false,
            isOffline: true,
            hasError: false,
          );
          return;
        }
      } catch (_) {}

      // 错误时保持空状态，不崩溃
      state = state.copyWith(
        isLoading: false,
        hasError: true,
        isOffline: true,
      );
    }
  }
}

final honorsProvider =
    StateNotifierProvider<HonorsNotifier, HonorsState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final cache = ref.watch(offlineCacheServiceProvider);
  return HonorsNotifier(apiClient, cache);
});

/// HonorsPage - 荣誉墙页面
class HonorsPage extends ConsumerStatefulWidget {
  const HonorsPage({super.key});

  @override
  ConsumerState<HonorsPage> createState() => _HonorsPageState();
}

class _HonorsPageState extends ConsumerState<HonorsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(honorsProvider.notifier).loadHonors();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(honorsProvider);
    final currentLevel = ref.watch(_levelFilterProvider);

    // 监听加载失败，弹出 SnackBar 提示
    ref.listen<HonorsState>(honorsProvider, (previous, next) {
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
        title: const Text('荣誉墙'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              // TODO: 分享荣誉墙
            },
          ),
        ],
      ),
      body: state.isLoading
          ? const LoadingWidget(text: '加载中...')
          : RefreshIndicator(
              onRefresh: () => ref
                  .read(honorsProvider.notifier)
                  .loadHonors(level: currentLevel),
              color: AppTheme.accent,
              child: CustomScrollView(
                slivers: [
                  // 离线提示条
                  if (state.isOffline)
                    SliverToBoxAdapter(
                      child: _buildOfflineBanner(),
                    ),
                  // 统计概览卡片
                  SliverToBoxAdapter(
                    child: _buildStatsCard(state),
                  ),
                  // 级别筛选标签
                  SliverToBoxAdapter(
                    child: _buildLevelFilter(currentLevel),
                  ),
                  // 荣誉列表
                  if (state.honors.isEmpty)
                    const SliverFillRemaining(
                      child: EmptyState(
                        emoji: '🏆',
                        title: '还没有荣誉记录',
                        description: '快去上传宝贝的荣誉证书吧！',
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final honor = state.honors[index];
                          return _buildHonorCard(honor, index);
                        },
                        childCount: state.honors.length,
                      ),
                    ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 80),
                  ),
                ],
              ),
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
            onTap: () => ref
                .read(honorsProvider.notifier)
                .loadHonors(level: ref.read(_levelFilterProvider)),
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

  /// 统计概览卡片
  Widget _buildStatsCard(HonorsState state) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.accent, AppTheme.accentLight],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                '🏆',
                style: TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '宝贝的荣誉成就',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'NotoSansSC',
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStatItem('总荣誉', '${state.totalCount}'),
              _buildDivider(),
              _buildStatItem('本年度', '${state.yearCount}'),
              _buildDivider(),
              _buildStatItem('市级以上', '${state.aboveMunicipalCount}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              fontFamily: 'NotoSansSC',
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'NotoSansSC',
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 32,
      width: 1,
      color: Colors.white.withOpacity(0.3),
    );
  }

  /// 级别筛选标签
  Widget _buildLevelFilter(String currentLevel) {
    final levels = ['全部', ...AppConstants.honorLevels];
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: levels.length,
        itemBuilder: (context, index) {
          final level = levels[index];
          final isSelected = level == currentLevel;
          return Padding(
            padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            child: GestureDetector(
              onTap: () {
                ref.read(_levelFilterProvider.notifier).state = level;
                ref.read(honorsProvider.notifier).loadHonors(level: level);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.accent : AppTheme.bg2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppTheme.accent : AppTheme.rule,
                  ),
                ),
                child: Text(
                  level,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'NotoSansSC',
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? Colors.white : AppTheme.ink,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 荣誉卡片（F16：FadeInItem + 呼吸动效）
  Widget _buildHonorCard(Honor honor, int index) {
    final levelColor = _getLevelColor(honor.level);

    return FadeInItem(
      index: index,
      child: TapScaleEffect(
        onTap: () => context.push('/honor-detail/${honor.id}'),
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 奖牌图标（F16：呼吸动效）
                BreathingEffect(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: levelColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        honor.level.emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // 荣誉信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        honor.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'NotoSansSC',
                          color: AppTheme.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          // 级别标签
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: levelColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              honor.level.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: levelColor,
                                fontFamily: 'NotoSansSC',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 分类
                          if (honor.category != null)
                            Text(
                              honor.category!,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.muted,
                                fontFamily: 'NotoSansSC',
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // 日期和颁发机构
                      Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 12, color: AppTheme.muted),
                          const SizedBox(width: 4),
                          Text(
                            honor.formattedAwardDate,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.muted,
                              fontFamily: 'NotoSansSC',
                            ),
                          ),
                          if (honor.organization != null) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.business,
                                size: 12, color: AppTheme.muted),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                honor.organization!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.muted,
                                  fontFamily: 'NotoSansSC',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 获取级别对应颜色
  Color _getLevelColor(HonorLevel level) {
    switch (level) {
      case HonorLevel.national:
        return const Color(0xFFD4AF37); // 金色
      case HonorLevel.provincial:
        return const Color(0xFFE8833A); // 橙色
      case HonorLevel.municipal:
        return const Color(0xFF4A6FA5); // 蓝色
      case HonorLevel.school:
        return const Color(0xFF5B8C5A); // 绿色
    }
  }
}
