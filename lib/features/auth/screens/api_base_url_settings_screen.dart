import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/open_vts_colors.dart';
import '../../../core/theme/open_vts_radius.dart';
import '../../../core/theme/open_vts_spacing.dart';
import '../../../core/theme/open_vts_typography.dart';
import '../../../core/utils/url_sanitizer.dart';
import '../../../shared/helpers/toast_helper.dart';
import '../../../shared/widgets/open_vts_button.dart';
import '../../../shared/widgets/open_vts_card.dart';
import '../../../shared/widgets/open_vts_page_scaffold.dart';
import '../../../shared/widgets/open_vts_text_field.dart';
import '../services/auth_service.dart';

class ApiBaseUrlSettingsScreen extends ConsumerStatefulWidget {
  const ApiBaseUrlSettingsScreen({super.key});

  @override
  ConsumerState<ApiBaseUrlSettingsScreen> createState() =>
      _ApiBaseUrlSettingsScreenState();
}

class _ApiBaseUrlSettingsScreenState
    extends ConsumerState<ApiBaseUrlSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _urlController;
  bool _isTesting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final activeUrl = ref.read(apiBaseUrlProvider);
    _urlController = TextEditingController(text: activeUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _errorMessage = null;
    });

    final rawInput = _urlController.text.trim();
    if (rawInput.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a server URL';
      });
      return;
    }

    final sanitizedUrl = UrlSanitizer.sanitizeUrl(rawInput);
    if (!UrlSanitizer.isValidUrl(sanitizedUrl)) {
      setState(() {
        _errorMessage =
            'Invalid URL format. Please enter a valid HTTP or HTTPS server URL.';
      });
      return;
    }

    // Update the text field with the sanitized URL
    _urlController.text = sanitizedUrl;

    setState(() {
      _isTesting = true;
    });

    try {
      // Test server connectivity against {server}/auth/google/client-id
      await AuthService.testServerConnection(sanitizedUrl);

      await ref
          .read(apiBaseUrlProvider.notifier)
          .saveCustomUrl(sanitizedUrl);

      if (!mounted) return;

      ToastHelper.showSuccess('Server connected and saved successfully');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
      });
      ToastHelper.showError(e.message);
    } catch (e) {
      if (!mounted) return;
      final msg = 'Failed to connect to server: $e';
      setState(() {
        _errorMessage = msg;
      });
      ToastHelper.showError(msg);
    } finally {
      if (mounted) {
        setState(() {
          _isTesting = false;
        });
      }
    }
  }

  Future<void> _reset() async {
    setState(() {
      _errorMessage = null;
    });

    await ref.read(apiBaseUrlProvider.notifier).resetToDefault();
    final defaultUrl = ref.read(apiBaseUrlProvider);
    _urlController.text = defaultUrl;

    if (!mounted) return;

    ToastHelper.showSuccess('Reset to default server URL');
  }

  @override
  Widget build(BuildContext context) {
    final activeUrl = ref.watch(apiBaseUrlProvider);
    final defaultUrl =
        ref.read(apiBaseUrlProvider.notifier).defaultUrl;
    final isUsingDefault = activeUrl == defaultUrl;

    return OpenVtsPageScaffold(
      title: 'Server Settings',
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OpenVtsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.dns_outlined,
                          color: OpenVtsColors.brandInk,
                          size: 24,
                        ),
                        const SizedBox(width: OpenVtsSpacing.sm),
                        Text(
                          'Smart AVL Server',
                          style: OpenVtsTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: OpenVtsSpacing.sm),
                    Text(
                      'Configure the API endpoint for your Smart AVL server. '
                      'The application will verify server availability before saving.',
                      style: OpenVtsTypography.body.copyWith(
                        color: OpenVtsColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: OpenVtsSpacing.lg),
                    OpenVtsTextField(
                      label: 'Server API URL',
                      controller: _urlController,
                      hintText: 'https://your-server.com/api',
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.done,
                      prefixIcon: Icons.link_rounded,
                      validator: UrlSanitizer.validateUrl,
                      onFieldSubmitted: (_) => _save(),
                    ),
                    const SizedBox(height: OpenVtsSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(OpenVtsSpacing.sm),
                      decoration: BoxDecoration(
                        color: OpenVtsColors.surface,
                        borderRadius:
                            BorderRadius.circular(OpenVtsRadius.sm),
                        border: Border.all(color: OpenVtsColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isUsingDefault
                                ? Icons.info_outline_rounded
                                : Icons.check_circle_outline_rounded,
                            size: 16,
                            color: isUsingDefault
                                ? OpenVtsColors.textSecondary
                                : OpenVtsColors.success,
                          ),
                          const SizedBox(width: OpenVtsSpacing.xs),
                          Expanded(
                            child: Text(
                              isUsingDefault
                                  ? 'Active: Default ($activeUrl)'
                                  : 'Active: $activeUrl',
                              style: OpenVtsTypography.meta.copyWith(
                                color: OpenVtsColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_errorMessage != null &&
                  _errorMessage!.trim().isNotEmpty) ...[
                const SizedBox(height: OpenVtsSpacing.md),
                Container(
                  padding: const EdgeInsets.all(OpenVtsSpacing.md),
                  decoration: BoxDecoration(
                    color: OpenVtsColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(OpenVtsRadius.md),
                    border: Border.all(
                      color: OpenVtsColors.error.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: OpenVtsColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: OpenVtsSpacing.sm),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: OpenVtsTypography.body.copyWith(
                            color: OpenVtsColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: OpenVtsSpacing.xl),
              OpenVtsButton(
                label: 'Test & Save Server',
                isLoading: _isTesting,
                trailingIcon: Icons.cloud_done_outlined,
                onPressed: _isTesting ? null : _save,
              ),
              const SizedBox(height: OpenVtsSpacing.md),
              OpenVtsButton(
                label: 'Reset to Default',
                variant: OpenVtsButtonVariant.secondary,
                trailingIcon: Icons.refresh_rounded,
                onPressed: _isTesting ? null : _reset,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
