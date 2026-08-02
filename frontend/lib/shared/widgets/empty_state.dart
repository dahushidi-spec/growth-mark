import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// EmptyState - 空状态展示组件
/// 用于列表为空时显示图标、提示文字和可选操作按钮
class EmptyState extends StatelessWidget {
  /// 空状态图标
  final IconData icon;

  /// 标题文字
  final String title;

  /// 描述文字
  final String? description;

  /// 操作按钮文字
  final String? actionText;

  /// 操作按钮回调
  final VoidCallback? onAction;

  /// 自定义图标颜色
  final Color? iconColor;

  /// 自定义图标大小
  final double iconSize;

  /// 是否使用emoji替代图标
  final String? emoji;

  const EmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.description,
    this.actionText,
    this.onAction,
    this.iconColor,
    this.iconSize = 64,
    this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 图标或Emoji
            if (emoji != null)
              Text(
                emoji!,
                style: TextStyle(fontSize: iconSize),
              )
            else
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: (iconColor ?? AppTheme.accent).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: iconSize,
                  color: iconColor ?? AppTheme.accent,
                ),
              ),
            const SizedBox(height: 24),
            // 标题
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: 'NotoSansSC',
                color: AppTheme.ink,
              ),
              textAlign: TextAlign.center,
            ),
            // 描述
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description!,
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'NotoSansSC',
                  color: AppTheme.muted,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            // 操作按钮
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: Text(actionText!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
