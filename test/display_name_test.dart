import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/providers/display_name_provider.dart';

void main() {
  test('profile name wins over everything else', () {
    expect(
        displayNameFor(
            profileName: 'Daniel Thomas',
            authDisplayName: 'dt',
            email: 'x@y.com'),
        'Daniel Thomas');
  });

  test('falls back to auth display name', () {
    expect(displayNameFor(profileName: '  ', authDisplayName: 'Ruth M'), 'Ruth M');
  });

  test('tidies up the email prefix as a last resort', () {
    expect(displayNameFor(email: 'daniel.thomas@test.local'), 'Daniel Thomas');
    expect(displayNameFor(email: 'kaskas@gmail.com'), 'Kaskas');
  });

  test('never uses the made-up address of a phone account as a name', () {
    const email = '260971234567@phone.lukulu-bread-of-life.app';
    expect(displayNameFor(email: email), 'User');
    expect(displayNameFor(email: email, profileName: 'John Phiri'), 'John Phiri');
    expect(displayNameFor(email: email, authDisplayName: 'John Phiri'), 'John Phiri');
  });

  test('uses a safe default when nothing is known', () {
    expect(displayNameFor(), 'User');
  });
}
