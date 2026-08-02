/// Family模型 - 家庭空间
class Family {
  final String id;
  final String name;
  final String inviteCode;
  final String creatorId;
  final int memberCount;
  final DateTime? createdAt;

  Family({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.creatorId,
    this.memberCount = 0,
    this.createdAt,
  });

  factory Family.fromJson(Map<String, dynamic> json) {
    // 后端 id/creator_id 是 int，需要转 String
    // 后端返回 members 数组，需要计算 member_count
    final membersJson = json['members'] as List<dynamic>?;
    final membersCount = membersJson?.length ?? (json['member_count'] as int? ?? 0);
    return Family(
      id: (json['id'] ?? '').toString(),
      name: json['name'] as String? ?? '',
      inviteCode: json['invite_code'] as String? ?? '',
      creatorId: (json['creator_id'] ?? '').toString(),
      memberCount: membersCount,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'invite_code': inviteCode,
      'creator_id': creatorId,
      'member_count': memberCount,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  Family copyWith({
    String? id,
    String? name,
    String? inviteCode,
    String? creatorId,
    int? memberCount,
    DateTime? createdAt,
  }) {
    return Family(
      id: id ?? this.id,
      name: name ?? this.name,
      inviteCode: inviteCode ?? this.inviteCode,
      creatorId: creatorId ?? this.creatorId,
      memberCount: memberCount ?? this.memberCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Family(id: $id, name: $name, inviteCode: $inviteCode, memberCount: $memberCount)';
  }
}

/// FamilyMember模型 - 家庭成员
class FamilyMember {
  final String id;
  final String userId;
  final String nickname;
  final String? avatarUrl;
  final String role; // 角色：家长/爷爷/奶奶/外公/外婆/其他
  final DateTime joinedAt;

  FamilyMember({
    required this.id,
    required this.userId,
    required this.nickname,
    this.avatarUrl,
    required this.role,
    required this.joinedAt,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    // 后端 id/user_id 是 int，需要转 String
    // role 后端返回英文：creator/admin/member
    return FamilyMember(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      nickname: json['nickname'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] as String? ?? 'member',
      joinedAt: json['joined_at'] != null
          ? DateTime.tryParse(json['joined_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'nickname': nickname,
      'avatar_url': avatarUrl,
      'role': role,
      'joined_at': joinedAt.toIso8601String(),
    };
  }

  FamilyMember copyWith({
    String? id,
    String? userId,
    String? nickname,
    String? avatarUrl,
    String? role,
    DateTime? joinedAt,
  }) {
    return FamilyMember(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  /// 格式化加入时间
  String get formattedJoinedAt {
    return '${joinedAt.year}年${joinedAt.month}月${joinedAt.day}日加入';
  }

  /// 角色中文显示名（后端返回英文，前端展示需要中文）
  String get roleDisplayName {
    switch (role) {
      case 'creator':
        return '创建者';
      case 'admin':
        return '管理员';
      case 'member':
        return '成员';
      default:
        return role;
    }
  }

  @override
  String toString() {
    return 'FamilyMember(id: $id, nickname: $nickname, role: $role, joinedAt: $joinedAt)';
  }
}
