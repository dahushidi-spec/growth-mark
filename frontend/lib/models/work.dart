/// WorkCategory枚举 - 作品分类
enum WorkCategory {
  painting('绘画', '🎨'),
  calligraphy('书法', '✍️'),
  handicraft('手工', '✂️'),
  music('音乐', '🎵'),
  writing('写作', '📝'),
  other('其他', '⭐');

  final String label;
  final String emoji;

  const WorkCategory(this.label, this.emoji);

  /// 从字符串获取枚举
  static WorkCategory fromString(String value) {
    return WorkCategory.values.firstWhere(
      (e) => e.label == value || e.name == value,
      orElse: () => WorkCategory.other,
    );
  }

  /// 从中文名称获取枚举
  static WorkCategory fromLabel(String label) {
    return WorkCategory.values.firstWhere(
      (e) => e.label == label,
      orElse: () => WorkCategory.other,
    );
  }
}

/// Work模型 - 作品信息
class Work {
  final String id;
  final String childId;
  final String title;
  final WorkCategory category;
  final String? description;
  final String? imageUrl;
  final String? thumbnailUrl;
  final DateTime createdDate;
  final String childAge;
  final List<String> tags;
  final int likeCount;
  final int commentCount;

  Work({
    required this.id,
    required this.childId,
    required this.title,
    required this.category,
    this.description,
    this.imageUrl,
    this.thumbnailUrl,
    required this.createdDate,
    required this.childAge,
    this.tags = const [],
    this.likeCount = 0,
    this.commentCount = 0,
  });

  factory Work.fromJson(Map<String, dynamic> json) {
    // tags 后端返回 [{tag_name, is_ai_generated, id}]，兼容纯字符串列表
    final tagsRaw = json['tags'] as List<dynamic>?;
    final tags = tagsRaw
            ?.map((e) =>
                (e is Map<String, dynamic>) ? e['tag_name'] as String : e as String)
            .toList() ??
        [];

    return Work(
      id: (json['id'] ?? '').toString(),
      childId: (json['child_id'] ?? '').toString(),
      title: json['title'] as String? ?? '',
      category: WorkCategory.fromLabel(json['category'] as String? ?? '其他'),
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      createdDate: json['created_date'] != null
          ? DateTime.parse(json['created_date'] as String)
          : DateTime.now(),
      childAge: json['child_age'] as String? ?? '',
      tags: tags,
      likeCount: json['like_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'child_id': childId,
      'title': title,
      'category': category.label,
      'description': description,
      'image_url': imageUrl,
      'thumbnail_url': thumbnailUrl,
      'created_date': createdDate.toIso8601String(),
      'child_age': childAge,
      'tags': tags,
      'like_count': likeCount,
      'comment_count': commentCount,
    };
  }

  Work copyWith({
    String? id,
    String? childId,
    String? title,
    WorkCategory? category,
    String? description,
    String? imageUrl,
    String? thumbnailUrl,
    DateTime? createdDate,
    String? childAge,
    List<String>? tags,
    int? likeCount,
    int? commentCount,
  }) {
    return Work(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      title: title ?? this.title,
      category: category ?? this.category,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      createdDate: createdDate ?? this.createdDate,
      childAge: childAge ?? this.childAge,
      tags: tags ?? this.tags,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
    );
  }

  /// 格式化日期字符串
  String get formattedDate {
    return '${createdDate.year}年${createdDate.month}月${createdDate.day}日';
  }

  @override
  String toString() {
    return 'Work(id: $id, title: $title, category: $category, createdDate: $createdDate)';
  }
}
