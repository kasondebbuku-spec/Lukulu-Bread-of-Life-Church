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

  group('numbers as people really type and paste them', () {
    test('every one of these is the same number', () {
      for (final typed in [
        '+260 0971234567', // the local 0 left in after 260
        '2600971234567',
        '+260 (0) 97 1234567',
        '00260 0971234567',
        '\u202A+260 97 1234567\u202C', // copied from contacts
        '\u200E0971234567',
        '097\u20111234567', // a different dash
        '097\u20131234567',
        '097\u00a0123\u00a04567', // a non-breaking space
        '097\u2009123\u20094567',
        '097/123/4567',
        '097,123,4567',
        '097.123.4567',
        '097_123_4567',
        '+260-97-123-4567',
        '097 123 4567\n',
      ]) {
        expect(normalizePhone(typed), '260971234567',
            reason: typed.runes.map((r) => r.toRadixString(16)).join(' '));
      }
    });

    test('letters or an @ still mean it is not a number', () {
      for (final typed in ['097abc4567', 'o971234567', '0971234567@x.com', 'mary']) {
        expect(normalizePhone(typed), isNull, reason: typed);
      }
    });
  });

  group('what the box shows as you type', () {
    test('a local number is spaced 3, 3, 4', () {
      expect(formatSignInEntry('097'), '097');
      expect(formatSignInEntry('0971'), '097 1');
      expect(formatSignInEntry('097123'), '097 123');
      expect(formatSignInEntry('0971234567'), '097 123 4567');
    });

    test('an international number is spaced +260 97 123 4567', () {
      expect(formatSignInEntry('+260'), '+260');
      expect(formatSignInEntry('+26097'), '+260 97');
      expect(formatSignInEntry('+260971234567'), '+260 97 123 4567');
      expect(formatSignInEntry('+2600971234567'), '+260 97 123 4567');
    });

    test('formatting twice changes nothing, so typing never fights it', () {
      for (final typed in ['0971234567', '097123', '+260971234567', 'me@x.com', '+4479111']) {
        final once = formatSignInEntry(typed);
        expect(formatSignInEntry(once), once, reason: typed);
      }
    });

    test('deleting from the end works one digit at a time', () {
      var text = formatSignInEntry('0971234567');
      var steps = 0;
      while (text.isNotEmpty && steps < 20) {
        text = formatSignInEntry(text.substring(0, text.length - 1));
        expect(text.endsWith(' '), isFalse);
        steps++;
      }
      expect(text, '');
    });

    test('too long a number is left for the message to explain', () {
      expect(formatSignInEntry('09712345678'), '09712345678');
    });

    test('an email never keeps spaces, even one that starts with digits', () {
      expect(formatSignInEntry('097 123 j'), '097123j');
      expect(formatSignInEntry('097 123@gmail.com'), '097123@gmail.com');
      expect(formatSignInEntry(' mary@x.com '), 'mary@x.com');
      expect(formatSignInEntry(''), '');
    });

    test('what is shown still reads as the same number', () {
      for (final typed in ['0971234567', '+260971234567', '971234567']) {
        expect(normalizePhone(formatSignInEntry(typed)), '260971234567', reason: typed);
      }
    });
  });

  group('saying what is wrong', () {
    test('counts the digits', () {
      expect(phoneProblem('097 123 456'),
          'Too short: a number like 0971234567 has 10 digits (this has 9)');
      expect(phoneProblem('09712345678'),
          'Too long: a number like 0971234567 has 10 digits (this has 11)');
      expect(phoneProblem('+260 97 123 456'),
          'Too short: a number like 260971234567 has 12 digits (this has 11)');
      expect(phoneProblem('12345'), 'Enter a number like 0971234567 or +260971234567');
    });

    test('the number is read back in a friendly shape', () {
      expect(prettyPhone('260971234567'), '+260 97 123 4567');
      expect(prettyPhone('447911123456'), '+447911123456');
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
