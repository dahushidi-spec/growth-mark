/// User模型 - 用户信息
class User {
  final String id;
  final String phone;
  final String nickname;
  final String? avatarUrl;
  final String? email;
  final DateTime? createdAt;

  User({
    required this.id,
    required this.phone,
    required this.nickname,
    this.avatarUrl,
    this.email,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] ?? '').toString(),
      phone: json['phone'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      email: json['email'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'nickname': nickname,
      'avatar_url': avatarUrl,
      'email': email,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? phone,
    String? nickname,
    String? avatarUrl,
    String? email,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, phone: $phone, nickname: $nickname, avatarUrl: $avatarUrl)';
  }
}

/// Child模型 - 孩子档案
class Child {
  final String id;
  final String userId;
  final String name;
  final int gender; // 0女 1男
  final DateTime birthDate;
  final String? avatarUrl;
  final String? bio;
  final String age; // 服务端计算的 "X岁X月"，未传时本地计算

  Child({
    required this.id,
    required this.userId,
    required this.name,
    required this.gender,
    required this.birthDate,
    this.avatarUrl,
    this.bio,
    this.age = '',
  });

  factory Child.fromJson(Map<String, dynamic> json) {
    return Child(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      name: json['name'] as String? ?? '',
      gender: json['gender'] is int ? json['gender'] as int : 0,
      birthDate: json['birth_date'] != null
          ? DateTime.parse(json['birth_date'] as String)
          : DateTime.now(),
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      age: json['age'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'gender': gender,
      'birth_date': birthDate.toIso8601String(),
      'avatar_url': avatarUrl,
      if (bio != null) 'bio': bio,
    };
  }

  Child copyWith({
    String? id,
    String? userId,
    String? name,
    int? gender,
    DateTime? birthDate,
    String? avatarUrl,
    String? bio,
    String? age,
  }) {
    return Child(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      age: age ?? this.age,
    );
  }

  /// 性别文字
  String get genderText => gender == 1 ? '男' : '女';

  /// 年龄展示：优先使用服务端返回的 age，否则本地计算
  String get ageString => age.isNotEmpty ? age : _calcAge();

  String _calcAge() {
    final now = DateTime.now();
    int years = now.year - birthDate.year;
    int months = now.month - birthDate.month;

    if (months < 0) {
      years--;
      months += 12;
    }

    if (now.day < birthDate.day) {
      months--;
      if (months < 0) {
        years--;
        months += 12;
      }
    }

    if (years <= 0 && months <= 0) {
      return '${(now.difference(birthDate).inDays)}天';
    }
    if (years <= 0) {
      return '$months个月';
    }
    if (months <= 0) {
      return '$years岁';
    }
    return '$years岁$months个月';
  }

  /// 计算年龄（月数）
  int get ageInMonths {
    final now = DateTime.now();
    return (now.year - birthDate.year) * 12 + (now.month - birthDate.month);
  }

  @override
  String toString() {
    return 'Child(id: $id, name: $name, gender: $gender, birthDate: $birthDate)';
  }
}
