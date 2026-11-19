/// Named routes, so screens navigate with `Navigator.pushNamed(context, Routes.home)`
/// instead of repeating strings.
abstract final class Routes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const payScan = '/pay/scan';
  static const payConfirm = '/pay/confirm';
  static const payResult = '/pay/result';
}
