class GoogleAuthConfig {
  const GoogleAuthConfig({
    required this.enabled,
    this.clientId,
    this.serverClientId,
  });

  final bool enabled;
  final String? clientId;
  final String? serverClientId;

  factory GoogleAuthConfig.fromJson(Map<String, dynamic> json) {
    return GoogleAuthConfig(
      enabled: json['enabled'] != false,
      clientId: _readString(json, [
        'clientId',
        'client_id',
        'googleClientId',
        'google_client_id',
      ]),
      serverClientId: _readString(json, [
        'serverClientId',
        'server_client_id',
        'googleServerClientId',
        'google_server_client_id',
      ]),
    );
  }

  static String? _readString(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return null;
  }
}
