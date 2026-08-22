import 'package:flutter/material.dart';

/// The project palette, taken from the mockup. It is deliberately *not* the
/// loose-agent palette: those start on reds and pinks, which read as errors
/// next to the amber accent and made every member look alarming.
///
/// The order matters — the first four are the colours the mockup shows for a
/// four-member project, so a typical project looks exactly like the design.
const kProjectMemberPalette = <Color>[
  Color(0xFF4FA3D9), // azul
  Color(0xFF3FA38C), // verde azulado
  Color(0xFF9B7BC4), // violeta
  Color(0xFFC9A227), // dorado
  Color(0xFF7FB069), // verde
  Color(0xFFD98E5A), // ámbar cálido
  Color(0xFF6C8EBF), // azul acero
  Color(0xFFB57EDC), // lila
];

/// The colour that identifies a member inside one project, assigned by its
/// position in the member list. Past the palette it wraps, which is fine: a
/// project with more than eight members is well beyond what the layout — a
/// facepile and a step list — is meant to show at a glance.
Color memberColorFor(int memberIndex) {
  if (memberIndex < 0) return kProjectMemberPalette.first;
  return kProjectMemberPalette[memberIndex % kProjectMemberPalette.length];
}

/// The palette slot for whoever wrote a message. Current members keep their
/// position-based colour so a project looks like the design; an author that is
/// no longer a member still gets a stable colour of its own, derived from its
/// id, instead of collapsing onto slot 0 and making every avatar look
/// identical.
int authorPaletteIndex(String profileId, List<String> memberIds) {
  final index = memberIds.indexOf(profileId);
  if (index >= 0) return index;

  var hash = 0;
  for (final unit in profileId.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash % kProjectMemberPalette.length;
}
