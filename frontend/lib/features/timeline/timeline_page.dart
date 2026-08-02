import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/providers/providers.dart';
import '../../core/storage/local_storage.dart';
import '../../core/storage/offline_cache.dart';
import '../../models/work.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/lazy_image.dart';
import '../../shared/widgets/loading_widget.dart';
import '../../shared/widgets/micro_animations.dart';

/// 时间线筛选标签
final _filterProvider = StateProvider<String>((ref) => '全部');

/// 时间线页面状态
class TimelineState {
  final List<Work> works;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int currentPage;
  final String? error;

  /// 是否处于离线模式（使用缓存数据）
  final bool isOffline;

  const TimelineState({
    this.works = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.currentPage = 1,
    this.error,
    this.isOffline = false,
  });

  TimelineState copyWith({
    List<Work>? works,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? currentPage,
    String? error,
    bool? isOffline,
  }) {
    return TimelineState(
      works: works ?? this.works,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: error,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

/// 时间线状态管理器
class TimelineNotifier extends StateNotifier<TimelineState> {
  final ApiClient _apiClient;
  final OfflineCacheService _cache;
  final LocalStorage _localStorage;

  TimelineNotifier(this._apiClient, this._cache, this._localStorage)
      : super(const TimelineState());

  /// 获取当前孩子 ID（用于缓存键）
  Future<String> _getChildId() async {
    final id = await _localStorage.getCurrentChildId();
    return id ?? 'default';
  }

  /// 加载作品列表
  Future<void> loadWorks({bool isRefresh = false, String? category}) async {
    if (isRefresh) {
      state = state.copyWith(isLoading: true, works: [], currentPage: 1);
    } else {
      state = state.copyWith(isLoadingMore: true);
    }

    try {
      final queryParams = <String, dynamic>{
        'page': state.currentPage,
        'size': AppConstants.pageSize,
      };
      // "全部" 不传 category，其他分类传中文标签
      if (category != null && category != '全部' && category != '荣誉') {
        queryParams['category'] = category;
      }

      final response = await _apiClient.get(
        ApiEndpoints.worksTimeline,
        queryParameters: queryParams,
      );

      final body = response.data as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>)
          .map((e) => Work.fromJson(e as Map<String, dynamic>))
          .toList();
      final total = data['total'] as int? ?? 0;

      final newWorks =
          isRefresh ? items : [...state.works, ...items];

      state = state.copyWith(
        works: newWorks,
        isLoading: false,
        isLoadingMore: false,
        hasMore: newWorks.length < total,
        currentPage: state.currentPage + 1,
        isOffline: false,
      );

      // 网络成功后写入缓存
      try {
        final childId = await _getChildId();
        final rawItems =
            newWorks.map((w) => w.toJson()).toList();
        await _cache.cacheTimeline(rawItems, childId);
      } catch (_) {}
    } catch (e) {
      // 网络失败，降级读取缓存
      try {
        final childId = await _getChildId();
        final cachedRaw = await _cache.getTimeline(childId);
        if (cachedRaw.isNotEmpty) {
          final cachedWorks = cachedRaw
              .map((m) => Work.fromJson(m as Map<String, dynamic>))
              .toList();
          state = state.copyWith(
            works: cachedWorks,
            isLoading: false,
            isLoadingMore: false,
            hasMore: false,
            isOffline: true,
            error: null,
          );
          return;
        }
      } catch (_) {}

      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        hasMore: false,
        error: '加载失败：$e',
        isOffline: true,
      );
    }
  }
}

final timelineProvider =
    StateNotifierProvider<TimelineNotifier, TimelineState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final cache = ref.watch(offlineCacheServiceProvider);
  final localStorage = ref.watch(localStorageProvider);
  return TimelineNotifier(apiClient, cache, localStorage);
});

/// TimelinePage - 成长时间线页面（首页）
class TimelinePage extends ConsumerStatefulWidget {
  const TimelinePage({super.key});

  @override
  ConsumerState<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends ConsumerState<TimelinePage> {
  final ScrollController _scrollController = ScrollController();
  final List<String> _filters = ['全部', ...AppConstants.workCategories, '荣誉'];

  @override
  void initState() {
    super.initState();
    // 初始加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(timelineProvider.notifier).loadWorks(isRefresh: true);
    });
    // 滚动监听 - 上拉加载更多
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final state = ref.read(timelineProvider);
      if (!state.isLoadingMore && state.hasMore && !state.isOffline) {
        ref.read(timelineProvider.notifier).loadWorks();
      }
    }
  }

  /// 下拉刷新
  Future<void> _onRefresh() async {
    await ref.read(timelineProvider.notifier).loadWorks(isRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(timelineProvider);
    final currentFilter = ref.watch(_filterProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('成长时间线'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: 跳转搜索页面
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: 跳转通知页面
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 离线提示条
          if (state.isOffline) _buildOfflineBanner(),
          // 横向筛选标签栏
          _buildFilterBar(currentFilter),
          // 列表区域
          Expanded(
            child: state.isLoading
                ? const LoadingWidget(text: '加载中...')
                : (state.error != null && state.works.isEmpty)
                    ? EmptyState(
                        icon: Icons.error_outline,
                        iconColor: AppTheme.errorRed,
                        title: '加载失败',
                        description: state.error,
                        actionText: '重试',
                        onAction: _onRefresh,
                      )
                    : state.works.isEmpty
                        ? EmptyState(
                            emoji: '🌱',
                            title: '还没有成长记录',
                            description: '点击中间的+按钮，\n记录宝贝的第一个成长瞬间吧！',
                            actionText: '去上传',
                            onAction: () => context.go('/main/upload'),
                          )
                        : RefreshIndicator(
                        onRefresh: _onRefresh,
                        color: AppTheme.accent,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount:
                              state.works.length + (state.hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == state.works.length) {
                              return const InlineLoadingWidget();
                            }
                            return _buildWorkCard(state.works[index], index);
                          },
                        ),
                      ),
          ),
        ],
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
            onTap: _onRefresh,
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

  /// 横向筛选标签栏
  Widget _buildFilterBar(String currentFilter) {
    return Container(
      height: 48,
      color: AppTheme.bg,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = filter == currentFilter;
          return Padding(
            padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            child: GestureDetector(
              onTap: () {
                ref.read(_filterProvider.notifier).state = filter;
                ref
                    .read(timelineProvider.notifier)
                    .loadWorks(isRefresh: true, category: filter);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.accent : AppTheme.bg2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppTheme.accent : AppTheme.rule,
                  ),
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'NotoSansSC',
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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

  /// 构建作品卡片（F16：FadeInItem + TapScaleEffect + Semantics）
  Widget _buildWorkCard(Work work, int index) {
    return FadeInItem(
      index: index,
      child: TapScaleEffect(
        onTap: () => context.push('/work-detail/${work.id}'),
        child: Semantics(
          label: '作品 ${work.title}，分类 ${work.category.label}，'
              '${work.formattedDate}，${work.childAge}',
          button: true,
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 作品图片（F16：LazyImage）
                  _buildWorkImage(work),
                  const SizedBox(width: 12),
                  // 作品信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 标题
                        Text(
                          work.title,
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
                        // 分类标签
                        _buildCategoryTag(work.category),
                        const SizedBox(height: 8),
                        // 日期和年龄
                        Row(
                          children: [
                            Icon(Icons.calendar_today,
                                size: 12, color: AppTheme.muted),
                            const SizedBox(width: 4),
                            Text(
                              work.formattedDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.muted,
                                fontFamily: 'NotoSansSC',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.cake, size: 12, color: AppTheme.muted),
                            const SizedBox(width: 4),
                            Text(
                              work.childAge,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.muted,
                                fontFamily: 'NotoSansSC',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // 描述
                        if (work.description != null)
                          Text(
                            work.description!,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.muted,
                              fontFamily: 'NotoSansSC',
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 8),
                        // 互动数据
                        Row(
                          children: [
                            Icon(Icons.favorite_outline,
                                size: 14, color: AppTheme.muted),
                            const SizedBox(width: 4),
                            Text(
                              '${work.likeCount}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.muted,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(Icons.chat_bubble_outline,
                                size: 14, color: AppTheme.muted),
                            const SizedBox(width: 4),
                            Text(
                              '${work.commentCount}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.muted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 作品图片（使用 LazyImage 替换 CachedNetworkImage）
  Widget _buildWorkImage(Work work) {
    return LazyImage(
      imageUrl: work.imageUrl,
      fallbackEmoji: work.category.emoji,
      borderRadius: 12,
      width: 100,
      height: 100,
    );
  }

  /// 分类标签
  Widget _buildCategoryTag(WorkCategory category) {
    final color = AppTheme.getCategoryColor(category.label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${category.emoji} ${category.label}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
          fontFamily: 'NotoSansSC',
        ),
      ),
    );
  }
}
