import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/token_storage.dart';
import '../models/user.dart';

enum AuthStatus {
  /// The app just opened and has not checked the saved token yet.
  unknown,
  signedOut,
  signedIn,
}

/// Owns the session: who is signed in and their token. The only class that
/// calls the auth endpoints of [ApiClient]. Screens read [status], [user],
/// [isLoading] and [errorCode], and call the methods below.
class AuthProvider extends ChangeNotifier {
  AuthProvider({required this._api, required this._tokenStorage}) {
    // A request with a token got a 401: the token expired or is no longer
    // valid, so the session is over.
    _api.onUnauthorized = _endSession;
  }

  final ApiClient _api;
  final TokenStorage _tokenStorage;

  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  bool _isLoading = false;
  String? _errorCode;

  AuthStatus get status => _status;

  /// The signed-in user, or null when [status] is not signedIn.
  User? get user => _user;

  /// True while register or login is waiting for the server.
  bool get isLoading => _isLoading;

  /// The code of the last failure (for example `invalid_credentials`), or
  /// null. Screens turn it into a message; they never show the server's text.
  String? get errorCode => _errorCode;

  /// Runs once when the app opens: if there is a saved token, asks the server
  /// who it belongs to.
  Future<void> restoreSession() async {
    final token = await _tokenStorage.read();
    if (token == null) {
      _setSignedOut();
      return;
    }
    try {
      _user = await _api.getMe();
      _status = AuthStatus.signedIn;
      _errorCode = null;
      notifyListeners();
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        // The token expired. onUnauthorized also ends the session, but without
        // waiting; we wait here so status is signedOut when this returns.
        await _endSession();
        return;
      }
      // No network or server down: we cannot confirm the session. Keep the
      // token so the next launch can try again, but show the login screen.
      _errorCode = error.code;
      _setSignedOut();
    }
  }

  /// Returns true when the account was created and the user is signed in.
  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _authenticate(
      () => _api.register(
        email: email,
        password: password,
        displayName: displayName,
      ),
    );
  }

  /// Returns true when the user is signed in.
  Future<bool> login({required String email, required String password}) {
    return _authenticate(() => _api.login(email: email, password: password));
  }

  Future<void> logout() async {
    // Later: call clear() on WalletProvider, ChargeProvider and PaymentProvider.
    _errorCode = null;
    await _endSession();
  }

  /// Hides the current error, for example when the user edits a field.
  void clearError() {
    if (_errorCode == null) return;
    _errorCode = null;
    notifyListeners();
  }

  // ---------- internals ----------

  Future<bool> _authenticate(Future<AuthResult> Function() request) async {
    if (_isLoading) return false; // a request is already on its way
    _isLoading = true;
    _errorCode = null;
    notifyListeners();

    try {
      final result = await request();
      // Save the token before saying "signed in", so the next request has it.
      await _tokenStorage.write(result.accessToken);
      _user = result.user;
      _status = AuthStatus.signedIn;
      return true;
    } on ApiException catch (error) {
      _errorCode = error.code;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _endSession() async {
    await _tokenStorage.delete();
    _setSignedOut();
  }

  void _setSignedOut() {
    _user = null;
    _status = AuthStatus.signedOut;
    notifyListeners();
  }
}
