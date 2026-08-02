/// ApiResponse - 统一API响应封装
/// 泛型T为data字段的实际数据类型
class ApiResponse<T> {
  final int code;
  final String message;
  final T? data;

  ApiResponse({
    required this.code,
    required this.message,
    this.data,
  });

  /// 是否成功（code为200表示成功）
  bool get isSuccess => code == 200;

  /// 从JSON构造ApiResponse
  /// [fromJsonT] 为T类型的fromJson转换函数
  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>)? fromJsonT,
  ) {
    return ApiResponse<T>(
      code: json['code'] as int? ?? 0,
      message: json['message'] as String? ?? '',
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'] as Map<String, dynamic>)
          : json['data'] as T?,
    );
  }

  /// 从JSON构造ApiResponse列表
  factory ApiResponse.fromJsonList(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    final dataList = json['data'] as List<dynamic>?;
    return ApiResponse<T>(
      code: json['code'] as int? ?? 0,
      message: json['message'] as String? ?? '',
      data: dataList != null
          ? dataList.map((e) => fromJsonT(e as Map<String, dynamic>)).toList()
              as T
          : null,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson({
    Map<String, dynamic> Function(T)? toJsonT,
  }) {
    return {
      'code': code,
      'message': message,
      'data': data != null && toJsonT != null ? toJsonT(data as T) : data,
    };
  }

  @override
  String toString() {
    return 'ApiResponse(code: $code, message: $message, data: $data)';
  }
}

/// 分页响应数据
class PagedData<T> {
  final List<T> items;
  final int total;
  final int page;
  final int pageSize;
  final bool hasMore;

  PagedData({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.hasMore,
  });

  factory PagedData.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    final list = json['items'] as List<dynamic>? ?? [];
    return PagedData<T>(
      items: list.map((e) => fromJsonT(e as Map<String, dynamic>)).toList(),
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
      hasMore: json['has_more'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson(Map<String, dynamic> Function(T) toJsonT) {
    return {
      'items': items.map(toJsonT).toList(),
      'total': total,
      'page': page,
      'page_size': pageSize,
      'has_more': hasMore,
    };
  }
}
