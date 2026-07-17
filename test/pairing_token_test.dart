import 'package:flutter_test/flutter_test.dart';
import 'package:the_guardian_child/utils/pairing_token.dart';

void main() {
  const token = 'AbCdEfGhIjKlMnOpQrStUvWxYz0123456789_-ABCD12';

  group('parent/child pairing contract', () {
    test('accepts the current parent HTTPS link format', () {
      expect(
        extractPairingToken('https://the-guardian.app/child/pair?code=$token'),
        token,
      );
    });

    test('accepts the legacy parent HTTPS path', () {
      expect(
        extractPairingToken('https://the-guardian.app/pair?token=$token'),
        token,
      );
    });

    test('accepts guardian deep links', () {
      expect(extractPairingToken('guardian://pair?token=$token'), token);
    });

    test('accepts an opaque token pasted directly', () {
      expect(extractPairingToken(token), token);
    });

    test('rejects an untrusted web origin or route', () {
      expect(
        extractPairingToken('https://example.com/child/pair?code=$token'),
        isNull,
      );
      expect(
        extractPairingToken('https://the-guardian.app/account?code=$token'),
        isNull,
      );
    });

    test('never treats a child id or six-character code as a credential', () {
      expect(
        extractPairingToken(
          'https://the-guardian.app/child/pair?childId=child123&code=ABC123',
        ),
        isNull,
      );
      expect(extractPairingToken('child123'), isNull);
    });
  });
}
