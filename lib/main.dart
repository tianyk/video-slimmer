import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_slimmer/src/services/permission_service.dart';
import 'src/constants/app_constants.dart';
import 'src/constants/app_theme.dart';
import 'src/cubits/purchase_cubit.dart';
import 'src/libs/localization.dart';
import 'src/libs/logger.dart';
import 'src/screens/home_screen.dart';
import 'src/services/localization_service.dart';
import 'src/widgets/permission_denied_screen.dart';
import 'src/widgets/error_screen.dart';

final _logger = Logger.getLogger();

Future<void> main() async {
  // 全局错误处理
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 捕获 Flutter 框架错误
    FlutterError.onError = (FlutterErrorDetails details) {
      _logger.error(
        'Flutter框架错误',
        error: details.exception,
        stackTrace: details.stack,
      );
    };

    // 初始化国际化
    await LocalizationService.instance.initialize();

    runApp(const VideoSlimmerApp());
  }, (error, stackTrace) {
    // 捕获未处理的异步错误
    _logger.error(
      '未捕获的异步错误',
      error: error,
      stackTrace: stackTrace,
    );
  });
}

class VideoSlimmerApp extends StatelessWidget {
  const VideoSlimmerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PurchaseCubit>(
      create: (_) => PurchaseCubit(),
      child: MaterialApp(
        title: tr(AppConstants.appName),
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const HomeScreenWrapper(),
      ),
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
          _logger.error('权限请求失败', error: snapshot.error);
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
