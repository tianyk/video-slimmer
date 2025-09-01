import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_slimmer/src/services/permission_service.dart';
import 'src/constants/app_constants.dart';
import 'src/constants/app_theme.dart';
import 'src/screens/home_screen.dart';

void main() {
  runApp(const ProviderScope(child: VideoSlimmerApp()));
}

class VideoSlimmerApp extends StatelessWidget {
  const VideoSlimmerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const HomeScreenWrapper(),
    );
  }
}

class HomeScreenWrapper extends StatelessWidget {
  const HomeScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: PermissionService.requestStoragePermission(), // 检查并请求权限
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return const HomeScreen();
      },
    );
  }
}