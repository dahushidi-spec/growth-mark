import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/app.dart';

Future<void> main() async {
  // 确保Flutter绑定初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化Hive本地数据库
  await Hive.initFlutter();
  // 打开作品离线缓存Box
  await Hive.openBox('works_cache');
  // 打开荣誉离线缓存Box
  await Hive.openBox('honors_cache');
  // 打开设置Box
  await Hive.openBox('settings');

  runApp(
    // 使用ProviderScope包裹整个App，启用Riverpod状态管理
    const ProviderScope(
      child: GrowthMarkApp(),
    ),
  );
}
