part of '../shared.dart';

extension SmoothBorderExtension on num {
  SmoothRectangleBorder smoothBorder({BorderSide side = BorderSide.none}) {
    return SmoothRectangleBorder(borderRadius: toDouble(), side: side);
  }
}
