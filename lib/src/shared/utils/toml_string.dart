/// Una cadena TOML básica (entre comillas dobles), con lo que hay que
/// escapar escapado: barra, comilla, salto de línea, tabulación y los demás
/// caracteres de control. La usan los overrides `-c clave=valor` que se le
/// pasan a codex y la config de hooks: un system prompt con comillas o un
/// matcher con `|` no pueden romper el argumento entero.
String tomlString(String value) {
  final buffer = StringBuffer('"');
  for (final rune in value.runes) {
    switch (rune) {
      case 0x5C:
        buffer.write(r'\\');
      case 0x22:
        buffer.write(r'\"');
      case 0x0A:
        buffer.write(r'\n');
      case 0x0D:
        buffer.write(r'\r');
      case 0x09:
        buffer.write(r'\t');
      case 0x08:
        buffer.write(r'\b');
      case 0x0C:
        buffer.write(r'\f');
      case < 0x20 || 0x7F:
        buffer.write('\\u${rune.toRadixString(16).padLeft(4, '0')}');
      default:
        buffer.writeCharCode(rune);
    }
  }
  buffer.write('"');
  return buffer.toString();
}
