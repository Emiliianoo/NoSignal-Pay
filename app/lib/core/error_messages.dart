import 'api_exception.dart';

/// The only place with user-facing error texts. Screens pass an error code
/// (from the server or ApiException) and show what this returns.
String errorMessage(String code) {
  return switch (code) {
    'invalid_credentials' => 'El correo o la contraseña no son correctos.',
    'email_already_registered' =>
      'Ya existe una billetera con ese correo. Entra con tu contraseña.',
    'validation_error' => 'Revisa los datos: usa un correo válido y una contraseña de 8 caracteres o más.',
    'not_authenticated' ||
    'token_expired' => 'Tu sesión terminó. Vuelve a entrar.',
    // Paying
    'invalid_qr' => 'Ese código no es de NoSignal. Pide a quien te cobra que te muestre su código.',
    'payment_request_not_found' =>
      'No encontramos ese cobro. Pide un código nuevo.',
    'payment_request_already_paid' => 'Ese cobro ya fue pagado.',
    'payment_request_expired' => 'Ese cobro caducó. Pide un código nuevo.',
    'cannot_pay_own_request' => 'No puedes pagar tu propio cobro.',
    'insufficient_funds' =>
      'No te alcanza el saldo. Recarga e inténtalo de nuevo.',
    ApiException.networkError => 'No pudimos conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.',
    ApiException.timeout => 'El servidor tardó demasiado. Inténtalo de nuevo.',
    _ => 'Algo salió mal. Inténtalo de nuevo.',
  };
}
