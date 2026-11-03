import 'package:google_sign_in/google_sign_in.dart';

class Auth {
  static const _serverClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
  static final _google = GoogleSignIn.instance;
  static GoogleSignInAccount? user;

  static bool get enabled => _serverClientId.isNotEmpty;

  static bool get signedIn => !enabled || user != null;

  static String? get idToken => user?.authentication.idToken;

  static Future<void> init() async {
    if (!enabled) return;
    await _google.initialize(serverClientId: _serverClientId);
    await refresh();
  }

  static Future<void> refresh() async {
    try {
      user = await _google.attemptLightweightAuthentication();
    } on GoogleSignInException {
      user = null;
    }
  }

  static Future<void> signIn() async {
    user = await _google.authenticate();
  }

  static Future<void> signOut() async {
    await _google.signOut();
    user = null;
  }
}
