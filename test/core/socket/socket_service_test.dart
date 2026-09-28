import 'package:flutter_test/flutter_test.dart';
import 'package:open_vts/core/socket/socket_service.dart';

void main() {
  group('SocketService', () {
    test('derives namespace URLs from API base without the REST /api path', () {
      expect(
        SocketService.socketUrlForApiBase(
          'https://app.smartavl.net/',
          '/telemetry',
        ),
        'https://app.openvts.io/telemetry',
      );
      expect(
        SocketService.socketUrlForApiBase(
          'https://app.smartavl.net//',
          'notifications',
        ),
        'https://app.openvts.io/notifications',
      );
      expect(
        SocketService.socketUrlForApiBase('/api', '/telemetry'),
        '/telemetry',
      );
    });
  });
}
