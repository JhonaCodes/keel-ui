part of '../keel_api.dart';

/// Defensive reading of what keel-api answers.
///
/// Some fields are JSON **inside a string** (`payload_json`, `result_json`)
/// and the API never validates them, so every decoder here answers the empty
/// form instead of throwing: a model is never built from a crash.
abstract final class KeelJson {
  /// An embedded JSON object; `{}` for null, blank or unreadable text, and
  /// for valid JSON that is not an object.
  static Map<String, dynamic> decodeObject(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return const <String, dynamic>{};
    try {
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic>
          ? decoded
          : const <String, dynamic>{};
    } on FormatException {
      return const <String, dynamic>{};
    }
  }

  /// Whether [raw] is a JSON object, the only shape `payload_json` takes.
  static bool isObject(String raw) {
    try {
      return jsonDecode(raw.trim()) is Map<String, dynamic>;
    } on FormatException {
      return false;
    }
  }

  /// What is sent back inside one of those string fields.
  static String encode(Object? value) => jsonEncode(value);

  /// A timestamp as keel-api writes most of them: `YYYY-MM-DD HH:MM:SS`, UTC,
  /// without a zone. RFC 3339 with its zone is accepted too.
  static DateTime? decodeTimestamp(Object? raw) {
    if (raw is! String) return null;
    final text = raw.trim();
    if (text.isEmpty) return null;
    final hasZone =
        text.endsWith('Z') || RegExp(r'[+-]\d\d:?\d\d$').hasMatch(text);
    return DateTime.tryParse(hasZone ? text : '${text}Z')?.toLocal();
  }

  /// An int sent as a number or as text.
  static int? decodeInt(Object? value) => switch (value) {
    final int number => number,
    final double number => number.toInt(),
    final String text => int.tryParse(text.trim()),
    _ => null,
  };

  /// A bool sent as a bool or as text.
  static bool decodeBool(Object? value, {bool fallback = false}) =>
      switch (value) {
        final bool flag => flag,
        'true' => true,
        'false' => false,
        _ => fallback,
      };

  /// A non-blank string, or null.
  static String? decodeText(Object? value) => switch (value) {
    final String text when text.trim().isNotEmpty => text,
    _ => null,
  };
}
