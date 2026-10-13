import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the church name against slipping back to Flutter's template defaults,
/// which is what people see on the browser tab, when installing the app, and in
/// WhatsApp link previews.
void main() {
  const name = 'Lukulu Bread of Life Church';

  test('index.html carries the church name and link-preview tags', () {
    final html = File('web/index.html').readAsStringSync();
    expect(html, contains('<title>$name</title>'));
    expect(html, contains('property="og:title" content="$name"'));
    expect(html, contains('property="og:image"'));
    expect(html, isNot(contains('church_cms')));
    expect(html, isNot(contains('A new Flutter project')));
  });

  test('the install manifest uses the church name and brand colour', () {
    final manifest =
        jsonDecode(File('web/manifest.json').readAsStringSync()) as Map<String, dynamic>;
    expect(manifest['name'], name);
    expect(manifest['short_name'], isNot('church_cms'));
    expect(manifest['theme_color'], '#2D0060');
    expect(manifest['description'], isNot(contains('Flutter project')));
  });

  test('firebase.json publishes to the church-named site and the original', () {
    final config =
        jsonDecode(File('firebase.json').readAsStringSync()) as Map<String, dynamic>;
    final sites = (config['hosting'] as List).map((h) => h['site']).toList();
    expect(sites, containsAll(['lukulu-bread-of-life', 'kasonde-bbuku']));
  });
}
