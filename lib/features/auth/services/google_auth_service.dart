import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  GoogleAuthService._();

  static final GoogleAuthService instance = GoogleAuthService._();

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  String? _currentClientId;
  String? _currentServerClientId;
  bool _initialized = false;

  Future<void> initialize({
    String? clientId,
    String? serverClientId,
  }) async {
    final effectiveClientId =
        clientId?.trim().isNotEmpty == true ? clientId!.trim() : null;

    final effectiveServerClientId = serverClientId?.trim().isNotEmpty == true
        ? serverClientId!.trim()
        : null;

    if (_initialized &&
        _currentClientId == effectiveClientId &&
        _currentServerClientId == effectiveServerClientId) {
      return;
    }

    await _googleSignIn.initialize(
      clientId: effectiveClientId,
      serverClientId: effectiveServerClientId,
    );

    _currentClientId = effectiveClientId;
    _currentServerClientId = effectiveServerClientId;
    _initialized = true;

    debugPrint(
      'Google SignIn initialized. '
      'clientId=$_currentClientId '
      'serverClientId=$_currentServerClientId',
    );
  }

  Future<String?> signInAndGetServerAuthCode({
    String? clientId,
    String? serverClientId,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Web Google Sign-In must use the Google rendered button.',
      );
    }

    await initialize(
      clientId: clientId,
      serverClientId: serverClientId,
    );

    final account = await _googleSignIn.authenticate();

    final authorization = await account.authorizationClient.authorizeServer(
      const <String>[],
    );

    return authorization?.serverAuthCode;
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('GoogleSignIn.signOut error: $e');
    }
  }
}
