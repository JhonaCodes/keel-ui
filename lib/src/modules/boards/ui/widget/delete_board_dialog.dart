import 'package:flutter/material.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/core/ui/confirm_card.dart';
import 'package:keel_ui/src/modules/boards/model/board.dart';
import 'package:keel_ui/src/modules/boards/viewmodel/boards_viewmodel.dart';

/// Borrar un tablero, desde donde sea que estés parado.
///
/// Uno solo para los tres lugares que lo ofrecen —el sidebar, la lista del
/// proyecto y el banco—: tres copias del mismo diálogo son tres textos que
/// se van separando.
///
/// Con un botón y no escribiendo el nombre, al revés que un proyecto: un
/// tablero se vuelve a pedir en un mensaje.
Future<bool> confirmAndDeleteBoard(BuildContext context, Board board) async {
  final confirmed = await confirmWithCard(
    context,
    title: AppLocalizations.of(context).confirmationDeleteTitle('tablero'),
    body:
        'Se elimina "${board.name}" y sus corridas guardadas. Lo que ya '
        'disparaste contra tu API no se deshace.',
    destructive: true,
  );

  if (!confirmed) return false;
  BoardsService.instance.notifier.deleteBoard(board.id);
  return true;
}
