import 'package:flutter/material.dart';
import 'package:video_slimmer/src/services/permission_service.dart';
import 'src/constants/app_constants.dart';
import 'src/constants/app_theme.dart';
import 'src/libs/localization.dart';
import 'src/screens/home_screen.dart';
import 'src/services/localization_service.dart';
import 'src/widgets/permission_denied_screen.dart';
import 'src/widgets/error_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化国际化
  await LocalizationService.instance.initialize();
  runApp(const VideoSlimmerApp());
}

class VideoSlimmerApp extends StatelessWidget {
  const VideoSlimmerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: tr(AppConstants.appName),
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
      future: PermissionService.requestStoragePermission(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          print('snapshot.error: ${snapshot.error}');
          return ErrorScreen(
            errorMessage: snapshot.error?.toString() ?? tr('未知错误'),
            brandGold: AppTheme.prosperityGold,
            brandGray: AppTheme.prosperityGray,
          );
        }

        final hasPermission = snapshot.data ?? false;
        if (hasPermission) {
          return const HomeScreen();
        } else {
          return const PermissionDeniedScreen();
        }
      },
    );
  }
}
