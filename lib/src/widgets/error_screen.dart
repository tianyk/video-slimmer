import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../libs/localization.dart';

class ErrorScreen extends StatelessWidget {
  final String errorMessage;
  final Color brandGold;
  final Color brandGray;

  const ErrorScreen({
    super.key,
    required this.errorMessage,
    required this.brandGold,
    required this.brandGray,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              brandGray,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Remix.error_warning_line,
                  size: 80,
                  color: brandGold,
                ),
                const SizedBox(height: 24),
                Text(
                  tr('出错啦'),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: brandGold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  errorMessage,
                  style: TextStyle(
                    fontSize: 16,
                    color: brandGold.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: Text(tr('返回')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
