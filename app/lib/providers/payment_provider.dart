import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/qr_payload.dart';
import '../models/payment_request.dart';
import '../models/transaction_item.dart';

enum PaymentStatus {
  /// Nothing loaded yet (scan screen).
  idle,

  /// Asking the server for the charge behind the QR.
  loadingPreview,

  /// Charge loaded and payable: the confirm screen can show it.
  ready,

  /// The payment is on its way; the pay button is disabled.
  paying,

  /// The server confirmed the payment; see [PaymentProvider.result].
  success,

  /// Something failed; see [PaymentProvider.errorCode].
  error,
}

/// The payer's side of a QR payment: scan, preview, confirm, result.
///
/// The idempotency key is created when a charge is loaded and reused on every
/// retry of [confirm]. It is only dropped by [clear] (leaving the flow) or by
/// loading another charge. That is what makes "Reintentar" safe: if the first
/// attempt did reach the server, the retry gets the same payment back instead
/// of a second charge.
class PaymentProvider extends ChangeNotifier {
  PaymentProvider({required this._api, Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  /// Local error code for a QR that is not a NoSignal charge.
  static const invalidQr = 'invalid_qr';

  final ApiClient _api;
  final Uuid _uuid;

  PaymentStatus _status = PaymentStatus.idle;
  PaymentRequest? _request;
  MoneyOperation? _result;
  String? _errorCode;
  String? _idempotencyKey;

  PaymentStatus get status => _status;

  /// The charge being paid (amount, payee name, description).
  PaymentRequest? get request => _request;

  /// The confirmed payment and the new balance, after [PaymentStatus.success].
  MoneyOperation? get result => _result;
  String? get errorCode => _errorCode;

  /// The key sent with the payment. Exposed for tests.
  String? get idempotencyKey => _idempotencyKey;

  /// True when the outcome of the last [confirm] is unknown (no response).
  /// Retrying with the same key is safe in that case.
  bool get canRetry =>
      _status == PaymentStatus.error &&
      (_errorCode == ApiException.networkError ||
          _errorCode == ApiException.timeout);

  /// Validates the scanned or pasted text and loads the charge it points to.
  /// Returns true when the charge can be paid.
  Future<bool> loadFromQr(String rawText) async {
    if (_status == PaymentStatus.loadingPreview) return false;

    final id = parsePaymentRequestQr(rawText);
    if (id == null) {
      _fail(invalidQr);
      return false;
    }

    _status = PaymentStatus.loadingPreview;
    _errorCode = null;
    _result = null;
    notifyListeners();

    try {
      final request = await _api.getPaymentRequest(id);
      // Check the status before showing the confirm screen; the server checks
      // again when paying, so this only saves the user a useless step.
      if (request.status == PaymentRequest.paid) {
        _fail('payment_request_already_paid');
        return false;
      }
      if (request.status == PaymentRequest.expired) {
        _fail('payment_request_expired');
        return false;
      }
      _request = request;
      _idempotencyKey = _uuid.v4(); // new charge, new intent, new key
      _status = PaymentStatus.ready;
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      _fail(error.code);
      return false;
    }
  }

  /// Sends the payment with the saved key. Returns true on success.
  Future<bool> confirm() async {
    final request = _request;
    final key = _idempotencyKey;
    if (request == null || key == null || _status == PaymentStatus.paying) {
      return false;
    }

    _status = PaymentStatus.paying;
    _errorCode = null;
    notifyListeners();

    try {
      _result = await _api.pay(
        paymentRequestId: request.id,
        idempotencyKey: key,
      );
      _status = PaymentStatus.success;
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      _fail(error.code); // the key is kept on purpose
      return false;
    }
  }

  /// Leaves the flow: forgets the charge, the result and the key.
  void clear() {
    _status = PaymentStatus.idle;
    _request = null;
    _result = null;
    _errorCode = null;
    _idempotencyKey = null;
    notifyListeners();
  }

  void _fail(String code) {
    _errorCode = code;
    _status = PaymentStatus.error;
    notifyListeners();
  }
}
