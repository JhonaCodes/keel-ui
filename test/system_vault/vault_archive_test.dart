import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/system_vault/system_vault.dart';

VaultContents _sampleContents() => VaultContents(
  catalog: {
    'skills': [
      {'name': 'revisión-de-código', 'content': 'Mirá el diff, no el archivo.'},
      {'name': 'ux/ui', 'content': 'Nombre con barra: no abre carpeta.'},
    ],
    'stations': [
      {'name': 'keel-ui', 'purpose': 'La app'},
    ],
  },
  settings: const {'chatFontScale': 0.9, 'extraAllowedTools': ['Bash']},
  secrets: const [
    {'name': 'LINEAR_API_KEY', 'description': 'Para el bot de tickets'},
  ],
  knowledgeDocs: {
    'apuntes': {
      'INDEX.md': Uint8List.fromList(utf8.encode('# Índice\nCon acentos: ñ á')),
      'img/logo.bin': Uint8List.fromList([0, 1, 2, 255, 254, 0, 128]),
      'stacks/flutter.md': Uint8List.fromList(utf8.encode('reglas')),
    },
  },
);

void main() {
  group('encodeVault / decodeVault', () {
    test('el round-trip devuelve lo mismo, con acentos y con binarios', () {
      final original = _sampleContents();
      final restored = decodeVault(encodeVault(original));

      expect(restored.catalog['skills'], original.catalog['skills']);
      expect(restored.catalog['stations'], original.catalog['stations']);
      expect(restored.settings, original.settings);
      expect(restored.secrets, original.secrets);
      expect(
        restored.knowledgeDocs['apuntes']!['INDEX.md'],
        original.knowledgeDocs['apuntes']!['INDEX.md'],
      );
      // Un binario tiene que volver byte por byte: si el códec lo hubiera
      // pasado por utf8, acá se rompe.
      expect(
        restored.knowledgeDocs['apuntes']!['img/logo.bin'],
        original.knowledgeDocs['apuntes']!['img/logo.bin'],
      );
      // Una ruta con subcarpeta no se aplana ni se parte mal.
      expect(
        restored.knowledgeDocs['apuntes']!.keys,
        containsAll(['INDEX.md', 'img/logo.bin', 'stacks/flutter.md']),
      );
    });

    test('un nombre con barra no abre una carpeta en el zip', () {
      final archive = ZipDecoder().decodeBytes(encodeVault(_sampleContents()));
      expect(
        archive.files.map((file) => file.name),
        contains('catalog/skills/ux_ui.json'),
      );
    });

    test('el mismo contenido da bytes idénticos', () {
      // De esto depende que respaldar dos veces sin cambios no deje un blob
      // nuevo en git. Si acá aparece un DateTime.now(), el test lo caza.
      final first = encodeVault(_sampleContents());
      final second = encodeVault(_sampleContents());
      expect(first, orderedEquals(second));
    });

    test('el manifest cuenta lo que realmente entró', () {
      final restored = decodeVault(encodeVault(_sampleContents()));
      expect(restored.catalogCount, 3);
      expect(restored.documentCount, 3);
    });

    test('un zip que no es un respaldo da un error nombrado', () {
      final foreign = Archive()
        ..add(ArchiveFile('leeme.txt', 4, utf8.encode('hola')));
      final bytes = Uint8List.fromList(ZipEncoder().encodeBytes(foreign));

      expect(
        () => decodeVault(bytes),
        throwsA(
          isA<VaultFormatException>().having(
            (error) => error.message,
            'message',
            contains('no es un respaldo de keel'),
          ),
        ),
      );
    });

    test('algo que ni siquiera es un zip da un error nombrado', () {
      expect(
        () => decodeVault(Uint8List.fromList(utf8.encode('esto no es un zip'))),
        throwsA(isA<VaultFormatException>()),
      );
    });

    test('un manifest roto se reporta como tal, no explota crudo', () {
      final broken = Archive()
        ..add(ArchiveFile('manifest.json', 1, utf8.encode('{')));
      final bytes = Uint8List.fromList(ZipEncoder().encodeBytes(broken));

      expect(
        () => decodeVault(bytes),
        throwsA(
          isA<VaultFormatException>().having(
            (error) => error.message,
            'message',
            contains('manifest.json'),
          ),
        ),
      );
    });
  });
}
