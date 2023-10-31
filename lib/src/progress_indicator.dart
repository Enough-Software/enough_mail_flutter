import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Displays progress in a platform specific manner
class PlatformProgressIndicator extends StatelessWidget {
  /// Creates a new progress indicator
  const PlatformProgressIndicator({super.key});

  @override
  Widget build(BuildContext context) =>
      (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS)
          ? const CupertinoActivityIndicator()
          : const CircularProgressIndicator();
}
