import 'package:flutter/material.dart';

import '../../../app/theme/color_tokens.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'I+',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                letterSpacing: 4,
              ),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(color: AppColors.ink),
          ],
        ),
      ),
    );
  }
}
