import 'package:flutter_test/flutter_test.dart';
import 'package:nosignal_pay/core/api_exception.dart';
import 'package:nosignal_pay/providers/wallet_provider.dart';

import '../support/fakes.dart';

void main() {
  late FakeApiClient api;
  late WalletProvider wallet;

  setUp(() {
    api = FakeApiClient();
    wallet = WalletProvider(api: api);
  });

  test('load gets the balance', () async {
    api.walletResult = walletWith(163000);

    await wallet.load();

    expect(wallet.status, WalletStatus.loaded);
    expect(wallet.balanceCents, 163000);
  });

  test('a failed refresh keeps the last balance and sets errorCode', () async {
    api.walletResult = walletWith(163000);
    await wallet.load();
    api.walletResult = apiError(null, ApiException.networkError);

    await wallet.load();

    expect(wallet.status, WalletStatus.error);
    expect(wallet.errorCode, ApiException.networkError);
    expect(wallet.balanceCents, 163000);
  });

  test('clear forgets the balance', () async {
    api.walletResult = walletWith(163000);
    await wallet.load();

    wallet.clear();

    expect(wallet.status, WalletStatus.initial);
    expect(wallet.balanceCents, isNull);
  });
}
