import 'package:flutter/widgets.dart';
import 'package:smooth_border/smooth_border.dart';

extension SmoothBorderExtension on num {
  SmoothRectangleBorder smoothBorder({BorderSide side = BorderSide.none}) {
    return SmoothRectangleBorder(borderRadius: toDouble(), side: side);
  }
}
