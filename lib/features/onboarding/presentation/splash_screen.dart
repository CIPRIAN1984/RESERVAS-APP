import 'package:flutter/material.dart';
import 'package:itaca/app/theme/app_palette.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'I+',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: context.paleta.ink,
                letterSpacing: 4,
              ),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(color: context.paleta.ink),
          ],
        ),
      ),
    );
  }
}
