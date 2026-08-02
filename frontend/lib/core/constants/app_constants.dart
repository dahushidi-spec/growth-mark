/// AppConstants - 应用全局常量定义
class AppConstants {
  AppConstants._();

  // ===== 应用信息 =====
  static const String appName = '成长印记';
  static const String appNameEn = 'Growth Mark';
  static const String appVersion = '1.0.0';
  static const String appSlogan = '记录每一个成长瞬间';

  // ===== API配置 =====
  // 相对路径：通过 nginx 反向代理访问后端，避免跨域
  // 注意末尾斜杠不可省略（Dio 以此拼接路径）
  static const String apiBaseUrl = '/api/v1/';
  static const int connectTimeout = 15000; // 15秒
  static const int receiveTimeout = 30000; // 30秒
  static const int sendTimeout = 30000; // 30秒

  // ===== Mock 数据开关 =====
  /// 设为 true 可在后端未启动时使用 Mock 数据进行前端开发
  static const bool useMockData = false;

  // ===== 分页配置 =====
  static const int pageSize = 20;
  static const int defaultPage = 1;

  // ===== 存储Key =====
  static const String storageToken = 'auth_token';
  static const String storageRefreshToken = 'auth_refresh_token';
  static const String storageUserId = 'user_id';
  static const String storageCurrentChildId = 'current_child_id';
  static const String storageThemeMode = 'theme_mode';
  static const String storageLocale = 'app_locale';

  // ===== Hive Box名称 =====
  static const String hiveBoxWorks = 'works_cache';
  static const String hiveBoxHonors = 'honors_cache';
  static const String hiveBoxSettings = 'settings';

  // ===== 路由名称 =====
  static const String routeLogin = 'login';
  static const String routeRegister = 'register';
  static const String routeMain = 'main';
  static const String routeTimeline = 'timeline';
  static const String routeHonors = 'honors';
  static const String routeUpload = 'upload';
  static const String routeStory = 'story';
  static const String routeProfile = 'profile';
  static const String routeWorkDetail = 'work-detail';
  static const String routeHonorDetail = 'honor-detail';
  static const String routeFamily = 'family';
  static const String routeSettings = 'settings';

  // ===== 作品分类 =====
  static const List<String> workCategories = [
    '绘画',
    '书法',
    '手工',
    '音乐',
    '写作',
    '其他',
  ];

  // ===== 荣誉级别 =====
  static const List<String> honorLevels = [
    '国家级',
    '省级',
    '市级',
    '校级',
  ];

  // ===== 性别 =====
  static const String genderMale = '男';
  static const String genderFemale = '女';

  // ===== 图片相关 =====
  static const int maxImageSize = 10 * 1024 * 1024; // 10MB
  static const int imageQuality = 85;
  static const List<String> supportedImageTypes = ['jpg', 'jpeg', 'png', 'webp'];

  // ===== 验证码 =====
  static const int smsCountdown = 60; // 60秒倒计时
  static const int smsLength = 6; // 6位验证码
}
