import 'package:flutter/material.dart';

Color contextUsageColor(double ratio) {
  if (ratio >= 0.95) return const Color(0xFFB71C1C);
  if (ratio >= 0.80) return Colors.red;
  if (ratio >= 0.65) return const Color(0xFFFF8A80);
  if (ratio >= 0.50) return Colors.amber;
  return Colors.green;
}
