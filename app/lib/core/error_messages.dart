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
    ApiException.networkError => 'No pudimos conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.',
    ApiException.timeout => 'El servidor tardó demasiado. Inténtalo de nuevo.',
    _ => 'Algo salió mal. Inténtalo de nuevo.',
  };
}
