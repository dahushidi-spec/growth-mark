import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/network/sync_controller.dart';
import '../../core/network/upload_queue.dart';
import '../../core/providers/providers.dart';
import '../../models/work.dart';
import '../../shared/widgets/loading_widget.dart';
import '../../shared/widgets/micro_animations.dart';
import '../timeline/timeline_page.dart';

/// 上传类型枚举
enum UploadType { work, honor }

/// 上传页面状态
class UploadState {
  final UploadType type;
  final List<XFile> images;
  final String? selectedCategory;
  final bool isAiRecognizing;

  /// AI 识别返回的分类建议
  final String? aiCategorySuggestion;

  /// AI 识别返回的标签建议列表
  final List<String> aiTags;

  /// 用户选中的标签列表
  final List<String> selectedTags;

  /// AI 识别返回的描述建议
  final String? aiDescriptionSuggestion;

  /// AI 识别置信度（0-1）
  final double? aiConfidence;

  /// AI 识别错误信息（识别失败时设置）
  final String? aiError;

  /// 旧字段保留兼容（已废弃，由结构化字段替代）
  final String? aiResult;
  final DateTime? selectedDate;
  final bool isSubmitting;
  final String? selectedChildId;

  const UploadState({
    this.type = UploadType.work,
    this.images = const [],
    this.selectedCategory,
    this.isAiRecognizing = false,
    this.aiCategorySuggestion,
    this.aiTags = const [],
    this.selectedTags = const [],
    this.aiDescriptionSuggestion,
    this.aiConfidence,
    this.aiError,
    this.aiResult,
    this.selectedDate,
    this.isSubmitting = false,
    this.selectedChildId,
  });

  /// 是否有 AI 识别结果
  bool get hasAiResult =>
      aiCategorySuggestion != null ||
      aiTags.isNotEmpty ||
      aiDescriptionSuggestion != null;

  UploadState copyWith({
    UploadType? type,
    List<XFile>? images,
    String? selectedCategory,
    bool? isAiRecognizing,
    String? aiCategorySuggestion,
    List<String>? aiTags,
    List<String>? selectedTags,
    String? aiDescriptionSuggestion,
    double? aiConfidence,
    String? aiError,
    String? aiResult,
    DateTime? selectedDate,
    bool? isSubmitting,
    String? selectedChildId,
    // 用于显式清空 nullable 字段的标志
    bool clearAiError = false,
  }) {
    return UploadState(
      type: type ?? this.type,
      images: images ?? this.images,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      isAiRecognizing: isAiRecognizing ?? this.isAiRecognizing,
      aiCategorySuggestion: aiCategorySuggestion ?? this.aiCategorySuggestion,
      aiTags: aiTags ?? this.aiTags,
      selectedTags: selectedTags ?? this.selectedTags,
      aiDescriptionSuggestion:
          aiDescriptionSuggestion ?? this.aiDescriptionSuggestion,
      aiConfidence: aiConfidence ?? this.aiConfidence,
      aiError: clearAiError ? null : (aiError ?? this.aiError),
      aiResult: aiResult ?? this.aiResult,
      selectedDate: selectedDate ?? this.selectedDate,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      selectedChildId: selectedChildId ?? this.selectedChildId,
    );
  }
}

/// 上传状态管理器
class UploadNotifier extends StateNotifier<UploadState> {
  final ImagePicker _picker = ImagePicker();
  final ApiClient _apiClient;

  UploadNotifier(this._apiClient) : super(const UploadState());

  /// 切换上传类型
  void switchType(UploadType type) {
    state = state.copyWith(type: type);
  }

  /// 从相机拍照
  Future<void> pickFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: AppConstants.imageQuality,
      );
      if (image != null) {
        state = state.copyWith(images: [...state.images, image]);
      }
    } catch (e) {
      debugPrint('拍照失败: $e');
    }
  }

  /// 从相册选择
  Future<void> pickFromGallery() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: AppConstants.imageQuality,
      );
      if (images.isNotEmpty) {
        state = state.copyWith(images: [...state.images, ...images]);
      }
    } catch (e) {
      debugPrint('选择图片失败: $e');
    }
  }

  /// 删除图片
  void removeImage(int index) {
    final images = List<XFile>.from(state.images);
    images.removeAt(index);
    state = state.copyWith(images: images);
  }

  /// 选择分类
  void selectCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  /// 选择日期
  void selectDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
  }

  /// 选择孩子
  void selectChild(String childId) {
    state = state.copyWith(selectedChildId: childId);
  }

  /// 切换标签选中状态（点击 chip）
  void toggleTag(String tag) {
    final selected = List<String>.from(state.selectedTags);
    if (selected.contains(tag)) {
      selected.remove(tag);
    } else {
      selected.add(tag);
    }
    state = state.copyWith(selectedTags: selected);
  }

  /// 手动添加新标签到 AI 标签列表，并自动选中
  void addTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) return;
    final tags = List<String>.from(state.aiTags);
    if (!tags.contains(trimmed)) {
      tags.add(trimmed);
    }
    final selected = List<String>.from(state.selectedTags);
    if (!selected.contains(trimmed)) {
      selected.add(trimmed);
    }
    state = state.copyWith(aiTags: tags, selectedTags: selected);
  }

  /// 删除标签（从 AI 标签列表和选中列表中同时移除）
  void removeTag(String tag) {
    final tags = List<String>.from(state.aiTags)..remove(tag);
    final selected = List<String>.from(state.selectedTags)..remove(tag);
    state = state.copyWith(aiTags: tags, selectedTags: selected);
  }

  /// AI识别
  /// 解析后端返回字段：category / tags / description_suggestion / confidence
  /// 失败时设置 aiError 字段，不阻塞上传流程
  Future<void> aiRecognize() async {
    if (state.images.isEmpty) return;

    state = state.copyWith(
      isAiRecognizing: true,
      clearAiError: true,
    );

    try {
      final firstImage = state.images.first;
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          await firstImage.readAsBytes(),
          filename: firstImage.name,
        ),
      });
      // 先上传图片再识别
      final uploadResp = await _apiClient.post(
        ApiEndpoints.uploadImage,
        data: formData,
      );
      final imageUrl =
          (uploadResp.data['data'] as Map<String, dynamic>)['url'] as String;

      final aiResp = await _apiClient.post(
        ApiEndpoints.aiRecognize,
        data: {'image_url': imageUrl},
      );
      final aiData = aiResp.data['data'] as Map<String, dynamic>;

      // 解析 tags（兼容 List<String> 与 List<Map>）
      final tagsRaw = aiData['tags'];
      final List<String> tags = <String>[];
      if (tagsRaw is List) {
        for (final t in tagsRaw) {
          if (t is String) {
            tags.add(t);
          } else if (t is Map<String, dynamic>) {
            final name = t['tag_name'];
            if (name is String && name.isNotEmpty) {
              tags.add(name);
            }
          }
        }
      }

      // 解析 description_suggestion（注意字段名）
      final descriptionSuggestion =
          aiData['description_suggestion'] as String? ??
              aiData['description'] as String?;

      // 解析置信度（兼容 0-1 与 0-100）
      double? confidence;
      final confRaw = aiData['confidence'];
      if (confRaw is num) {
        confidence = confRaw.toDouble();
        if (confidence > 1) {
          confidence = confidence / 100;
        }
      }

      // 解析分类
      final category = aiData['category'] as String?;

      // 默认选中所有 AI 标签
      final selectedTags = List<String>.from(tags);

      state = state.copyWith(
        isAiRecognizing: false,
        aiCategorySuggestion: category,
        aiTags: tags,
        selectedTags: selectedTags,
        aiDescriptionSuggestion: descriptionSuggestion,
        aiConfidence: confidence,
        aiError: null,
        // 同步选中 AI 推荐分类
        selectedCategory: category ?? state.selectedCategory,
        aiResult: 'AI 识别完成',
      );
    } catch (e) {
      // AI 接口未配置时降级为友好提示，不阻塞上传流程
      state = state.copyWith(
        isAiRecognizing: false,
        aiError: 'AI 识别暂不可用，请手动填写',
        aiResult: null,
      );
    }
  }

  /// 提交保存：上传图片 -> 创建作品/荣誉
  /// 使用 selectedTags 作为 tags
  Future<bool> submit({
    required String title,
    required String description,
  }) async {
    if (state.selectedChildId == null) {
      state = state.copyWith();
      return false;
    }

    state = state.copyWith(isSubmitting: true);

    try {
      // 上传第一张图片作为封面
      String? imageUrl;
      String? thumbnailUrl;
      if (state.images.isNotEmpty) {
        final firstImage = state.images.first;
        final formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(
            await firstImage.readAsBytes(),
            filename: firstImage.name,
          ),
        });
        final uploadResp = await _apiClient.post(
          ApiEndpoints.uploadImage,
          data: formData,
        );
        final uploadData = uploadResp.data['data'] as Map<String, dynamic>;
        imageUrl = uploadData['url'] as String;
        thumbnailUrl = uploadData['thumbnail_url'] as String;
      }

      final createdDate =
          (state.selectedDate ?? DateTime.now()).toIso8601String().split('T')[0];

      if (state.type == UploadType.work) {
        final payload = <String, dynamic>{
          'title': title,
          'category': state.selectedCategory ?? '其他',
          'description': description.isEmpty ? null : description,
          'image_url': imageUrl,
          'thumbnail_url': thumbnailUrl,
          'created_date': createdDate,
          'child_id': int.parse(state.selectedChildId!),
          // 使用用户选中的标签
          'tags': state.selectedTags,
        };
        await _apiClient.post(ApiEndpoints.works, data: payload);
      } else {
        final payload = <String, dynamic>{
          'title': title,
          'level': state.selectedCategory ?? '校级',
          'category': '其他',
          'image_url': imageUrl,
          'award_date': createdDate,
          'description': description.isEmpty ? null : description,
          'child_id': int.parse(state.selectedChildId!),
        };
        await _apiClient.post(ApiEndpoints.honors, data: payload);
      }

      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      debugPrint('提交失败: $e');
      state = state.copyWith(isSubmitting: false);
      return false;
    }
  }

  /// 重置状态
  void reset() {
    state = const UploadState();
  }
}

final uploadProvider =
    StateNotifierProvider<UploadNotifier, UploadState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return UploadNotifier(apiClient);
});

/// UploadPage - 上传页面
class UploadPage extends ConsumerStatefulWidget {
  const UploadPage({super.key});

  @override
  ConsumerState<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends ConsumerState<UploadPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagInputController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  /// 是否显示成功动画（F16）
  bool _showSuccess = false;

  @override
  void initState() {
    super.initState();
    // 加载孩子档案，自动选中第一个或当前孩子
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final childrenAsync = ref.read(childrenProvider);
      final currentChild = ref.read(currentChildProvider).child;
      childrenAsync.whenData((children) {
        if (children.isEmpty) return;
        String? selectedId;
        if (currentChild != null &&
            children.any((c) => c.id == currentChild.id)) {
          selectedId = currentChild.id;
        } else {
          selectedId = children.first.id;
        }
        ref.read(uploadProvider.notifier).selectChild(selectedId);
      });
    });

    // 监听 AI 描述建议变化，预填到描述输入框
    ref.listenManual(uploadProvider.select((s) => s.aiDescriptionSuggestion),
        (previous, next) {
      if (next != null && next.isNotEmpty && _descriptionController.text.isEmpty) {
        _descriptionController.text = next;
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  /// 选择日期
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppTheme.accent,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      ref.read(uploadProvider.notifier).selectDate(picked);
    }
  }

  /// 保存
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final state = ref.read(uploadProvider);
    if (state.images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请至少上传一张图片'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    if (state.selectedChildId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先在个人中心创建孩子档案'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    final success = await ref.read(uploadProvider.notifier).submit(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
        );

    if (success && mounted) {
      // F16: 显示成功对勾动画 0.8 秒后再跳转
      setState(() => _showSuccess = true);
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      ref.read(uploadProvider.notifier).reset();
      _titleController.clear();
      _descriptionController.clear();
      setState(() => _showSuccess = false);
      // 刷新时间线，使 IndexedStack 保活的 Tab 也能展示新作品
      ref.invalidate(timelineProvider);
      context.go('/main/timeline');
    } else if (mounted) {
      // F15: 离线时入队，等网络恢复后重试
      final isOnline = await ConnectivityService.instance.isOnline;
      if (!isOnline) {
        await _enqueueUploadTask(state);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('当前离线，已加入上传队列，网络恢复后自动同步'),
            backgroundColor: AppTheme.warningYellow,
          ),
        );
        ref.read(uploadProvider.notifier).reset();
        _titleController.clear();
        _descriptionController.clear();
        context.go('/main/timeline');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('保存失败，请稍后重试'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  /// F15: 离线时将上传任务入队
  Future<void> _enqueueUploadTask(UploadState state) async {
    try {
      final task = <String, dynamic>{
        'type': state.type == UploadType.work ? 'work' : 'honor',
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': state.selectedCategory,
        'images_path':
            state.images.map((x) => x.path).toList(),
        'tags': state.selectedTags,
        'created_date':
            (state.selectedDate ?? DateTime.now()).toIso8601String().split('T')[0],
        'child_id': state.selectedChildId,
      };
      await UploadQueueService.instance.enqueue(task);
      // 通知 SyncController 刷新 pendingCount
      ref.read(syncControllerProvider.notifier).notifyEnqueued();
    } catch (e) {
      debugPrint('入队失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(uploadProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('上传记录'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/main/timeline'),
        ),
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 类型切换Tab
                  _buildTypeTab(state.type),
                  const SizedBox(height: 20),
                  // 图片上传区
                  _buildImageSection(state),
                  const SizedBox(height: 20),
                  // AI 识别结果区
                  if (state.hasAiResult || state.aiError != null) ...[
                    _buildAiResultSection(state),
                    const SizedBox(height: 20),
                  ],
                  // 表单
                  _buildForm(state),
                  const SizedBox(height: 32),
                  // 保存按钮
                  _buildSaveButton(state),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          // AI识别中遮罩：使用成长树动效
          if (state.isAiRecognizing) const AiRecognizingLoading(),
          // F16: 保存成功对勾动画遮罩
          if (_showSuccess)
            SuccessCheckAnimation(
              onComplete: () {},
            ),
        ],
      ),
    );
  }

  /// 类型切换Tab
  Widget _buildTypeTab(UploadType type) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bg2,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () =>
                  ref.read(uploadProvider.notifier).switchType(UploadType.work),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: type == UploadType.work
                      ? AppTheme.accent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '🎨 作品',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'NotoSansSC',
                    color: type == UploadType.work
                        ? Colors.white
                        : AppTheme.muted,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => ref
                  .read(uploadProvider.notifier)
                  .switchType(UploadType.honor),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: type == UploadType.honor
                      ? AppTheme.accent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '🏆 荣誉',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'NotoSansSC',
                    color: type == UploadType.honor
                        ? Colors.white
                        : AppTheme.muted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 图片上传区
  Widget _buildImageSection(UploadState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '上传图片',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'NotoSansSC',
                color: AppTheme.ink,
              ),
            ),
            if (state.images.isNotEmpty)
              TextButton.icon(
                onPressed: state.isAiRecognizing
                    ? null
                    : ref.read(uploadProvider.notifier).aiRecognize,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('AI识别'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // 图片网格
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            // 已选图片
            ...state.images.asMap().entries.map((entry) {
              return _buildImageItem(entry.key, entry.value);
            }),
            // 添加按钮
            if (state.images.length < 9) _buildAddButton(),
          ],
        ),
      ],
    );
  }

  /// AI 识别结果展示区
  /// 包含：分类建议、标签建议、描述建议、置信度
  /// 失败降级时显示友好提示
  Widget _buildAiResultSection(UploadState state) {
    // 识别失败降级提示
    if (state.aiError != null && !state.hasAiResult) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.warningYellow.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.warningYellow.withOpacity(0.4),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline,
                size: 18, color: AppTheme.warningYellow),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.aiError!,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.ink,
                  fontFamily: 'NotoSansSC',
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行：AI 识别结果 + 置信度
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: AppTheme.accent),
              const SizedBox(width: 6),
              Text(
                'AI 识别结果',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'NotoSansSC',
                  color: AppTheme.accent,
                ),
              ),
              const Spacer(),
              if (state.aiConfidence != null)
                Text(
                  '置信度 ${(state.aiConfidence! * 100).round()}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.muted,
                    fontFamily: 'NotoSansSC',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // 分类建议
          if (state.aiCategorySuggestion != null &&
              state.aiCategorySuggestion!.isNotEmpty) ...[
            _buildAiSuggestionLabel('分类建议'),
            const SizedBox(height: 6),
            _buildCategorySuggestionChip(state),
            const SizedBox(height: 12),
          ],
          // 标签建议
          if (state.aiTags.isNotEmpty) ...[
            _buildAiSuggestionLabel('标签建议（点击切换选中）'),
            const SizedBox(height: 6),
            _buildTagsEditor(state),
            const SizedBox(height: 8),
            _buildAddTagInput(),
            const SizedBox(height: 12),
          ],
          // 描述建议
          if (state.aiDescriptionSuggestion != null &&
              state.aiDescriptionSuggestion!.isNotEmpty) ...[
            _buildAiSuggestionLabel('描述建议（已填入下方描述框，可编辑）'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                state.aiDescriptionSuggestion!,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.ink,
                  fontFamily: 'NotoSansSC',
                  height: 1.6,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// AI 小节标题
  Widget _buildAiSuggestionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        fontFamily: 'NotoSansSC',
        color: AppTheme.muted,
      ),
    );
  }

  /// 分类建议 Chip：点击选中该分类
  Widget _buildCategorySuggestionChip(UploadState state) {
    final suggestion = state.aiCategorySuggestion!;
    final isSelected = state.selectedCategory == suggestion;
    return GestureDetector(
      onTap: () =>
          ref.read(uploadProvider.notifier).selectCategory(suggestion),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.accent : AppTheme.accent.withOpacity(0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.auto_awesome,
              size: 14,
              color: isSelected ? Colors.white : AppTheme.accent,
            ),
            const SizedBox(width: 6),
            Text(
              suggestion,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'NotoSansSC',
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 标签编辑器：每个标签 chip 可点击切换选中，长按删除
  Widget _buildTagsEditor(UploadState state) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: state.aiTags.map((tag) {
        final isSelected = state.selectedTags.contains(tag);
        return GestureDetector(
          onTap: () => ref.read(uploadProvider.notifier).toggleTag(tag),
          onLongPress: () {
            // 长按删除
            ref.read(uploadProvider.notifier).removeTag(tag);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('已删除标签 "$tag"'),
                duration: const Duration(milliseconds: 800),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.accent2 : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? AppTheme.accent2
                    : AppTheme.rule,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? Icons.check : Icons.label_outline,
                  size: 12,
                  color: isSelected ? Colors.white : AppTheme.muted,
                ),
                const SizedBox(width: 4),
                Text(
                  '#$tag',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'NotoSansSC',
                    color: isSelected ? Colors.white : AppTheme.ink,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 添加新标签输入框 + 添加按钮
  Widget _buildAddTagInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _tagInputController,
            decoration: const InputDecoration(
              hintText: '添加自定义标签',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              prefixIcon: Icon(Icons.add, size: 18),
            ),
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'NotoSansSC',
            ),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                ref.read(uploadProvider.notifier).addTag(value);
                _tagInputController.clear();
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 40,
          child: OutlinedButton(
            onPressed: () {
              final value = _tagInputController.text;
              if (value.trim().isNotEmpty) {
                ref.read(uploadProvider.notifier).addTag(value);
                _tagInputController.clear();
              }
            },
            child: const Text('添加'),
          ),
        ),
      ],
    );
  }

  /// 图片项
  Widget _buildImageItem(int index, XFile image) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 100,
            height: 100,
            child: FutureBuilder<Uint8List>(
              future: image.readAsBytes(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    color: AppTheme.bg2,
                    child: const Icon(Icons.hourglass_empty, color: AppTheme.muted),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return Container(
                    color: AppTheme.bg2,
                    child: const Icon(Icons.image, color: AppTheme.muted),
                  );
                }
                return Image.memory(
                  snapshot.data!,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, child) => Container(
                    width: 100,
                    height: 100,
                    color: AppTheme.bg2,
                    child: const Icon(Icons.image, color: AppTheme.muted),
                  ),
                );
              },
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => ref.read(uploadProvider.notifier).removeImage(index),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 添加按钮
  Widget _buildAddButton() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppTheme.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.rule,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_photo_alternate,
                color: AppTheme.muted, size: 32),
            onSelected: (value) {
              if (value == 'camera') {
                ref.read(uploadProvider.notifier).pickFromCamera();
              } else {
                ref.read(uploadProvider.notifier).pickFromGallery();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'camera',
                child: Row(
                  children: [
                    Icon(Icons.camera_alt, size: 20),
                    SizedBox(width: 8),
                    Text('拍照'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'gallery',
                child: Row(
                  children: [
                    Icon(Icons.photo_library, size: 20),
                    SizedBox(width: 8),
                    Text('从相册选择'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '添加图片',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.muted,
              fontFamily: 'NotoSansSC',
            ),
          ),
        ],
      ),
    );
  }

  /// 表单
  Widget _buildForm(UploadState state) {
    final categories = state.type == UploadType.work
        ? AppConstants.workCategories
        : AppConstants.honorLevels;

    final label = state.type == UploadType.work ? '作品名称' : '荣誉名称';
    final descLabel = state.type == UploadType.work ? '创作故事' : '获奖说明';
    final catLabel = state.type == UploadType.work ? '分类' : '级别';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 名称
        TextFormField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: label,
            hintText: '请输入$label',
            prefixIcon: const Icon(Icons.title),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '请输入$label';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        // 分类选择
        Text(
          catLabel,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFamily: 'NotoSansSC',
            color: AppTheme.ink,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((category) {
            final isSelected = state.selectedCategory == category;
            return GestureDetector(
              onTap: () =>
                  ref.read(uploadProvider.notifier).selectCategory(category),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.accent : AppTheme.bg2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppTheme.accent : AppTheme.rule,
                  ),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'NotoSansSC',
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? Colors.white : AppTheme.ink,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        // 日期选择
        GestureDetector(
          onTap: _selectDate,
          child: AbsorbPointer(
            child: TextFormField(
              decoration: InputDecoration(
                labelText: '日期',
                hintText: '请选择日期',
                prefixIcon: const Icon(Icons.calendar_today),
                suffixIcon: const Icon(Icons.arrow_drop_down),
              ),
              controller: TextEditingController(
                text: state.selectedDate != null
                    ? '${state.selectedDate!.year}年${state.selectedDate!.month}月${state.selectedDate!.day}日'
                    : '',
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 描述（AI 建议会预填）
        TextFormField(
          controller: _descriptionController,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: descLabel,
            hintText: '请输入$descLabel...',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  /// 保存按钮（F16：TapScaleEffect 点击缩放反馈）
  /// ElevatedButton 的 onPressed 设为 null，由 TapScaleEffect 统一处理点击，
  /// 避免双重手势冲突；disabled 状态通过 IgnorePointer 控制。
  Widget _buildSaveButton(UploadState state) {
    final isDisabled = state.isSubmitting;
    return SizedBox(
      height: 52,
      child: TapScaleEffect(
        onTap: isDisabled ? null : _handleSave,
        child: IgnorePointer(
          ignoring: isDisabled,
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: state.isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('保存'),
          ),
        ),
      ),
    );
  }
}
