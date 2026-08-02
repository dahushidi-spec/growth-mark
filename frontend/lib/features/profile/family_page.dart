import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/providers/providers.dart';
import '../../core/storage/local_storage.dart';
import '../../models/family.dart';
import '../../shared/widgets/loading_widget.dart';

/// 家庭空间状态
class FamilyState {
  final Family? family;
  final List<FamilyMember> members;
  final bool isLoading;
  final String? currentUserId;

  const FamilyState({
    this.family,
    this.members = const [],
    this.isLoading = false,
    this.currentUserId,
  });

  FamilyState copyWith({
    Family? family,
    List<FamilyMember>? members,
    bool? isLoading,
    String? currentUserId,
  }) {
    return FamilyState(
      family: family ?? this.family,
      members: members ?? this.members,
      isLoading: isLoading ?? this.isLoading,
      currentUserId: currentUserId ?? this.currentUserId,
    );
  }

  /// 当前用户是否可管理成员（创建者或管理员）
  bool get canManageMembers {
    if (currentUserId == null || members.isEmpty) return false;
    final myMember = members.where((m) => m.userId == currentUserId);
    if (myMember.isEmpty) return false;
    final role = myMember.first.role;
    return role == 'creator' || role == 'admin';
  }
}

/// 家庭空间状态管理器
class FamilyNotifier extends StateNotifier<FamilyState> {
  final ApiClient _apiClient;
  final LocalStorage _localStorage;

  FamilyNotifier(this._apiClient, this._localStorage)
      : super(const FamilyState());

  /// 加载家庭数据
  /// 1. 从 LocalStorage 读取 family_id
  /// 2. 没有 family_id → 显示创建/加入入口
  /// 3. 有 family_id → 调用 GET /families/{family_id}/members 加载成员列表
  Future<void> loadFamily() async {
    state = state.copyWith(isLoading: true);

    final currentUserId = await _localStorage.getUserId();
    final familyId = await _localStorage.getString('family_id');

    if (familyId == null || familyId.isEmpty) {
      state = FamilyState(isLoading: false, currentUserId: currentUserId);
      return;
    }

    try {
      // 恢复缓存的家庭基本信息（名称、邀请码等，因为 members 接口不返回这些）
      Family? cachedFamily;
      final familyJson = await _localStorage.getString('family_data');
      if (familyJson != null && familyJson.isNotEmpty) {
        try {
          cachedFamily = Family.fromJson(
            jsonDecode(familyJson) as Map<String, dynamic>,
          );
        } catch (_) {
          // 缓存解析失败，忽略
        }
      }

      // 拉取成员列表：GET /families/{family_id}/members
      final response = await _apiClient.get(
        '${ApiEndpoints.familyDetail(familyId)}/members',
      );
      final body = response.data as Map<String, dynamic>;
      final list = body['data'] as List<dynamic>? ?? [];
      final members = list
          .map((e) => FamilyMember.fromJson(e as Map<String, dynamic>))
          .toList();

      final family = (cachedFamily ??
              Family(
                id: familyId,
                name: '我的家庭',
                inviteCode: '',
                creatorId: '',
              ))
          .copyWith(memberCount: members.length);

      state = FamilyState(
        family: family,
        members: members,
        isLoading: false,
        currentUserId: currentUserId,
      );
    } catch (e) {
      state = FamilyState(isLoading: false, currentUserId: currentUserId);
      rethrow;
    }
  }

  /// 创建家庭：POST /families body:{name}
  Future<void> createFamily(String name) async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _apiClient.post(
        ApiEndpoints.families,
        data: {'name': name},
      );
      final body = response.data as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>;
      final family = Family.fromJson(data);

      // 缓存 family_id 和 family 信息
      await _localStorage.saveString('family_id', family.id);
      await _localStorage.saveString('family_data', jsonEncode(data));

      final members = (data['members'] as List<dynamic>? ?? [])
          .map((e) => FamilyMember.fromJson(e as Map<String, dynamic>))
          .toList();

      state = FamilyState(
        family: family,
        members: members,
        isLoading: false,
        currentUserId: state.currentUserId,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  /// 加入家庭：POST /families/join body:{invite_code}
  Future<void> joinFamily(String inviteCode) async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _apiClient.post(
        ApiEndpoints.familyJoin,
        data: {'invite_code': inviteCode},
      );
      final body = response.data as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>;
      final family = Family.fromJson(data);

      // 缓存 family_id 和 family 信息
      await _localStorage.saveString('family_id', family.id);
      await _localStorage.saveString('family_data', jsonEncode(data));

      final members = (data['members'] as List<dynamic>? ?? [])
          .map((e) => FamilyMember.fromJson(e as Map<String, dynamic>))
          .toList();

      state = FamilyState(
        family: family,
        members: members,
        isLoading: false,
        currentUserId: state.currentUserId,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  /// 移除成员：DELETE /families/{family_id}/members/{user_id}
  Future<void> removeMember(String userId) async {
    final familyId = state.family?.id;
    if (familyId == null) return;
    try {
      await _apiClient.delete(
        ApiEndpoints.familyRemoveMember(familyId, userId),
      );
      // 刷新成员列表
      await loadFamily();
    } catch (e) {
      rethrow;
    }
  }
}

final familyProvider =
    StateNotifierProvider<FamilyNotifier, FamilyState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final localStorage = ref.watch(localStorageProvider);
  return FamilyNotifier(apiClient, localStorage);
});

/// FamilyPage - 家庭空间页面
class FamilyPage extends ConsumerStatefulWidget {
  const FamilyPage({super.key});

  @override
  ConsumerState<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends ConsumerState<FamilyPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(familyProvider.notifier).loadFamily();
      } catch (e) {
        if (mounted) {
          _showError(e);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(familyProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('家庭空间'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: state.isLoading
          ? const LoadingWidget(text: '加载中...')
          : state.family == null
              ? _buildNoFamilyState()
              : _buildContent(state),
    );
  }

  /// 没有家庭时的创建/加入入口
  Widget _buildNoFamilyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 24),
            const Text(
              '还没有家庭空间',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: 'NotoSansSC',
                color: AppTheme.ink,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              '创建家庭空间，邀请家人一起记录宝贝成长',
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'NotoSansSC',
                color: AppTheme.muted,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showCreateDialog(),
              icon: const Icon(Icons.add_home),
              label: const Text('创建家庭'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _showJoinDialog(),
              icon: const Icon(Icons.group_add),
              label: const Text('加入家庭'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(FamilyState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 家庭信息卡片
          _buildFamilyCard(state.family!),
          const SizedBox(height: 24),
          // 邀请码
          _buildInviteCard(state.family!),
          const SizedBox(height: 24),
          // 成员列表
          _buildMembersSection(state.members, state.canManageMembers),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// 家庭信息卡片
  Widget _buildFamilyCard(Family family) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.accent3, AppTheme.accent],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent3.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.family_restroom, size: 48, color: Colors.white),
          const SizedBox(height: 12),
          Text(
            family.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'NotoSansSC',
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${family.memberCount}位家庭成员',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'NotoSansSC',
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  /// 邀请码卡片
  Widget _buildInviteCard(Family family) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.person_add, color: AppTheme.accent),
                const SizedBox(width: 8),
                Text(
                  '邀请家人',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'NotoSansSC',
                    color: AppTheme.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.bg2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '邀请码：',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.muted,
                      fontFamily: 'NotoSansSC',
                    ),
                  ),
                  Text(
                    family.inviteCode,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'NotoSansSC',
                      color: AppTheme.accent,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _copyInviteCode(family.inviteCode),
                icon: const Icon(Icons.share),
                label: const Text('分享邀请码'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 成员列表
  Widget _buildMembersSection(List<FamilyMember> members, bool canManage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '家庭成员',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'NotoSansSC',
            color: AppTheme.ink,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: members
                .map((member) => _buildMemberItem(member, canManage))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberItem(FamilyMember member, bool canManage) {
    // 创建者不可被移除；其余成员在有权限时可被移除
    final canRemove = canManage && member.role != 'creator';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.bg2,
              image: member.avatarUrl != null
                  ? DecorationImage(
                      image: NetworkImage(member.avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: member.avatarUrl == null
                ? const Icon(Icons.person, color: AppTheme.muted)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.nickname,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'NotoSansSC',
                    color: AppTheme.ink,
                  ),
                ),
                Text(
                  '${member.roleDisplayName} · ${member.formattedJoinedAt}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.muted,
                    fontFamily: 'NotoSansSC',
                  ),
                ),
              ],
            ),
          ),
          if (canRemove)
            IconButton(
              icon: const Icon(Icons.more_vert, color: AppTheme.muted),
              onPressed: () => _showMemberOptions(member),
            ),
        ],
      ),
    );
  }

  /// 创建家庭对话框
  void _showCreateDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('创建家庭空间'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: '家庭名称',
              hintText: '请输入家庭名称',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(dialogContext);
                try {
                  await ref.read(familyProvider.notifier).createFamily(name);
                  if (mounted) _showSnackBar('家庭创建成功');
                } catch (e) {
                  if (mounted) _showError(e);
                }
              },
              child: const Text('创建'),
            ),
          ],
        );
      },
    );
  }

  /// 加入家庭对话框
  void _showJoinDialog() {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('加入家庭空间'),
          content: TextField(
            controller: codeController,
            decoration: const InputDecoration(
              labelText: '邀请码',
              hintText: '请输入家庭邀请码',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final code = codeController.text.trim();
                if (code.isEmpty) return;
                Navigator.pop(dialogContext);
                try {
                  await ref.read(familyProvider.notifier).joinFamily(code);
                  if (mounted) _showSnackBar('加入家庭成功');
                } catch (e) {
                  if (mounted) _showError(e);
                }
              },
              child: const Text('加入'),
            ),
          ],
        );
      },
    );
  }

  /// 成员操作选项（移除成员）
  void _showMemberOptions(FamilyMember member) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_remove, color: Colors.red),
                title: const Text('移除成员'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmRemoveMember(member);
                },
              ),
              ListTile(
                leading: const Icon(Icons.close, color: AppTheme.muted),
                title: const Text('取消'),
                onTap: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 确认移除成员
  void _confirmRemoveMember(FamilyMember member) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('移除成员'),
          content: Text('确定要移除 ${member.nickname} 吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await ref
                      .read(familyProvider.notifier)
                      .removeMember(member.userId);
                  if (mounted) _showSnackBar('已移除 ${member.nickname}');
                } catch (e) {
                  if (mounted) _showError(e);
                }
              },
              child: const Text('移除'),
            ),
          ],
        );
      },
    );
  }

  /// 复制邀请码到剪贴板
  void _copyInviteCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    _showSnackBar('邀请码已复制到剪贴板');
  }

  /// 从异常中提取错误信息
  String _extractError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        return data['message'] as String? ?? '请求失败，请稍后重试';
      }
      return e.message ?? '网络错误，请稍后重试';
    }
    return e.toString();
  }

  void _showError(Object e) {
    _showSnackBar(_extractError(e));
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
