class UrlSanitizer {
  const UrlSanitizer._();

  /// Cleans and normalizes a server or API URL.
  ///
  /// - Strips Markdown link formatting like `[https://...](https://...)`
  /// - Removes surrounding brackets, parentheses, quotes, and whitespace
  /// - Prepends `https://` if no scheme is provided
  /// - Strips trailing slashes
  static String sanitizeUrl(String? input, {bool appendDefaultScheme = true}) {
    if (input == null) {
      return '';
    }

    var cleaned = input.trim();
    if (cleaned.isEmpty) {
      return '';
    }

    // Handle Markdown link pattern: [text](url) -> extract url
    final markdownLinkMatch =
        RegExp(r'\[.*?\]\((https?://[^\s\)]+)\)').firstMatch(cleaned);
    if (markdownLinkMatch != null) {
      cleaned = markdownLinkMatch.group(1) ?? cleaned;
    } else {
      // Handle Markdown bracketed text: [https://...] -> extract inner URL
      final bracketMatch =
          RegExp(r'\[(https?://[^\]\s]+)\]').firstMatch(cleaned);
      if (bracketMatch != null) {
        cleaned = bracketMatch.group(1) ?? cleaned;
      }
    }

    // Strip remaining brackets, parentheses, quotes, angle brackets
    cleaned = cleaned
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('(', '')
        .replaceAll(')', '')
        .replaceAll('<', '')
        .replaceAll('>', '')
        .replaceAll('"', '')
        .replaceAll("'", '')
        .trim();

    if (cleaned.isEmpty) {
      return '';
    }

    // Prepend default https:// scheme if missing
    if (!cleaned.startsWith(RegExp(r'https?://', caseSensitive: false))) {
      if (appendDefaultScheme) {
        cleaned = 'https://$cleaned';
      }
    }

    // Strip trailing slashes
    cleaned = cleaned.replaceAll(RegExp(r'/+$'), '');

    return cleaned;
  }

  /// Checks whether the sanitized URL is a valid HTTP/HTTPS URL.
  static bool isValidUrl(String? input) {
    if (input == null || input.trim().isEmpty) {
      return false;
    }

    final sanitized = sanitizeUrl(input);
    final uri = Uri.tryParse(sanitized);

    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return false;
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return false;
    }

    if (uri.host.isEmpty) {
      return false;
    }

    if (!uri.host.contains('.')) {
      // Allow localhost or local IP aliases
      if (uri.host != 'localhost' &&
          uri.host != '10.0.2.2' &&
          uri.host != '127.0.0.1') {
        return false;
      }
    }

    return true;
  }

  /// Form validation helper for server URL input fields.
  static String? validateUrl(String? input) {
    if (input == null || input.trim().isEmpty) {
      return 'Please enter a server URL';
    }

    if (!isValidUrl(input)) {
      return 'Please enter a valid HTTP or HTTPS server URL';
    }

    return null;
  }
}

