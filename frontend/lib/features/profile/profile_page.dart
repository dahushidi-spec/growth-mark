import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/providers/providers.dart';
import '../../models/user.dart';

/// ProfilePage - 个人中心页面
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final childState = ref.watch(currentChildProvider);
    final childrenAsync = ref.watch(childrenProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: CustomScrollView(
        slivers: [
          // 用户信息头部
          SliverToBoxAdapter(
            child: _buildUserHeader(context, user),
          ),
          // 孩子档案管理
          SliverToBoxAdapter(
            child: _buildChildrenSection(
              context,
              childrenAsync: childrenAsync,
              currentChild: childState.child,
            ),
          ),
          // 功能列表
          SliverToBoxAdapter(
            child: _buildFunctionList(context, ref),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    );
  }

  /// 用户信息头部
  Widget _buildUserHeader(BuildContext context, dynamic user) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.accent, AppTheme.accentLight],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // 头像和昵称
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.white, width: 3),
                  image: user?.avatarUrl != null
                      ? DecorationImage(
                          image: NetworkImage(user.avatarUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: user?.avatarUrl == null
                    ? const Icon(Icons.person, size: 36, color: AppTheme.accent)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.nickname ?? '成长记录者',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'NotoSansSC',
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.phone ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'NotoSansSC',
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () => _showEditNicknameDialog(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 统计信息（占位，后续可从额外 API 获取）
          Row(
            children: [
              _buildStatItem('记录数', '--'),
              _buildStatItem('荣誉数', '--'),
              _buildStatItem('存储量', '--'),
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
              fontSize: 20,
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

  /// 孩子档案管理
  Widget _buildChildrenSection(
    BuildContext context, {
    required AsyncValue<List<Child>> childrenAsync,
    required Child? currentChild,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '孩子档案',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'NotoSansSC',
                  color: AppTheme.ink,
                ),
              ),
              GestureDetector(
                onTap: () => _showChildEditDialog(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 16, color: AppTheme.accent),
                      const SizedBox(width: 4),
                      Text(
                        '添加',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.accent,
                          fontFamily: 'NotoSansSC',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 孩子列表
          childrenAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(
                  color: AppTheme.accent,
                  strokeWidth: 2,
                ),
              ),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  '加载失败，请下拉重试',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.muted,
                    fontFamily: 'NotoSansSC',
                  ),
                ),
              ),
            ),
            data: (children) {
              if (children.isEmpty) {
                return _buildEmptyChildren();
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (int i = 0; i < children.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      _buildChildAvatar(
                        child: children[i],
                        isSelected:
                            currentChild?.id == children[i].id,
                        onTap: () => _switchChild(children[i]),
                        onLongPress: () =>
                            _showChildActionSheet(children[i]),
                      ),
                    ],
                    const SizedBox(width: 12),
                    _buildAddChildButton(),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 空孩子档案占位
  Widget _buildEmptyChildren() {
    return Row(
      children: [
        _buildAddChildButton(),
        const SizedBox(width: 12),
        Text(
          '还没有孩子档案，点击添加',
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.muted,
            fontFamily: 'NotoSansSC',
          ),
        ),
      ],
    );
  }

  Widget _buildChildAvatar({
    required Child child,
    bool isSelected = false,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent.withOpacity(0.08) : AppTheme.bg2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.bg2,
                image: child.avatarUrl != null
                    ? DecorationImage(
                        image: NetworkImage(child.avatarUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: child.avatarUrl == null
                  ? const Icon(Icons.child_care, color: AppTheme.accent)
                  : null,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  child.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'NotoSansSC',
                    color: AppTheme.ink,
                  ),
                ),
                Text(
                  child.ageString,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.muted,
                    fontFamily: 'NotoSansSC',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddChildButton() {
    return GestureDetector(
      onTap: () => _showChildEditDialog(),
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: AppTheme.bg2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.rule,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: AppTheme.muted),
            Text(
              '添加',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.muted,
                fontFamily: 'NotoSansSC',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 功能列表
  Widget _buildFunctionList(BuildContext context, WidgetRef ref) {
    final items = [
      _MenuItem(
        icon: Icons.family_restroom,
        iconColor: AppTheme.accent3,
        title: '家庭空间',
        subtitle: '邀请家人一起记录',
        onTap: () => context.push('/family'),
      ),
      _MenuItem(
        icon: Icons.workspace_premium,
        iconColor: AppTheme.accent,
        title: '会员中心',
        subtitle: '解锁更多功能',
        onTap: () {
          // TODO: 会员页面
        },
      ),
      _MenuItem(
        icon: Icons.privacy_tip_outlined,
        iconColor: AppTheme.accent2,
        title: '隐私设置',
        subtitle: '管理隐私权限',
        onTap: () {
          // TODO: 隐私设置
        },
      ),
      _MenuItem(
        icon: Icons.settings_outlined,
        iconColor: AppTheme.muted,
        title: '设置',
        subtitle: '应用设置',
        onTap: () => context.push('/settings'),
      ),
      _MenuItem(
        icon: Icons.info_outline,
        iconColor: AppTheme.accent3,
        title: '关于',
        subtitle: '关于成长印记',
        onTap: () {
          // TODO: 关于页面
        },
      ),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ...items.map((item) => _buildMenuItem(item)),
          // 退出登录
          const Divider(height: 1),
          _buildLogoutButton(context, ref),
        ],
      ),
    );
  }

  Widget _buildMenuItem(_MenuItem item) {
    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: item.iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, color: item.iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'NotoSansSC',
                      color: AppTheme.ink,
                    ),
                  ),
                  if (item.subtitle != null)
                    Text(
                      item.subtitle!,
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

  Widget _buildLogoutButton(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => _showLogoutDialog(context, ref),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, color: AppTheme.errorRed, size: 20),
            SizedBox(width: 8),
            Text(
              '退出登录',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                fontFamily: 'NotoSansSC',
                color: AppTheme.errorRed,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== 业务逻辑 =====

  /// 显示 SnackBar 提示
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorRed : AppTheme.accent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 编辑昵称对话框
  void _showEditNicknameDialog() {
    final user = ref.read(authProvider).user;
    final controller = TextEditingController(text: user?.nickname ?? '');
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('编辑昵称'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '请输入昵称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nickname = controller.text.trim();
              if (nickname.isEmpty) {
                _showSnackBar('昵称不能为空', isError: true);
                return;
              }
              Navigator.pop(dialogContext);
              await _updateUserNickname(nickname);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  /// 调用 PUT /users/me 更新昵称
  Future<void> _updateUserNickname(String nickname) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.put(
        'users/me',
        data: {'nickname': nickname},
      );
      final body = response.data as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>;
      final updatedUser = User.fromJson(data);
      ref.read(authProvider.notifier).updateUser(updatedUser);
      _showSnackBar('昵称更新成功');
    } catch (e) {
      _showSnackBar('更新失败: $e', isError: true);
    }
  }

  /// 切换当前孩子
  Future<void> _switchChild(Child child) async {
    await ref.read(currentChildProvider.notifier).switchChild(child);
  }

  /// 长按孩子卡片：编辑/删除菜单
  void _showChildActionSheet(Child child) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: AppTheme.accent),
              title: const Text('编辑档案'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showChildEditDialog(child: child);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppTheme.errorRed),
              title: const Text('删除档案'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showDeleteConfirmDialog(child);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close, color: AppTheme.muted),
              title: const Text('取消'),
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );
  }

  /// 删除孩子确认对话框
  void _showDeleteConfirmDialog(Child child) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除档案'),
        content: Text('确定要删除「${child.name}」的档案吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _deleteChild(child);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 调用 DELETE /children/{id}
  Future<void> _deleteChild(Child child) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.delete(ApiEndpoints.childDetail(child.id));
      // 刷新孩子列表
      final children = await ref.refresh(childrenProvider.future);
      // 若删除的是当前选中孩子，切换到第一个孩子；无孩子则重置当前孩子状态，
      // 避免后续 API 请求仍携带已删除的 child ID
      final currentChild = ref.read(currentChildProvider).child;
      if (currentChild?.id == child.id) {
        if (children.isNotEmpty) {
          await ref
              .read(currentChildProvider.notifier)
              .switchChild(children.first);
        } else {
          ref.invalidate(currentChildProvider);
        }
      }
      _showSnackBar('删除成功');
    } catch (e) {
      _showSnackBar('删除失败: $e', isError: true);
    }
  }

  /// 添加/编辑孩子档案对话框
  void _showChildEditDialog({Child? child}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _ChildEditDialog(
        child: child,
        onSubmit: (name, gender, birthDate) async {
          if (child == null) {
            await _createChild(name, gender, birthDate);
          } else {
            await _updateChild(child, name, gender, birthDate);
          }
        },
      ),
    );
  }

  /// 调用 POST /children
  Future<void> _createChild(String name, int gender, DateTime birthDate) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.post(
        ApiEndpoints.children,
        data: {
          'name': name,
          'gender': gender,
          'birth_date': _formatDate(birthDate),
        },
      );
      ref.invalidate(childrenProvider);
      _showSnackBar('添加成功');
    } catch (e) {
      _showSnackBar('添加失败: $e', isError: true);
    }
  }

  /// 调用 PUT /children/{id}
  Future<void> _updateChild(
      Child child, String name, int gender, DateTime birthDate) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.put(
        ApiEndpoints.childDetail(child.id),
        data: {
          'name': name,
          'gender': gender,
          'birth_date': _formatDate(birthDate),
        },
      );
      ref.invalidate(childrenProvider);
      // 若更新的是当前孩子，同步本地状态
      final currentChild = ref.read(currentChildProvider).child;
      if (currentChild?.id == child.id) {
        await ref.read(currentChildProvider.notifier).switchChild(
              child.copyWith(
                name: name,
                gender: gender,
                birthDate: birthDate,
              ),
            );
      }
      _showSnackBar('更新成功');
    } catch (e) {
      _showSnackBar('更新失败: $e', isError: true);
    }
  }

  /// 格式化日期为 YYYY-MM-DD
  String _formatDate(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// 退出登录确认
  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('退出登录'),
          content: const Text('确定要退出登录吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) {
                  context.go('/login');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorRed,
              ),
              child: const Text('退出'),
            ),
          ],
        );
      },
    );
  }
}

/// 孩子档案编辑对话框（添加/编辑共用）
class _ChildEditDialog extends StatefulWidget {
  final Child? child;
  final Future<void> Function(String name, int gender, DateTime birthDate)
      onSubmit;

  const _ChildEditDialog({this.child, required this.onSubmit});

  @override
  State<_ChildEditDialog> createState() => _ChildEditDialogState();
}

class _ChildEditDialogState extends State<_ChildEditDialog> {
  late final TextEditingController _nameController;
  int _gender = 1; // 默认男
  DateTime _birthDate = DateTime(2020, 1, 1);
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final c = widget.child;
    _nameController = TextEditingController(text: c?.name ?? '');
    if (c != null) {
      _gender = c.gender;
      _birthDate = c.birthDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入孩子姓名'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(name, _gender, _birthDate);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      // 错误已在调用方通过 SnackBar 提示
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.child != null;
    return AlertDialog(
      title: Text(isEdit ? '编辑孩子档案' : '添加孩子档案'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 姓名
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '姓名',
                hintText: '请输入孩子姓名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // 性别
            Row(
              children: [
                const Text('性别：',
                    style: TextStyle(fontSize: 14, fontFamily: 'NotoSansSC')),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('男'),
                  selected: _gender == 1,
                  onSelected: (_) => setState(() => _gender = 1),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('女'),
                  selected: _gender == 0,
                  onSelected: (_) => setState(() => _gender = 0),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 出生日期
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '出生日期',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today, size: 18),
                ),
                child: Text(_formatDate(_birthDate)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEdit ? '保存' : '添加'),
        ),
      ],
    );
  }
}

/// 菜单项数据类
class _MenuItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  _MenuItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.onTap,
  });
}
