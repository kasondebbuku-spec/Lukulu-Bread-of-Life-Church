import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/models/phone_login.dart';

void main() {
  group('normalizePhone', () {
    test('turns every usual way of writing a Zambian number into one form', () {
      for (final typed in [
        '0971234567',
        '097 123 4567',
        '097-123-4567',
        '+260971234567',
        '+260 97 123 4567',
        '260971234567',
        '00260971234567',
        '971234567',
        '(097) 123.4567',
        '  0971234567  ',
      ]) {
        expect(normalizePhone(typed), '260971234567', reason: typed);
      }
    });

    test('keeps a foreign number that starts with a plus', () {
      expect(normalizePhone('+27 82 123 4567'), '27821234567');
      expect(normalizePhone('+44 7911 123456'), '447911123456');
    });

    test('refuses things that are not phone numbers', () {
      for (final typed in [
        '',
        '   ',
        'abc',
        '097abc4567',
        'me@example.com',
        '12345',
        '0971234', // too short
        '09712345678901234567', // too long
        '+260 97 123 456', // a Zambian number is nine digits after 260
        '+260 97 123 45678',
      ]) {
        expect(normalizePhone(typed), isNull, reason: typed);
      }
    });
  });

  group('the private sign-in address', () {
    test('is made from the number and recognised again', () {
      final email = phoneLoginEmail('260971234567');
      expect(email, '260971234567@phone.lukulu-bread-of-life.app');
      expect(isPhoneLoginEmail(email), isTrue);
      expect(isPhoneLoginEmail(email.toUpperCase()), isTrue);
      expect(phoneFromLoginEmail(email), '260971234567');
    });

    test('is not mistaken for a real email', () {
      expect(isPhoneLoginEmail('mary@gmail.com'), isFalse);
      expect(isPhoneLoginEmail(null), isFalse);
      expect(phoneFromLoginEmail('mary@gmail.com'), isNull);
      expect(phoneFromLoginEmail(null), isNull);
    });

    test('the number is shown with a plus', () {
      expect(formatPhone('260971234567'), '+260971234567');
    });
  });

  group('looksLikePhone', () {
    test('tells a phone number from an email', () {
      expect(looksLikePhone('0971234567'), isTrue);
      expect(looksLikePhone('+260 97 123 4567'), isTrue);
      expect(looksLikePhone('mary@gmail.com'), isFalse);
      expect(looksLikePhone('mary1234567@gmail.com'), isFalse);
      expect(looksLikePhone('mary'), isFalse);
      expect(looksLikePhone('123'), isFalse);
      expect(looksLikePhone(''), isFalse);
    });
  });
}
