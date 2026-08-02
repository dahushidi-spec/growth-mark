import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// LocalStorage - 本地存储封装
/// 统一管理 SharedPreferences（简单键值对）和 Hive（离线缓存）
class LocalStorage {
  static LocalStorage? _instance;
  SharedPreferences? _prefs;

  LocalStorage._();

  /// 获取单例实例
  static LocalStorage get instance {
    _instance ??= LocalStorage._();
    return _instance!;
  }

  /// 初始化SharedPreferences
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// 确保SharedPreferences已初始化
  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ===== 认证Token相关 =====

  /// 保存访问Token
  Future<void> saveToken(String token) async {
    final prefs = await _getPrefs();
    await prefs.setString(AppConstants.storageToken, token);
  }

  /// 获取访问Token
  Future<String?> getToken() async {
    final prefs = await _getPrefs();
    return prefs.getString(AppConstants.storageToken);
  }

  /// 保存刷新Token
  Future<void> saveRefreshToken(String token) async {
    final prefs = await _getPrefs();
    await prefs.setString(AppConstants.storageRefreshToken, token);
  }

  /// 获取刷新Token
  Future<String?> getRefreshToken() async {
    final prefs = await _getPrefs();
    return prefs.getString(AppConstants.storageRefreshToken);
  }

  /// 保存用户ID
  Future<void> saveUserId(String userId) async {
    final prefs = await _getPrefs();
    await prefs.setString(AppConstants.storageUserId, userId);
  }

  /// 获取用户ID
  Future<String?> getUserId() async {
    final prefs = await _getPrefs();
    return prefs.getString(AppConstants.storageUserId);
  }

  /// 保存当前选中的孩子ID
  Future<void> saveCurrentChildId(String childId) async {
    final prefs = await _getPrefs();
    await prefs.setString(AppConstants.storageCurrentChildId, childId);
  }

  /// 获取当前选中的孩子ID
  Future<String?> getCurrentChildId() async {
    final prefs = await _getPrefs();
    return prefs.getString(AppConstants.storageCurrentChildId);
  }

  /// 清除认证信息
  Future<void> clearAuth() async {
    final prefs = await _getPrefs();
    await prefs.remove(AppConstants.storageToken);
    await prefs.remove(AppConstants.storageRefreshToken);
    await prefs.remove(AppConstants.storageUserId);
    await prefs.remove(AppConstants.storageCurrentChildId);
  }

  /// 检查是否已登录
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ===== 通用键值存储 =====

  /// 保存任意字符串键值对
  Future<void> saveString(String key, String value) async {
    final prefs = await _getPrefs();
    await prefs.setString(key, value);
  }

  /// 获取任意字符串键值对
  Future<String?> getString(String key) async {
    final prefs = await _getPrefs();
    return prefs.getString(key);
  }

  /// 移除指定键
  Future<void> removeString(String key) async {
    final prefs = await _getPrefs();
    await prefs.remove(key);
  }

  // ===== 主题设置相关 =====

  /// 保存主题模式
  Future<void> saveThemeMode(String mode) async {
    final prefs = await _getPrefs();
    await prefs.setString(AppConstants.storageThemeMode, mode);
  }

  /// 获取主题模式
  Future<String?> getThemeMode() async {
    final prefs = await _getPrefs();
    return prefs.getString(AppConstants.storageThemeMode);
  }

  // ===== Hive离线缓存相关 =====

  /// 获取Hive Box
  Future<Box> _getBox(String boxName) async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox(boxName);
    }
    return Hive.box(boxName);
  }

  /// 缓存作品列表到Hive
  Future<void> cacheWorks(List<Map<String, dynamic>> works) async {
    final box = await _getBox(AppConstants.hiveBoxWorks);
    await box.put('works_list', jsonEncode(works));
    await box.put('works_cached_at', DateTime.now().toIso8601String());
  }

  /// 获取缓存的作品列表
  Future<List<Map<String, dynamic>>> getCachedWorks() async {
    final box = await _getBox(AppConstants.hiveBoxWorks);
    final cached = box.get('works_list') as String?;
    if (cached == null) return [];
    final list = jsonDecode(cached) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  /// 缓存荣誉列表到Hive
  Future<void> cacheHonors(List<Map<String, dynamic>> honors) async {
    final box = await _getBox(AppConstants.hiveBoxHonors);
    await box.put('honors_list', jsonEncode(honors));
    await box.put('honors_cached_at', DateTime.now().toIso8601String());
  }

  /// 获取缓存的荣誉列表
  Future<List<Map<String, dynamic>>> getCachedHonors() async {
    final box = await _getBox(AppConstants.hiveBoxHonors);
    final cached = box.get('honors_list') as String?;
    if (cached == null) return [];
    final list = jsonDecode(cached) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  /// 清除指定Box的缓存
  Future<void> clearCache(String boxName) async {
    final box = await _getBox(boxName);
    await box.clear();
  }

  /// 清除所有缓存
  Future<void> clearAllCache() async {
    await clearCache(AppConstants.hiveBoxWorks);
    await clearCache(AppConstants.hiveBoxHonors);
  }
}
