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

  test('uses a safe default when nothing is known', () {
    expect(displayNameFor(), 'User');
  });
}
