part of '../keel_node.dart';

/// How this PC names itself as a keel-api node.
abstract final class DesktopNodeIdentity {
  /// keel-api takes node ids of 1 to 100 characters.
  static const int maxId = 100;

  /// keel-api takes labels of up to 200 characters.
  static const int maxLabel = 200;

  static const String _suffix = '-desktop';

  /// `<hostname>-desktop`, as a URL path segment and keel-api take it: lower
  /// case letters, digits and single dashes, without macOS's `.local`. The
  /// id travels in paths (`nodes/{id}/status`), so nothing else goes in it.
  static String idFor(String hostname) {
    final base = _bareHost(hostname)
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final room = maxId - _suffix.length;
    final kept = base.length <= room
        ? base
        : base.substring(0, room).replaceAll(RegExp(r'-+$'), '');
    return '${kept.isEmpty ? 'keel' : kept}$_suffix';
  }

  /// `Keel en <hostname>`: how the app lists this PC.
  static String labelFor(String hostname) {
    final label = 'Keel en ${_bareHost(hostname)}'.trim();
    return label.length <= maxLabel ? label : label.substring(0, maxLabel);
  }

  /// The hostname as the person knows it: `Mac-de-Jhona.local` reads
  /// `Mac-de-Jhona`.
  static String _bareHost(String hostname) => hostname.trim().replaceFirst(
    RegExp(r'\.local$', caseSensitive: false),
    '',
  );
}
