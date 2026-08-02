/// MockData - Mock 数据切换机制
///
/// 开发环境下可通过 [MockData.useMock] 开关切换 Mock 数据，
/// 便于在后端未启动时进行前端 UI 开发与调试。
/// 在 AppConstants 中设置 `useMockData = true` 即可全局启用。
import 'package:dio/dio.dart';

class MockData {
  MockData._();

  /// 是否启用 Mock 数据（由 AppConstants.useMockData 控制）
  static bool useMock = false;

  /// Mock 数据路由表：method + path -> 响应数据
  static final Map<String, Map<String, dynamic>> _mockResponses = {
    // ===== 认证 =====
    'POST:/auth/sms/send': {
      'code': 200,
      'message': 'success',
      'data': {'sent': true},
    },
    'POST:/auth/login': {
      'code': 200,
      'message': 'success',
      'data': {
        'access_token': 'mock-access-token',
        'refresh_token': 'mock-refresh-token',
        'token_type': 'bearer',
        'user': {
          'id': 1,
          'phone': '13800000000',
          'nickname': 'Mock 用户',
          'avatar_url': null,
        },
      },
    },
    'POST:/auth/register': {
      'code': 200,
      'message': 'success',
      'data': {
        'access_token': 'mock-access-token',
        'refresh_token': 'mock-refresh-token',
        'token_type': 'bearer',
        'user': {
          'id': 2,
          'phone': '13800000001',
          'nickname': '新用户',
          'avatar_url': null,
        },
      },
    },
    'GET:/auth/me': {
      'code': 200,
      'message': 'success',
      'data': {
        'id': 1,
        'phone': '13800000000',
        'nickname': 'Mock 用户',
        'avatar_url': null,
      },
    },
    // ===== 时间线 =====
    'GET:/works/timeline': {
      'code': 200,
      'message': 'success',
      'data': {
        'items': [
          {
            'id': 1,
            'title': '我的第一幅画',
            'category': '绘画',
            'image_url': '',
            'thumbnail_url': '',
            'created_date': '2026-06-01',
            'description': '孩子画的太阳花',
          },
        ],
        'total': 1,
        'page': 1,
        'size': 20,
      },
    },
    // ===== 荣誉墙 =====
    'GET:/honors': {
      'code': 200,
      'message': 'success',
      'data': {
        'items': [
          {
            'id': 1,
            'title': '少儿绘画比赛一等奖',
            'level': '市级',
            'category': '绘画',
            'award_date': '2026-05-15',
          },
        ],
        'total': 1,
        'page': 1,
        'size': 20,
      },
    },
  };

  /// 尝试匹配 Mock 响应，匹配成功返回 true 并填充 [response]
  static bool tryMatch(String method, String path, Response response) {
    final key = '$method:$path';
    final mock = _mockResponses[key];
    if (mock != null) {
      response.data = mock;
      response.statusCode = 200;
      return true;
    }
    return false;
  }

  /// 判断某请求是否有 Mock 数据
  static bool hasMock(String method, String path) {
    return _mockResponses.containsKey('$method:$path');
  }
}
