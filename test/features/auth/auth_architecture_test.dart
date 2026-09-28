import 'package:flutter_test/flutter_test.dart';
import 'package:open_vts/core/providers/core_providers.dart';
import 'package:open_vts/core/storage/local_cache.dart';
import 'package:open_vts/core/storage/storage_keys.dart';
import 'package:open_vts/features/auth/models/login_request.dart';
import 'package:open_vts/features/auth/models/login_response.dart';
import 'package:open_vts/shared/models/user_role.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Auth Architecture & Multi-Server Tests', () {
    test('LoginRequest serializes accurately', () {
      const request = LoginRequest(
        identifier: 'test@example.com',
        password: 'password123',
      );
      final json = request.toJson();
      expect(json['identifier'], 'test@example.com');
      expect(json['password'], 'password123');
    });

    test('LoginResponse deserializes with tokens and user info', () {
      final json = {
        'accessToken': 'access-token-123',
        'refreshToken': 'refresh-token-123',
        'user': {
          'id': 'user-1',
          'name': 'Fleet Manager',
          'email': 'fleet@openvts.io',
          'role': 'ADMIN',
          'username': 'fleetadmin',
        }
      };

      final response = LoginResponse.fromJson(json);
      expect(response.accessToken, 'access-token-123');
      expect(response.refreshToken, 'refresh-token-123');
      expect(response.user.id, 'user-1');
      expect(response.user.role, UserRole.admin);
    });

    test('ApiBaseUrlController persists and normalizes custom server URLs', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final localCache = LocalCache(prefs);

      final controller = ApiBaseUrlController(localCache);

      // Save custom self-hosted server with markdown brackets and trailing slashes
      await controller.saveCustomUrl('[https://my-fleet-server.com/api///]');

      expect(controller.state, 'https://my-fleet-server.com/api');
      expect(
        localCache.getString(StorageKeys.apiBaseUrlOverride),
        'https://my-fleet-server.com/api',
      );

      // Reset to default
      await controller.resetToDefault();
      expect(localCache.getString(StorageKeys.apiBaseUrlOverride), isNull);
    });
  });
}

