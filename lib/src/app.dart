import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'db.dart';
import 'repos.dart';
import 'state.dart';
import 'ui.dart';

class AppBootstrap extends StatelessWidget {
  const AppBootstrap({super.key});

  Future<AppDependencies> _init() async {
    final db = await AppDatabase.open();
    final repos = AppRepositories(db: db);
    await repos.settings.ensureDefaults();
    return AppDependencies(db: db, repos: repos);
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      return MaterialApp(
        title: 'QuickCards',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        ),
        home: Scaffold(
          appBar: AppBar(title: const Text('QuickCards')),
          body: const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text(
                '当前运行目标不支持本地数据库（web/windows）。\n\n请用 Android 设备/模拟器运行：\n- 连接手机：开启开发者选项与 USB 调试\n- 或在 Android Studio 的 Device Manager 创建并启动模拟器',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return FutureBuilder<AppDependencies>(
      future: _init(),
      builder: (context, snapshot) {
        final deps = snapshot.data;
        if (deps == null) {
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(snapshot.hasError ? '初始化失败' : '初始化中...'),
                  ],
                ),
              ),
            ),
          );
        }

        return MultiProvider(
          providers: [
            Provider.value(value: deps.repos),
            ChangeNotifierProvider(
              create: (_) => SettingsModel(repos: deps.repos)..load(),
            ),
            ChangeNotifierProvider(
              create: (_) => DecksModel(repos: deps.repos)..refresh(),
            ),
            ChangeNotifierProvider(
              create: (_) => StatsModel(repos: deps.repos)..refresh(),
            ),
          ],
          child: MaterialApp(
            title: 'QuickCards',
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
            ),
            home: const HomeShell(),
          ),
        );
      },
    );
  }
}

class AppDependencies {
  AppDependencies({required this.db, required this.repos});

  final AppDatabase db;
  final AppRepositories repos;
}
