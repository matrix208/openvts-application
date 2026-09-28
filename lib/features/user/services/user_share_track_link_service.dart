import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_options.dart';
import '../../../core/config/app_config.dart';
import '../models/user_share_track_link_model.dart';

class UserShareTrackLinkService {
  UserShareTrackLinkService(this._apiClient);

  final ApiClient _apiClient;

  static final Options _readOptions = normalReadOptions();

  static final Options _mutationOptions = normalWriteOptions();

  Future<UserShareTrackLinksPage> getShareTrackLinks({
    int page = 1,
    int limit = 50,
    String? search,
    String? refreshKey,
  }) async {
    final normalizedPage = page < 1 ? 1 : page;
    final normalizedLimit = limit < 1 ? 50 : limit;

    if (AppConfig.demoMode) {
      return _demoShareTrackLinks(
        page: normalizedPage,
        limit: normalizedLimit,
        search: search,
      );
    }

    final response = await _apiClient.get<UserShareTrackLinksPage>(
      ApiEndpoints.user.shareTrackLinks,
      queryParameters: _query(<String, dynamic>{
        'page': normalizedPage,
        'limit': normalizedLimit,
        'search': search,
      }),
      options: _readOptions,
      parser: (json) => UserShareTrackLinksPage.fromJson(
        json,
        defaultPage: normalizedPage,
        defaultLimit: normalizedLimit,
      ),
    );
    return response.data;
  }

  Future<UserShareTrackLink> getShareTrackLinkById(String id) async {
    final linkId = _requireId(id, 'id');

    if (AppConfig.demoMode) {
      return _demoShareTrackLinksData().firstWhere(
        (link) => link.id == linkId,
        orElse: () => _demoShareTrackLinksData().first,
      );
    }

    final response = await _apiClient.get<UserShareTrackLink>(
      ApiEndpoints.user.shareTrackLinkById(linkId),
      options: _readOptions,
      parser: UserShareTrackLink.fromJson,
    );
    return response.data;
  }

  Future<UserShareTrackLinkMutationResult> createShareTrackLink(
    UserCreateShareTrackLinkRequest request,
  ) async {
    final response = await _apiClient.post<UserShareTrackLink>(
      ApiEndpoints.user.shareTrackLinks,
      data: request.toJson(),
      options: _mutationOptions,
      parser: UserShareTrackLink.fromJson,
    );
    return UserShareTrackLinkMutationResult(
      link: response.data,
      message: response.message,
    );
  }

  Future<UserShareTrackLinkMutationResult> updateShareTrackLink({
    required String id,
    required UserUpdateShareTrackLinkRequest request,
  }) async {
    final linkId = _requireId(id, 'id');
    final response = await _apiClient.patch<UserShareTrackLink>(
      ApiEndpoints.user.shareTrackLinkById(linkId),
      data: request.toJson(),
      options: _mutationOptions,
      parser: UserShareTrackLink.fromJson,
    );
    return UserShareTrackLinkMutationResult(
      link: response.data,
      message: response.message,
    );
  }

  Future<void> deleteShareTrackLink(UserShareTrackLink link) async {
    final linkId = _requireId(link.id, 'id');
    await _apiClient.delete<void>(
      ApiEndpoints.user.shareTrackLinkById(linkId),
      options: _mutationOptions,
      parser: (_) {},
    );
  }

  Future<List<UserShareTrackVehicle>> getVehicles() async {
    if (AppConfig.demoMode) {
      return _demoShareTrackVehicles();
    }

    final response = await _apiClient.get<List<UserShareTrackVehicle>>(
      ApiEndpoints.user.vehicles,
      options: _readOptions,
      parser: UserShareTrackVehicle.listFromJson,
    );
    return response.data;
  }

  UserShareTrackLinksPage _demoShareTrackLinks({
    required int page,
    required int limit,
    String? search,
  }) {
    final normalizedSearch = search?.trim().toLowerCase();

    final allLinks = _demoShareTrackLinksData();

    final filtered = normalizedSearch == null || normalizedSearch.isEmpty
        ? allLinks
        : allLinks.where((link) {
            final code = link.uniqueCode.toLowerCase();
            final vehicleMatch = link.vehicles.any(
              (vehicle) =>
                  vehicle.name.toLowerCase().contains(normalizedSearch) ||
                  (vehicle.plateNumber ?? '')
                      .toLowerCase()
                      .contains(normalizedSearch),
            );

            return code.contains(normalizedSearch) || vehicleMatch;
          }).toList();

    final start = (page - 1) * limit;

    final items = start >= filtered.length
        ? <UserShareTrackLink>[]
        : filtered.skip(start).take(limit).toList();

    return UserShareTrackLinksPage(
      items: items,
      page: page,
      limit: limit,
      total: filtered.length,
      hasMore: page * limit < filtered.length,
    );
  }

  List<UserShareTrackLink> _demoShareTrackLinksData() {
    final vehicles = _demoShareTrackVehicles();
    final now = DateTime.now();

    return <UserShareTrackLink>[
      UserShareTrackLink(
        id: 'demo-track-link-001',
        uniqueCode: 'SMARTAVL-DEMO-001',
        expiryAt: now.add(const Duration(days: 30)),
        isActive: true,
        isGeofence: false,
        isHistory: true,
        vehicles: <UserShareTrackVehicle>[vehicles[0]],
        vehiclesCount: 1,
        finalUrl:
            'https://app.smartavl.net/track/SMARTAVL-DEMO-001',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      UserShareTrackLink(
        id: 'demo-track-link-002',
        uniqueCode: 'SMARTAVL-DEMO-002',
        expiryAt: now.add(const Duration(days: 14)),
        isActive: true,
        isGeofence: true,
        isHistory: false,
        vehicles: <UserShareTrackVehicle>[
          vehicles[1],
          vehicles[2],
        ],
        vehiclesCount: 2,
        finalUrl:
            'https://app.smartavl.net/track/SMARTAVL-DEMO-002',
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      UserShareTrackLink(
        id: 'demo-track-link-003',
        uniqueCode: 'SMARTAVL-DEMO-003',
        expiryAt: now.subtract(const Duration(days: 1)),
        isActive: false,
        isGeofence: false,
        isHistory: false,
        vehicles: <UserShareTrackVehicle>[vehicles[2]],
        vehiclesCount: 1,
        finalUrl:
            'https://app.smartavl.net/track/SMARTAVL-DEMO-003',
        createdAt: now.subtract(const Duration(days: 20)),
      ),
    ];
  }

  List<UserShareTrackVehicle> _demoShareTrackVehicles() {
    return const <UserShareTrackVehicle>[
      UserShareTrackVehicle(
        id: 'demo-vehicle-001',
        name: 'Smart AVL Vehicle 01',
        plateNumber: 'AVL-001',
        isLicenseBlocked: false,
      ),
      UserShareTrackVehicle(
        id: 'demo-vehicle-002',
        name: 'Smart AVL Vehicle 02',
        plateNumber: 'AVL-002',
        isLicenseBlocked: false,
      ),
      UserShareTrackVehicle(
        id: 'demo-vehicle-003',
        name: 'Smart AVL Vehicle 03',
        plateNumber: 'AVL-003',
        isLicenseBlocked: false,
      ),
    ];
  }

  String _requireId(String value, String fieldName) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('$fieldName is required.');
    }
    return normalized;
  }

  Map<String, dynamic>? _query(Map<String, dynamic> values) {
    final query = <String, dynamic>{};
    for (final entry in values.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      query[entry.key] = value;
    }
    return query.isEmpty ? null : query;
  }
}

class UserShareTrackLinkMutationResult {
  const UserShareTrackLinkMutationResult({
    required this.link,
    this.message,
  });

  final UserShareTrackLink link;
  final String? message;
}
