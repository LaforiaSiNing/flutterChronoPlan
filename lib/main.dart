import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 intl 的中文日期格式化
  await initializeDateFormatting('zh_CN', null);
  
  // 桌面端窗口设置
  try {
    await windowManager.ensureInitialized();
    // 默认尺寸紧凑化，允许用户拉得更小
    WindowOptions windowOptions = const WindowOptions(
      size: Size(960, 540),          // 原来 1024×520，改为 960×540（更平衡）
      minimumSize: Size(700, 450),   // 允许更小的窗口
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: "ChronoPlan"
    );
    
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    // 监听窗口关闭事件，显式保存状态后销毁窗口
    windowManager.addListener(WindowListener(
      onWindowClose: () async {
        await windowManager.saveState(); // 先保存当前窗口大小和位置
        await windowManager.destroy();   // 再销毁窗口
      },
    ));

  } catch (e) {
    // 非桌面端/插件不可用时忽略窗口管理异常
    debugPrint('窗口管理器异常: $e');
  }

  runApp(
    const ProviderScope(
      child: ChronoPlanApp(),
    ),
  );
}
