/// ApiEndpoints - API端点路径常量定义
class ApiEndpoints {
  ApiEndpoints._();

  // ===== 认证相关 =====
  static const String register = 'auth/register';
  static const String login = 'auth/login';
  static const String refresh = 'auth/refresh';
  static const String logout = 'auth/logout';
  static const String sendSms = 'auth/sms/send';
  static const String verifySms = 'auth/sms/verify';

  // ===== 用户相关 =====
  static const String userProfile = 'auth/me';
  static const String updateUser = 'users/me';
  static const String updateAvatar = 'users/avatar';

  // ===== 孩子档案 =====
  static const String children = 'children';
  static String childDetail(String id) => 'children/$id';
  static const String switchChild = 'children/switch';

  // ===== 作品相关 =====
  static const String worksTimeline = 'works/timeline';
  static const String works = 'works';
  static String workDetail(String id) => 'works/$id';
  static String workLike(String id) => 'works/$id/like';
  static String workComment(String id) => 'works/$id/comments';

  // ===== 荣誉相关 =====
  static const String honors = 'honors';
  static const String honorsStats = 'honors/stats';
  static String honorDetail(String id) => 'honors/$id';

  // ===== AI识别 =====
  static const String aiRecognize = 'ai/recognize';
  static const String aiRecognizeAsync = 'ai/recognize/async';
  static const String aiTaskStatus = 'ai/tasks';
  static String aiTaskDetail(String taskId) => 'ai/tasks/$taskId';
  static const String aiReport = 'ai/report';
  static const String aiGenerateStory = 'ai/generate-story';

  // ===== 家庭空间 =====
  static const String families = 'families';
  static const String familyCreate = 'families/create';
  static const String familyJoin = 'families/join';
  static const String familyMembers = 'families/members';
  static String familyDetail(String id) => 'families/$id';
  static String familyRemoveMember(String familyId, String userId) =>
      'families/$familyId/members/$userId';

  // ===== 分享相关 =====
  static const String shareCard = 'shares/card';
  static const String shares = 'shares';
  static String shareVerify(String id) => 'shares/$id/verify';
  static String shareDetail(String id) => 'shares/$id';

  // ===== 成长故事报告 =====
  static const String reports = 'reports';
  static const String reportsGenerate = 'reports/generate';
  static String reportDetail(String id) => 'reports/$id';

  // ===== 文件上传 =====
  static const String uploadImage = 'upload/image';
  static const String uploadFile = 'upload/file';
}
