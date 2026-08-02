import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';
import '../network/api_endpoints.dart';

/// UploadQueueService - 离线上传队列
///
/// 离线时将上传任务暂存到 SharedPreferences，网络恢复后逐个重试。
/// task 字段约定：
///   - id：唯一任务 ID
///   - type：'work' 或 'honor'
///   - title：标题
///   - description：描述
///   - category：分类/级别
///   - images_path：本地图片路径列表
///   - tags：标签列表（作品）
///   - created_date：创作日期 ISO 字符串
///   - child_id：孩子 ID
///   - enqueued_at：入队时间戳
class UploadQueueService {
  static UploadQueueService? _instance;

  /// 单例实例
  static UploadQueueService get instance {
    _instance ??= UploadQueueService._();
    return _instance!;
  }

  UploadQueueService._();

  static const String _queueKey = 'upload_queue';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// 生成唯一任务 ID：timestamp + random
  String _generateId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(0xFFFF).toRadixString(16).padLeft(4, '0');
    return 'task_${ts}_$rand';
  }

  /// 入队一个上传任务
  Future<String> enqueue(Map<String, dynamic> task) async {
    try {
      final prefs = await _getPrefs();
      final queue = await getPending();
      final id = (task['id'] as String?) ?? _generateId();
      final enriched = <String, dynamic>{
        ...task,
        'id': id,
        'enqueued_at': DateTime.now().toIso8601String(),
      };
      queue.add(enriched);
      await prefs.setString(_queueKey, jsonEncode(queue));
      if (kDebugMode) {
        debugPrint('📥 [UploadQueue] 入队成功 id=$id 剩余 ${queue.length}');
      }
      return id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📥 [UploadQueue] 入队失败: $e');
      }
      rethrow;
    }
  }

  /// 获取所有待上传任务
  Future<List<Map<String, dynamic>>> getPending() async {
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString(_queueKey);
      if (raw == null || raw.isEmpty) return const [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📥 [UploadQueue] 读取队列失败: $e');
      }
      return const [];
    }
  }

  /// 上传成功后移除任务
  Future<void> dequeue(String taskId) async {
    try {
      final prefs = await _getPrefs();
      final queue = await getPending();
      queue.removeWhere((t) => t['id'] == taskId);
      await prefs.setString(_queueKey, jsonEncode(queue));
      if (kDebugMode) {
        debugPrint('📥 [UploadQueue] 出队成功 id=$taskId 剩余 ${queue.length}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📥 [UploadQueue] 出队失败: $e');
      }
    }
  }

  /// 处理队列：逐个重试上传
  /// 成功的移除，失败的保留以便下次重试
  Future<int> processQueue(ApiClient apiClient) async {
    final queue = await getPending();
    if (queue.isEmpty) return 0;

    int successCount = 0;
    for (final task in List<Map<String, dynamic>>.from(queue)) {
      final taskId = task['id'] as String?;
      if (taskId == null) continue;
      try {
        final ok = await _processTask(apiClient, task);
        if (ok) {
          await dequeue(taskId);
          successCount++;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('📥 [UploadQueue] 任务 $taskId 重试失败: $e');
        }
        // 单个任务失败不阻塞后续任务
      }
    }
    if (kDebugMode) {
      debugPrint('📥 [UploadQueue] 处理完成，成功 $successCount 个');
    }
    return successCount;
  }

  /// 处理单个上传任务
  Future<bool> _processTask(
      ApiClient apiClient, Map<String, dynamic> task) async {
    try {
      final type = task['type'] as String? ?? 'work';
      final title = (task['title'] as String?) ?? '';
      final description = (task['description'] as String?) ?? '';
      final category = task['category'] as String?;
      final createdDate =
          (task['created_date'] as String?) ?? _todayIso();
      final childId = task['child_id']?.toString();
      if (childId == null || childId.isEmpty) return false;

      // 1. 上传第一张图片作为封面
      String? imageUrl;
      String? thumbnailUrl;
      final imagesPath = (task['images_path'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      if (imagesPath.isNotEmpty && !kIsWeb) {
        final firstPath = imagesPath.first;
        final fileName = firstPath.split('/').last.split('\\').last;
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            firstPath,
            filename: fileName,
          ),
        });
        final uploadResp = await apiClient.post(
          ApiEndpoints.uploadImage,
          data: formData,
        );
        final uploadData =
            uploadResp.data['data'] as Map<String, dynamic>;
        imageUrl = uploadData['url'] as String?;
        thumbnailUrl = uploadData['thumbnail_url'] as String?;
      }

      // 2. 创建作品/荣誉
      if (type == 'work') {
        final tags = (task['tags'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[];
        final payload = <String, dynamic>{
          'title': title,
          'category': category ?? '其他',
          'description': description.isEmpty ? null : description,
          'image_url': imageUrl,
          'thumbnail_url': thumbnailUrl,
          'created_date': createdDate,
          'child_id': int.tryParse(childId) ?? childId,
          'tags': tags,
        };
        await apiClient.post(ApiEndpoints.works, data: payload);
      } else {
        final payload = <String, dynamic>{
          'title': title,
          'level': category ?? '校级',
          'category': '其他',
          'image_url': imageUrl,
          'award_date': createdDate,
          'description': description.isEmpty ? null : description,
          'child_id': int.tryParse(childId) ?? childId,
        };
        await apiClient.post(ApiEndpoints.honors, data: payload);
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📥 [UploadQueue] 任务处理异常: $e');
      }
      return false;
    }
  }

  String _todayIso() {
    return DateTime.now().toIso8601String().split('T')[0];
  }
}

/// 上传队列 Provider
final uploadQueueServiceProvider = Provider<UploadQueueService>((ref) {
  return UploadQueueService.instance;
});
