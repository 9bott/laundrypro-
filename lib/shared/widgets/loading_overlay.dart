import 'package:flutter/material.dart';

import 'app_logo_loader.dart';

/// Full-screen or stacked loading indicator.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black26,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogoLoader(size: 120, background: Colors.white),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(message!),
            ],
          ],
        ),
      ),
    );
  }
}
