import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// OfflineCacheService - 离线缓存服务
///
/// 基于 SharedPreferences 持久化缓存关键列表数据（时间线 / 荣誉 / 成长报告），
/// 在无网络时供页面降级展示。每条缓存项都附带 `cached_at` 时间戳。
class OfflineCacheService {
  static OfflineCacheService? _instance;

  /// 单例实例
  static OfflineCacheService get instance {
    _instance ??= OfflineCacheService._();
    return _instance!;
  }

  OfflineCacheService._();

  SharedPreferences? _prefs;

  // ===== 缓存键定义 =====
  /// 时间线缓存键前缀：cache:timeline:{childId}
  static const String timelinePrefix = 'cache:timeline:';

  /// 荣誉缓存键
  static const String honorsKey = 'cache:honors';

  /// 报告缓存键
  static const String reportsKey = 'cache:reports';

  /// 缓存写入时间键后缀
  static const String _cachedAtSuffix = ':cached_at';

  /// 初始化 SharedPreferences
  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ===== 时间线缓存 =====

  /// 缓存时间线数据
  Future<void> cacheTimeline(
      List<Map<String, dynamic>> items, String childId) async {
    try {
      final prefs = await _getPrefs();
      final key = '$timelinePrefix$childId';
      await prefs.setString(key, jsonEncode(items));
      await prefs.setString(
          '$key$_cachedAtSuffix', DateTime.now().toIso8601String());
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📥 [OfflineCache] 缓存时间线失败: $e');
      }
    }
  }

  /// 读取时间线缓存
  Future<List<Map<String, dynamic>>> getTimeline(String childId) async {
    try {
      final prefs = await _getPrefs();
      final cached = prefs.getString('$timelinePrefix$childId');
      if (cached == null) return const [];
      final list = jsonDecode(cached) as List<dynamic>;
      return list
          .map((e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📥 [OfflineCache] 读取时间线缓存失败: $e');
      }
      return const [];
    }
  }

  /// 读取时间线缓存写入时间
  Future<DateTime?> getTimelineCachedAt(String childId) async {
    try {
      final prefs = await _getPrefs();
      final raw =
          prefs.getString('$timelinePrefix$childId$_cachedAtSuffix');
      if (raw == null) return null;
      return DateTime.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  // ===== 荣誉缓存 =====

  /// 缓存荣誉列表
  Future<void> cacheHonors(List<Map<String, dynamic>> items) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(honorsKey, jsonEncode(items));
      await prefs.setString(
          '$honorsKey$_cachedAtSuffix', DateTime.now().toIso8601String());
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📥 [OfflineCache] 缓存荣誉失败: $e');
      }
    }
  }

  /// 读取荣誉缓存
  Future<List<Map<String, dynamic>>> getHonors() async {
    try {
      final prefs = await _getPrefs();
      final cached = prefs.getString(honorsKey);
      if (cached == null) return const [];
      final list = jsonDecode(cached) as List<dynamic>;
      return list
          .map((e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📥 [OfflineCache] 读取荣誉缓存失败: $e');
      }
      return const [];
    }
  }

  // ===== 报告缓存 =====

  /// 缓存成长报告列表
  Future<void> cacheReports(List<Map<String, dynamic>> items) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(reportsKey, jsonEncode(items));
      await prefs.setString(
          '$reportsKey$_cachedAtSuffix', DateTime.now().toIso8601String());
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📥 [OfflineCache] 缓存报告失败: $e');
      }
    }
  }

  /// 读取成长报告缓存
  Future<List<Map<String, dynamic>>> getReports() async {
    try {
      final prefs = await _getPrefs();
      final cached = prefs.getString(reportsKey);
      if (cached == null) return const [];
      final list = jsonDecode(cached) as List<dynamic>;
      return list
          .map((e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📥 [OfflineCache] 读取报告缓存失败: $e');
      }
      return const [];
    }
  }

  // ===== 清理 =====

  /// 清空所有缓存
  Future<void> clearAll() async {
    try {
      final prefs = await _getPrefs();
      final keys = prefs.getKeys().where(
          (k) => k.startsWith('cache:') || k.contains(_cachedAtSuffix));
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📥 [OfflineCache] 清空缓存失败: $e');
      }
    }
  }
}

/// 离线缓存 Provider
final offlineCacheServiceProvider = Provider<OfflineCacheService>((ref) {
  return OfflineCacheService.instance;
});
