import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';

enum WalletStatus { initial, loading, loaded, error }

/// The signed-in user's balance. Screens read [status], [balanceCents] and
/// [errorCode], and call [load] to refresh.
class WalletProvider extends ChangeNotifier {
  WalletProvider({required this._api});

  final ApiClient _api;

  WalletStatus _status = WalletStatus.initial;
  int? _balanceCents;
  String? _errorCode;

  WalletStatus get status => _status;

  /// The last balance we got, or null if it never loaded. It stays visible
  /// while a refresh is running or after a refresh fails.
  int? get balanceCents => _balanceCents;
  String? get errorCode => _errorCode;

  Future<void> load() async {
    if (_status == WalletStatus.loading) return;
    _status = WalletStatus.loading;
    _errorCode = null;
    notifyListeners();
    try {
      final wallet = await _api.getWallet();
      _balanceCents = wallet.balanceCents;
      _status = WalletStatus.loaded;
    } on ApiException catch (error) {
      _errorCode = error.code;
      _status = WalletStatus.error;
    }
    notifyListeners();
  }

  /// Forgets everything; AuthProvider calls this on sign out so the next user
  /// never sees the previous user's balance.
  void clear() {
    _status = WalletStatus.initial;
    _balanceCents = null;
    _errorCode = null;
    notifyListeners();
  }
}
