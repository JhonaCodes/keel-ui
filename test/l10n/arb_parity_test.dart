import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The three catalogs have to carry the same keys. Nothing else enforces it:
/// `flutter gen-l10n` fills a missing Spanish key with the English string and
/// says nothing, so a half-translated feature ships looking translated. That is
/// exactly how the rail ended up in English while the sidebar next to it stayed
/// in Spanish.
void main() {
  Map<String, dynamic> load(String name) =>
      jsonDecode(File('lib/l10n/$name').readAsStringSync())
          as Map<String, dynamic>;

  Set<String> keysOf(Map<String, dynamic> arb) =>
      arb.keys.where((key) => !key.startsWith('@')).toSet();

  late Map<String, dynamic> en;
  late Map<String, dynamic> es;
  late Map<String, dynamic> esCo;

  setUpAll(() {
    en = load('app_en.arb');
    es = load('app_es.arb');
    esCo = load('app_es_CO.arb');
  });

  test('every catalog declares the same keys', () {
    final english = keysOf(en);
    expect(
      keysOf(es).difference(english),
      isEmpty,
      reason: 'app_es.arb declares keys app_en.arb does not',
    );
    expect(
      english.difference(keysOf(es)),
      isEmpty,
      reason: 'app_es.arb is missing keys; gen-l10n would fall back to English',
    );
    expect(
      english.difference(keysOf(esCo)),
      isEmpty,
      reason: 'app_es_CO.arb is missing keys',
    );
  });

  test('no key is left empty', () {
    for (final arb in [en, es, esCo]) {
      for (final key in keysOf(arb)) {
        expect(
          (arb[key] as String).trim(),
          isNotEmpty,
          reason: '$key is empty',
        );
      }
    }
  });

  test('placeholders match between English and Spanish', () {
    final placeholder = RegExp(r'\{(\w+)\}');
    for (final key in keysOf(en)) {
      Set<String> names(String value) =>
          placeholder.allMatches(value).map((m) => m.group(1)!).toSet();
      expect(
        names(es[key] as String),
        names(en[key] as String),
        reason: '$key uses different placeholders in Spanish',
      );
    }
  });
}
