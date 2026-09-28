import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_options.dart';
import '../../../core/config/app_config.dart';
import '../models/user_vehicle_model.dart';

class UserVehicleService {
  UserVehicleService(this._apiClient);

  final ApiClient _apiClient;

  static final Options _readOptions = normalReadOptions();

  static final Options _mutationOptions = normalWriteOptions();

  static final Options _uploadOptions = uploadOptions().copyWith(
    contentType: Headers.multipartFormDataContentType,
  );

  Future<List<UserVehicleListItem>> getVehicles({String? refreshKey}) async {
    if (AppConfig.demoMode) {
      return _demoVehicles();
    }

    final response = await _apiClient.get<List<UserVehicleListItem>>(
      ApiEndpoints.user.vehicles,
      queryParameters: _query(<String, dynamic>{'rk': refreshKey}),
      options: _readOptions,
      parser: UserVehicleListItem.listFromJson,
    );
    return response.data;
  }

  Future<UserVehicleDetails> getVehicleById(String id) async {
    final vehicleId = _requireId(id, 'vehicleId');

    if (AppConfig.demoMode) {
      return _demoVehicleDetails(vehicleId);
    }

    final response = await _apiClient.get<UserVehicleDetails>(
      ApiEndpoints.user.vehicleById(vehicleId),
      options: _readOptions,
      parser: UserVehicleDetails.fromJson,
    );
    return response.data;
  }

  Future<UserVehicleDetails> updateVehicle({
    required String id,
    required UserVehicleUpdateRequest request,
  }) async {
    final vehicleId = _requireId(id, 'vehicleId');
    await _apiClient.patch<void>(
      ApiEndpoints.user.vehicleUpdate(vehicleId),
      data: request.toJson(),
      options: _mutationOptions,
      parser: (_) {},
    );
    return getVehicleById(vehicleId);
  }

  Future<UserVehicleDetails> updateVehicleConfig({
    required String id,
    required UserVehicleConfigUpdateRequest request,
  }) async {
    final vehicleId = _requireId(id, 'vehicleId');
    await _apiClient.patch<void>(
      ApiEndpoints.user.vehicleConfigUpdate(vehicleId),
      data: request.toJson(),
      options: _mutationOptions,
      parser: (_) {},
    );
    return getVehicleById(vehicleId);
  }

  Future<List<UserVehicleTypeOption>> getVehicleTypes() async {
    final response = await _apiClient.get<List<UserVehicleTypeOption>>(
      ApiEndpoints.public.vehicleTypes,
      options: _readOptions,
      parser: UserVehicleTypeOption.listFromJson,
    );
    return response.data;
  }

  Future<List<String>> getTimezones() async {
    final response = await _apiClient.get<List<String>>(
      ApiEndpoints.public.timezones,
      options: _readOptions,
      parser: _parseTimezones,
    );
    return response.data;
  }

  Future<UserVehicleSensorPage> getVehicleSensors({
    required String vehicleId,
    String? search,
    int page = 1,
    int limit = 100,
    bool includeLive = true,
  }) async {
    final id = _requireId(vehicleId, 'vehicleId');

    if (AppConfig.demoMode) {
      return _demoSensorPage(
        vehicleId: id,
        search: search,
        page: page,
        limit: limit,
      );
    }

    final normalizedPage = page < 1 ? 1 : page;
    final normalizedLimit = limit < 1 ? 100 : limit;
    final response = await _apiClient.get<UserVehicleSensorPage>(
      ApiEndpoints.user.vehicleSensors(id),
      queryParameters: _query(<String, dynamic>{
        'search': search,
        'page': normalizedPage,
        'limit': normalizedLimit,
        'includeLive': includeLive,
      }),
      options: _readOptions,
      parser: (json) => UserVehicleSensorPage.fromJson(
        json,
        defaultPage: normalizedPage,
        defaultLimit: normalizedLimit,
      ),
    );
    return response.data;
  }

  Future<UserVehicleSensor> createVehicleSensor({
    required String vehicleId,
    required String name,
    String? unit,
    String? icon,
    required String code,
    bool isActive = true,
  }) async {
    final id = _requireId(vehicleId, 'vehicleId');
    final response = await _apiClient.post<UserVehicleSensor>(
      ApiEndpoints.user.vehicleSensors(id),
      data: _sensorPayload(
        name: name,
        unit: unit,
        icon: icon,
        code: code,
        isActive: isActive,
      ),
      options: _mutationOptions,
      parser: UserVehicleSensor.fromJson,
    );
    return response.data;
  }

  Future<UserVehicleSensor> updateVehicleSensor({
    required String vehicleId,
    required String sensorId,
    required String name,
    String? unit,
    String? icon,
    required String code,
    bool isActive = true,
  }) async {
    final id = _requireId(vehicleId, 'vehicleId');
    final sid = _requireId(sensorId, 'sensorId');
    final response = await _apiClient.patch<UserVehicleSensor>(
      ApiEndpoints.user.vehicleSensorById(vehicleId: id, sensorId: sid),
      data: _sensorPayload(
        name: name,
        unit: unit,
        icon: icon,
        code: code,
        isActive: isActive,
      ),
      options: _mutationOptions,
      parser: UserVehicleSensor.fromJson,
    );
    return response.data;
  }

  Future<void> deleteVehicleSensor({
    required String vehicleId,
    required String sensorId,
  }) async {
    final id = _requireId(vehicleId, 'vehicleId');
    final sid = _requireId(sensorId, 'sensorId');
    await _apiClient.delete<void>(
      ApiEndpoints.user.vehicleSensorById(vehicleId: id, sensorId: sid),
      options: _mutationOptions,
      parser: (_) {},
    );
  }

  Future<UserVehicleSensorRunResult> runVehicleSensor({
    required String vehicleId,
    required String code,
    required Map<String, dynamic> payload,
  }) async {
    final id = _requireId(vehicleId, 'vehicleId');
    final normalizedCode = _requireText(code, 'code');
    final response = await _apiClient.post<UserVehicleSensorRunResult>(
      ApiEndpoints.user.vehicleSensorsRun(id),
      data: <String, dynamic>{
        'code': normalizedCode,
        'payload': payload,
      },
      options: _mutationOptions,
      parser: UserVehicleSensorRunResult.fromJson,
    );
    return response.data;
  }

  Future<UserVehicleSensorTelemetry> getVehicleSensorTelemetry(
    String vehicleId,
  ) async {
    final id = _requireId(vehicleId, 'vehicleId');
    final response = await _apiClient.get<UserVehicleSensorTelemetry>(
      ApiEndpoints.user.vehicleSensorsTelemetry(id),
      options: _readOptions,
      parser: UserVehicleSensorTelemetry.fromJson,
    );
    return response.data;
  }

  Future<UserVehicleSensorHistory> getVehicleSensorHistory({
    required String vehicleId,
    required String sensorId,
    required DateTime from,
    required DateTime to,
    int maxPoints = 500,
  }) async {
    final id = _requireId(vehicleId, 'vehicleId');
    final sid = _requireId(sensorId, 'sensorId');
    final normalizedFrom = from.isAfter(to) ? to : from;
    final normalizedTo = to.isBefore(from) ? from : to;
    final response = await _apiClient.get<UserVehicleSensorHistory>(
      ApiEndpoints.user.vehicleSensorHistory(
        vehicleId: id,
        sensorId: sid,
      ),
      queryParameters: _query(<String, dynamic>{
        'from': normalizedFrom.toUtc().toIso8601String(),
        'to': normalizedTo.toUtc().toIso8601String(),
        'maxPoints': maxPoints < 1 ? 1 : maxPoints,
      }),
      options: _readOptions,
      parser: UserVehicleSensorHistory.fromJson,
    );
    return response.data;
  }

  Future<List<UserVehicleDocument>> getVehicleDocuments(
    String vehicleId,
  ) async {
    final id = _requireId(vehicleId, 'vehicleId');
    final response = await _apiClient.get<List<UserVehicleDocument>>(
      ApiEndpoints.user.vehicleDocuments(id),
      options: _readOptions,
      parser: UserVehicleDocument.listFromJson,
    );
    return response.data;
  }

  Future<List<UserVehicleDocumentType>> getVehicleDocumentTypes() async {
    final response = await _apiClient.get<List<UserVehicleDocumentType>>(
      ApiEndpoints.user.vehicleDocumentTypes,
      options: _readOptions,
      parser: UserVehicleDocumentType.listFromJson,
    );
    return response.data;
  }

  Future<void> uploadVehicleDocument({
    required String vehicleId,
    required UserVehicleDocumentRequest request,
  }) async {
    final id = _requireId(vehicleId, 'vehicleId');
    _validateDocumentRequest(request, requireFile: true);
    final formData = await _buildDocumentFormData(request);
    await _apiClient.post<void>(
      ApiEndpoints.user.vehicleDocuments(id),
      data: formData,
      options: _uploadOptions,
      parser: (_) {},
    );
  }

  Future<void> updateVehicleDocument({
    required String vehicleId,
    required String docId,
    required UserVehicleDocumentRequest request,
  }) async {
    final id = _requireId(vehicleId, 'vehicleId');
    final did = _requireId(docId, 'docId');
    _validateDocumentRequest(request, requireFile: false);
    final formData = await _buildDocumentFormData(request);
    await _apiClient.patch<void>(
      ApiEndpoints.user.vehicleDocumentById(vehicleId: id, docId: did),
      data: formData,
      options: _uploadOptions,
      parser: (_) {},
    );
  }

  Future<void> deleteVehicleDocument({
    required String vehicleId,
    required String docId,
  }) async {
    final id = _requireId(vehicleId, 'vehicleId');
    final did = _requireId(docId, 'docId');
    await _apiClient.delete<void>(
      ApiEndpoints.user.vehicleDocumentById(vehicleId: id, docId: did),
      options: _mutationOptions,
      parser: (_) {},
    );
  }

  UserVehicleSensorPage _demoSensorPage({
    required String vehicleId,
    String? search,
    required int page,
    required int limit,
  }) {
    final now = DateTime.now();

    final sensors = <UserVehicleSensor>[
      UserVehicleSensor(
        id: '$vehicleId-sensor-fuel',
        name: 'Fuel Level',
        unit: '%',
        icon: 'fuel',
        code: 'fuel_level',
        value: 72,
        liveValue: 72,
        displayValue: '72%',
        dataType: 'number',
        isActive: true,
        lastUpdated: now,
        createdAt: now,
        updatedAt: now,
      ),
      UserVehicleSensor(
        id: '$vehicleId-sensor-temp',
        name: 'Engine Temperature',
        unit: '°C',
        icon: 'temperature',
        code: 'engine_temperature',
        value: 84,
        liveValue: 84,
        displayValue: '84 °C',
        dataType: 'number',
        isActive: true,
        lastUpdated: now,
        createdAt: now,
        updatedAt: now,
      ),
      UserVehicleSensor(
        id: '$vehicleId-sensor-voltage',
        name: 'External Voltage',
        unit: 'V',
        icon: 'battery',
        code: 'external_voltage',
        value: 13.8,
        liveValue: 13.8,
        displayValue: '13.8 V',
        dataType: 'number',
        isActive: true,
        lastUpdated: now,
        createdAt: now,
        updatedAt: now,
      ),
      UserVehicleSensor(
        id: '$vehicleId-sensor-ignition',
        name: 'Ignition',
        unit: null,
        icon: 'power',
        code: 'ignition',
        value: true,
        liveValue: true,
        displayValue: 'ON',
        dataType: 'boolean',
        isActive: true,
        lastUpdated: now,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final normalizedSearch = search?.trim().toLowerCase();

    final filtered = normalizedSearch == null || normalizedSearch.isEmpty
        ? sensors
        : sensors
            .where(
              (sensor) =>
                  sensor.name.toLowerCase().contains(normalizedSearch) ||
                  sensor.code.toLowerCase().contains(normalizedSearch),
            )
            .toList();

    final normalizedPage = page < 1 ? 1 : page;
    final normalizedLimit = limit < 1 ? 100 : limit;
    final startIndex = (normalizedPage - 1) * normalizedLimit;

    final items = startIndex >= filtered.length
        ? <UserVehicleSensor>[]
        : filtered
            .skip(startIndex)
            .take(normalizedLimit)
            .toList();

    return UserVehicleSensorPage(
      items: items,
      page: normalizedPage,
      limit: normalizedLimit,
      total: filtered.length,
      telemetryMeta: <String, dynamic>{
        'demo': true,
        'vehicleId': vehicleId,
        'updatedAt': now.toIso8601String(),
      },
    );
  }

  UserVehicleDetails _demoVehicleDetails(String vehicleId) {
    final vehicles = _demoVehicles();

    final vehicle = vehicles.firstWhere(
      (item) => item.id == vehicleId,
      orElse: () => vehicles.first,
    );

    return UserVehicleDetails(
      id: vehicle.id,
      name: vehicle.name,
      vin: vehicle.vin,
      plateNumber: vehicle.plateNumber,
      isActive: vehicle.isActive,
      isLicenseBlocked: vehicle.isLicenseBlocked,
      licenseBlockedAt: vehicle.licenseBlockedAt,
      licenseBlockReason: vehicle.licenseBlockReason,
      createdAt: vehicle.createdAt,
      imei: vehicle.imei,
      simNumber: vehicle.simNumber,
      vehicleType: vehicle.vehicleType,
      vehicleMeta: const <String, dynamic>{
        'demo': true,
        'source': 'Smart AVL Fleet Demo',
      },
      gmtOffset: '+03:00',
      device: vehicle.device,
      plan: const UserVehiclePlanMini(
        id: 'demo-plan-001',
        name: 'Demo Fleet Plan',
        price: 0,
        currency: 'USD',
      ),
    );
  }

  List<UserVehicleListItem> _demoVehicles() {
    return const [
      UserVehicleListItem(
        id: 'demo-vehicle-001',
        name: 'Smart AVL Vehicle 01',
        vin: 'DEMO-VIN-0001',
        plateNumber: 'AVL-001',
        isActive: true,
        isLicenseBlocked: false,
        licenseBlockedAt: null,
        licenseBlockReason: null,
        createdAt: null,
        imei: '356307042441001',
        simNumber: '+966500000001',
        vehicleType: UserVehicleTypeMini(
          id: 'demo-type-car',
          name: 'Car',
          slug: 'car',
        ),
        device: UserVehicleDeviceMini(
          id: 'demo-device-001',
          imei: '356307042441001',
          simNumber: '+966500000001',
          speedVariation: 5,
          distanceVariation: 0,
          odometer: 12450,
          engineHours: 184,
          ignitionSource: 'ACC',
          liveOdometer: 12450,
          liveEngineHours: 184,
        ),
      ),
      UserVehicleListItem(
        id: 'demo-vehicle-002',
        name: 'Smart AVL Vehicle 02',
        vin: 'DEMO-VIN-0002',
        plateNumber: 'AVL-002',
        isActive: true,
        isLicenseBlocked: false,
        licenseBlockedAt: null,
        licenseBlockReason: null,
        createdAt: null,
        imei: '356307042441002',
        simNumber: '+966500000002',
        vehicleType: UserVehicleTypeMini(
          id: 'demo-type-truck',
          name: 'Truck',
          slug: 'truck',
        ),
        device: UserVehicleDeviceMini(
          id: 'demo-device-002',
          imei: '356307042441002',
          simNumber: '+966500000002',
          speedVariation: 5,
          distanceVariation: 0,
          odometer: 28760,
          engineHours: 421,
          ignitionSource: 'ACC',
          liveOdometer: 28760,
          liveEngineHours: 421,
        ),
      ),
      UserVehicleListItem(
        id: 'demo-vehicle-003',
        name: 'Smart AVL Vehicle 03',
        vin: 'DEMO-VIN-0003',
        plateNumber: 'AVL-003',
        isActive: false,
        isLicenseBlocked: false,
        licenseBlockedAt: null,
        licenseBlockReason: null,
        createdAt: null,
        imei: '356307042441003',
        simNumber: '+966500000003',
        vehicleType: UserVehicleTypeMini(
          id: 'demo-type-van',
          name: 'Van',
          slug: 'van',
        ),
        device: UserVehicleDeviceMini(
          id: 'demo-device-003',
          imei: '356307042441003',
          simNumber: '+966500000003',
          speedVariation: 5,
          distanceVariation: 0,
          odometer: 8320,
          engineHours: 97,
          ignitionSource: 'MOTION',
          liveOdometer: 8320,
          liveEngineHours: 97,
        ),
      ),
    ];
  }

  Map<String, dynamic> _sensorPayload({
    required String name,
    String? unit,
    String? icon,
    required String code,
    required bool isActive,
  }) {
    return <String, dynamic>{
      'name': _requireText(name, 'name'),
      'code': _requireText(code, 'code'),
      'isActive': isActive,
      if (_optionalString(unit) != null) 'unit': _optionalString(unit),
      if (_optionalString(icon) != null) 'icon': _optionalString(icon),
    };
  }

  Future<FormData> _buildDocumentFormData(
    UserVehicleDocumentRequest request,
  ) async {
    final formData = FormData();
    formData.fields.addAll(<MapEntry<String, String>>[
      MapEntry('title', request.title.trim()),
      MapEntry('docTypeId', request.docTypeId.trim()),
      MapEntry('isVisible', request.isVisible.toString()),
      MapEntry('description', request.description.trim()),
    ]);

    final tags = request.tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .join(',');
    if (tags.isNotEmpty) {
      formData.fields.add(MapEntry('tags', tags));
    }

    final expiry = request.expiryAt?.trim();
    if (expiry != null && expiry.isNotEmpty) {
      formData.fields.add(MapEntry('expiryAt', expiry));
    }

    final file = request.file;
    if (file != null) {
      formData.files.add(MapEntry('File', await _toMultipartFile(file)));
    }

    return formData;
  }

  Future<MultipartFile> _toMultipartFile(PlatformFile file) async {
    final fileName = file.name.trim().isEmpty ? 'attachment' : file.name.trim();
    final contentType = _contentTypeForExtension(_extension(fileName));

    if (file.bytes != null) {
      return MultipartFile.fromBytes(
        file.bytes!,
        filename: fileName,
        contentType: contentType,
      );
    }

    final path = file.path?.trim();
    if (path != null && path.isNotEmpty) {
      return MultipartFile.fromFile(
        path,
        filename: fileName,
        contentType: contentType,
      );
    }

    throw ArgumentError('Unable to read file "$fileName".');
  }

  void _validateDocumentRequest(
    UserVehicleDocumentRequest request, {
    required bool requireFile,
  }) {
    _requireText(request.title, 'title');
    _requireText(request.docTypeId, 'docTypeId');
    if (requireFile && request.file == null) {
      throw ArgumentError('file is required.');
    }
  }

  String _requireId(String value, String fieldName) {
    return _requireText(value, fieldName);
  }

  String _requireText(String value, String fieldName) {
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

  List<String> _parseTimezones(dynamic json) {
    final list = _extractList(json, preferredKeys: const [
      'timezones',
      'items',
      'rows',
      'list',
      'data',
    ]);
    return list
        .map(_timezoneLabel)
        .whereType<String>()
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  List<dynamic> _extractList(
    dynamic json, {
    required List<String> preferredKeys,
  }) {
    if (json is List) return json;
    final root = _asMap(json);
    for (final key in preferredKeys) {
      final value = _valueForKey(root, key);
      if (value is List) return value;
    }
    for (final key in const ['data', 'result', 'payload', 'response']) {
      final nested = _valueForKey(root, key);
      if (nested == null || identical(nested, json)) continue;
      final list = _extractList(nested, preferredKeys: preferredKeys);
      if (list.isNotEmpty) return list;
    }
    return const <dynamic>[];
  }

  String? _timezoneLabel(dynamic value) {
    if (value is String) return value.trim();
    final source = _asMap(value);
    for (final key in const [
      'value',
      'name',
      'label',
      'timezone',
      'gmtOffset'
    ]) {
      final raw = _valueForKey(source, key);
      if (raw == null) continue;
      final normalized = raw.toString().trim();
      if (normalized.isNotEmpty) return normalized;
    }
    return null;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const <String, dynamic>{};
  }

  dynamic _valueForKey(Map<String, dynamic> json, String key) {
    if (json.containsKey(key)) return json[key];
    final normalizedKey = key.toLowerCase();
    for (final entry in json.entries) {
      if (entry.key.toLowerCase() == normalizedKey) return entry.value;
    }
    return null;
  }

  String? _optionalString(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
  }

  String _extension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }

  MediaType _contentTypeForExtension(String extension) {
    switch (extension) {
      case 'pdf':
        return MediaType('application', 'pdf');
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'gif':
        return MediaType('image', 'gif');
      case 'webp':
        return MediaType('image', 'webp');
      case 'doc':
        return MediaType('application', 'msword');
      case 'docx':
        return MediaType(
          'application',
          'vnd.openxmlformats-officedocument.wordprocessingml.document',
        );
      case 'xls':
        return MediaType('application', 'vnd.ms-excel');
      case 'xlsx':
        return MediaType(
          'application',
          'vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
      case 'csv':
        return MediaType('text', 'csv');
      case 'txt':
        return MediaType('text', 'plain');
      case 'zip':
        return MediaType('application', 'zip');
      default:
        return MediaType('application', 'octet-stream');
    }
  }
}
