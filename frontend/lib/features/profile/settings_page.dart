import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/constants/app_constants.dart';

/// SettingsPage - 设置页面
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('设置'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          // 账号设置
          _buildSectionTitle('账号设置'),
          _buildSettingsGroup([
            _SettingsItem(
              icon: Icons.person_outline,
              title: '修改昵称',
              onTap: () {},
            ),
            _SettingsItem(
              icon: Icons.lock_outline,
              title: '修改密码',
              onTap: () {},
            ),
            _SettingsItem(
              icon: Icons.phone_outlined,
              title: '更换手机号',
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 16),
          // 通用设置
          _buildSectionTitle('通用设置'),
          _buildSettingsGroup([
            _SettingsItem(
              icon: Icons.notifications_outlined,
              title: '通知设置',
              onTap: () {},
            ),
            _SettingsItem(
              icon: Icons.language,
              title: '语言',
              value: '简体中文',
              onTap: () {},
            ),
            _SettingsItem(
              icon: Icons.storage_outlined,
              title: '清除缓存',
              value: '0.0 MB',
              onTap: () async {
                // 清除缓存
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('缓存已清除')),
                );
              },
            ),
          ]),
          const SizedBox(height: 16),
          // 隐私
          _buildSectionTitle('隐私与安全'),
          _buildSettingsGroup([
            _SettingsItem(
              icon: Icons.privacy_tip_outlined,
              title: '隐私设置',
              onTap: () {},
            ),
            _SettingsItem(
              icon: Icons.security,
              title: '账号安全',
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 16),
          // 关于
          _buildSectionTitle('关于'),
          _buildSettingsGroup([
            _SettingsItem(
              icon: Icons.info_outline,
              title: '关于成长印记',
              value: 'v${AppConstants.appVersion}',
              onTap: () {},
            ),
            _SettingsItem(
              icon: Icons.description_outlined,
              title: '用户协议',
              onTap: () {},
            ),
            _SettingsItem(
              icon: Icons.policy_outlined,
              title: '隐私政策',
              onTap: () {},
            ),
            _SettingsItem(
              icon: Icons.star_outline,
              title: '给我们评分',
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// 分区标题
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontFamily: 'NotoSansSC',
          color: AppTheme.muted,
        ),
      ),
    );
  }

  /// 设置组
  Widget _buildSettingsGroup(List<_SettingsItem> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _buildSettingsItem(items[i]),
            if (i < items.length - 1)
              const Divider(height: 1, indent: 56),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsItem(_SettingsItem item) {
    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(item.icon, size: 22, color: AppTheme.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontFamily: 'NotoSansSC',
                  color: AppTheme.ink,
                ),
              ),
            ),
            if (item.value != null)
              Text(
                item.value!,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.muted,
                  fontFamily: 'NotoSansSC',
                ),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppTheme.muted, size: 20),
          ],
        ),
      ),
    );
  }
}

/// 设置项数据类
class _SettingsItem {
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback onTap;

  _SettingsItem({
    required this.icon,
    required this.title,
    this.value,
    required this.onTap,
  });
}
