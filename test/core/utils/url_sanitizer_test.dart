import 'package:flutter_test/flutter_test.dart';
import 'package:open_vts/core/utils/url_sanitizer.dart';

void main() {
  group('UrlSanitizer', () {
    test('cleans markdown link syntax', () {
      expect(
        UrlSanitizer.sanitizeUrl(
          '[https://app.smartavl.net/](https://app.smartavl.net/)',
        ),
        'https://app.smartavl.net/',
      );
      expect(
        UrlSanitizer.sanitizeUrl('[https://fleet.company.com/api]'),
        'https://fleet.company.com/api',
      );
    });

    test('adds https:// scheme if missing', () {
      expect(
        UrlSanitizer.sanitizeUrl('company-a.com/api'),
        'https://company-a.com/api',
      );
      expect(
        UrlSanitizer.sanitizeUrl('localhost:3000/api'),
        'https://localhost:3000/api',
      );
    });

    test('preserves http:// scheme if explicitly specified', () {
      expect(
        UrlSanitizer.sanitizeUrl('http://10.0.2.2:3000/api'),
        'http://10.0.2.2:3000/api',
      );
    });

    test('strips whitespace, surrounding quotes, brackets, and trailing slashes', () {
      expect(
        UrlSanitizer.sanitizeUrl('  "https://myserver.com/api///"  '),
        'https://myserver.com/api',
      );
      expect(
        UrlSanitizer.sanitizeUrl("<https://myserver.com/api>"),
        'https://myserver.com/api',
      );
      expect(
        UrlSanitizer.sanitizeUrl("(https://myserver.com/api/)"),
        'https://myserver.com/api',
      );
    });

    test('validates valid URLs', () {
      expect(UrlSanitizer.isValidUrl('https://app.smartavl.net/'), isTrue);
      expect(UrlSanitizer.isValidUrl('https://company-a.com/api'), isTrue);
      expect(UrlSanitizer.isValidUrl('http://localhost:3000/api'), isTrue);
      expect(UrlSanitizer.isValidUrl('http://10.0.2.2:3000/api'), isTrue);
    });

    test('rejects invalid URLs', () {
      expect(UrlSanitizer.isValidUrl(''), isFalse);
      expect(UrlSanitizer.isValidUrl('   '), isFalse);
      expect(UrlSanitizer.isValidUrl('ftp://server.com'), isFalse);
      expect(UrlSanitizer.isValidUrl('not-a-valid-url'), isFalse);
    });

    test('validateUrl returns appropriate error messages', () {
      expect(UrlSanitizer.validateUrl(''), 'Please enter a server URL');
      expect(
        UrlSanitizer.validateUrl('not a url'),
        'Please enter a valid HTTP or HTTPS server URL',
      );
      expect(UrlSanitizer.validateUrl('https://app.smartavl.net/'), isNull);
    });
  });
}

