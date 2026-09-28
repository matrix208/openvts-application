import 'package:flutter/material.dart';

/// Web-only Google Sign-In button.
///
/// Google Sign-In for Android/iOS is handled by GoogleAuthService.
/// This widget intentionally contains no direct dependency on
/// google_sign_in_web so mobile release builds do not compile
/// web-only JS interop code.
class GoogleWebButton extends StatelessWidget {
  const GoogleWebButton({
    super.key,
    this.onPressed,
  });

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.login),
      label: const Text('Sign in with Google'),
    );
  }
}
