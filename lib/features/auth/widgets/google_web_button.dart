import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;

class GoogleWebButton extends StatefulWidget {
  const GoogleWebButton({
    super.key,
    required this.onServerAuthCode,
    this.clientId,
    this.serverClientId,
    this.enabled = true,
  });

  final ValueChanged<String> onServerAuthCode;
  final String? clientId;
  final String? serverClientId;
  final bool enabled;

  @override
  State<GoogleWebButton> createState() => _GoogleWebButtonState();
}

class _GoogleWebButtonState extends State<GoogleWebButton> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _subscription;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final googleSignIn = GoogleSignIn.instance;

    await googleSignIn.initialize(
      clientId: widget.clientId,
      serverClientId: widget.serverClientId,
    );

    _subscription = googleSignIn.authenticationEvents.listen(
      _handleAuthenticationEvent,
    );

    if (mounted) {
      setState(() {
        _initialized = true;
      });
    }
  }

  Future<void> _handleAuthenticationEvent(
    GoogleSignInAuthenticationEvent event,
  ) async {
    if (event is! GoogleSignInAuthenticationEventSignIn) {
      return;
    }

    try {
      final authorization =
          await event.user.authorizationClient.authorizeServer(
        const <String>[],
      );

      final serverAuthCode = authorization?.serverAuthCode;

      if (serverAuthCode == null || serverAuthCode.trim().isEmpty) {
        return;
      }

      widget.onServerAuthCode(serverAuthCode);
    } catch (error) {
      debugPrint('Web Google authorization error: $error');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || !_initialized) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 46,
      width: double.infinity,
      child: google_web.renderButton(),
    );
  }
}
