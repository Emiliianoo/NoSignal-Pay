/// Reads the charge QR: exactly `NSP:1:REQ:<uuid v4>`, nothing else.
///
/// Anything that does not match (another app's QR, a link, a modified code) is
/// rejected here, without calling the server and without opening anything.
final _paymentRequestQr = RegExp(
  r'^NSP:1:REQ:([0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})$',
  caseSensitive: false,
);

/// The payment request id inside [raw], or null if [raw] is not a charge QR.
/// Spaces around the text (common when pasting) are ignored.
String? parsePaymentRequestQr(String raw) {
  final match = _paymentRequestQr.firstMatch(raw.trim());
  return match?.group(1)!.toLowerCase();
}
