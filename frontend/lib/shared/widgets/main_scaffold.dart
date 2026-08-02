import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/network/sync_controller.dart';

/// MainScaffold - 主框架底部导航实现
/// 使用 StatefulShellRoute 实现底部5个Tab导航
/// 中间上传按钮采用凸起设计
///
/// F15: 监听 SyncController，离线时顶部显示离线提示条
class MainScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({
    super.key,
    required this.navigationShell,
  });

  /// 切换Tab
  void _onTabSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncControllerProvider);

    return Scaffold(
      body: Column(
        children: [
          // 离线提示条（F15）
          if (!syncState.isOnline) _buildOfflineBanner(context, ref, syncState),
          // 主内容区域
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  /// 离线提示条
  Widget _buildOfflineBanner(
      BuildContext context, WidgetRef ref, SyncState syncState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.warningYellow.withOpacity(0.2),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 16, color: AppTheme.warningYellow),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              syncState.pendingCount > 0
                  ? '离线模式 - ${syncState.pendingCount} 个任务待同步'
                  : '离线模式 - 网络恢复后自动同步',
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'NotoSansSC',
                color: AppTheme.ink,
              ),
            ),
          ),
          if (syncState.isSyncing)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
              ),
            )
          else
            GestureDetector(
              onTap: () => ref.read(syncControllerProvider.notifier).syncNow(),
              child: const Text(
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

  /// 构建底部导航栏 - 中间上传按钮凸起设计
  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTabItem(
                index: 0,
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: '时间线',
                emoji: '🏠',
              ),
              _buildTabItem(
                index: 1,
                icon: Icons.emoji_events_outlined,
                activeIcon: Icons.emoji_events,
                label: '荣誉墙',
                emoji: '🏆',
              ),
              _buildUploadButton(),
              _buildTabItem(
                index: 3,
                icon: Icons.menu_book_outlined,
                activeIcon: Icons.menu_book,
                label: '故事',
                emoji: '📖',
              ),
              _buildTabItem(
                index: 4,
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: '我的',
                emoji: '👤',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建普通Tab项
  Widget _buildTabItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String emoji,
  }) {
    final isSelected = navigationShell.currentIndex == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTabSelected(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 24,
              color: isSelected ? AppTheme.accent : AppTheme.muted,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'NotoSansSC',
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppTheme.accent : AppTheme.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建中间凸起的上传按钮
  Widget _buildUploadButton() {
    final isSelected = navigationShell.currentIndex == 2;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTabSelected(2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 凸起的圆形按钮
            Container(
              width: 56,
              height: 56,
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.accentLight, AppTheme.accent],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: Icon(
                Icons.add,
                size: 32,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: AppTheme.accentDark.withOpacity(0.3),
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
            Text(
              '上传',
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'NotoSansSC',
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppTheme.accent : AppTheme.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
