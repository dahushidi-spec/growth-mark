/// HonorLevel枚举 - 荣誉级别
enum HonorLevel {
  national('国家级', '🏆', 4),
  provincial('省级', '🥇', 3),
  municipal('市级', '🥈', 2),
  school('校级', '🥉', 1);

  final String label;
  final String emoji;
  final int priority; // 优先级，数字越大级别越高

  const HonorLevel(this.label, this.emoji, this.priority);

  /// 从字符串获取枚举
  static HonorLevel fromString(String value) {
    return HonorLevel.values.firstWhere(
      (e) => e.label == value || e.name == value,
      orElse: () => HonorLevel.school,
    );
  }

  /// 从中文名称获取枚举
  static HonorLevel fromLabel(String label) {
    return HonorLevel.values.firstWhere(
      (e) => e.label == label,
      orElse: () => HonorLevel.school,
    );
  }
}

/// Honor模型 - 荣誉信息
class Honor {
  final String id;
  final String childId;
  final String title;
  final HonorLevel level;
  final String? category;
  final String? imageUrl;
  final DateTime awardDate;
  final String? organization;
  final String? description;

  Honor({
    required this.id,
    required this.childId,
    required this.title,
    required this.level,
    this.category,
    this.imageUrl,
    required this.awardDate,
    this.organization,
    this.description,
  });

  factory Honor.fromJson(Map<String, dynamic> json) {
    return Honor(
      id: (json['id'] ?? '').toString(),
      childId: (json['child_id'] ?? '').toString(),
      title: json['title'] as String? ?? '',
      level: HonorLevel.fromLabel(json['level'] as String? ?? '校级'),
      category: json['category'] as String?,
      imageUrl: json['image_url'] as String?,
      awardDate: json['award_date'] != null
          ? DateTime.parse(json['award_date'] as String)
          : DateTime.now(),
      organization: json['organization'] as String?,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'child_id': childId,
      'title': title,
      'level': level.label,
      'category': category,
      'image_url': imageUrl,
      'award_date': awardDate.toIso8601String(),
      'organization': organization,
      'description': description,
    };
  }

  Honor copyWith({
    String? id,
    String? childId,
    String? title,
    HonorLevel? level,
    String? category,
    String? imageUrl,
    DateTime? awardDate,
    String? organization,
    String? description,
  }) {
    return Honor(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      title: title ?? this.title,
      level: level ?? this.level,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      awardDate: awardDate ?? this.awardDate,
      organization: organization ?? this.organization,
      description: description ?? this.description,
    );
  }

  /// 格式化获奖日期
  String get formattedAwardDate {
    return '${awardDate.year}年${awardDate.month}月${awardDate.day}日';
  }

  /// 是否为本年度荣誉
  bool get isCurrentYear {
    return awardDate.year == DateTime.now().year;
  }

  /// 是否为市级以上
  bool get isAboveMunicipal {
    return level.priority >= HonorLevel.municipal.priority;
  }

  @override
  String toString() {
    return 'Honor(id: $id, title: $title, level: $level, awardDate: $awardDate)';
  }
}
