import 'package:flutter/material.dart';

class GoogleWebButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
