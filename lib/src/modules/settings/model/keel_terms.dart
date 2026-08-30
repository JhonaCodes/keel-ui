/// Los términos de uso de Keel, tal como se muestran en la app.
///
/// Están escritos como datos y no dentro de un widget por una razón práctica:
/// un término que se lee en pantalla y otro que dice el `LICENSE` es un
/// problema, y teniéndolos acá hay UN solo lugar donde cambiarlos.
///
/// El tono es el de alguien explicando su herramienta, no el de un contrato
/// de banco. Lo que sí es literal es el alcance: lo que dice la sección de
/// datos es lo que el código hace, no lo que sería lindo que hiciera.
///
/// El texto sale de [AppLocalizations] porque se muestra al usuario: cada
/// sección viaja traducida, no hardcodeada en un solo idioma.
library;

import 'package:keel_ui/l10n/generated/app_localizations.dart';

/// Un bloque de los términos: un título y lo que dice.
typedef TermsSection = ({String title, String body});

abstract final class KeelTerms {
  /// Qué versión está leyendo la persona. Sirve para poder decir "aceptaste
  /// la 1" cuando la 2 diga otra cosa.
  static String version(AppLocalizations t) => t.termsVersion;

  static List<TermsSection> sections(AppLocalizations t) => [
    (title: t.termsSection1Title, body: t.termsSection1Body),
    (title: t.termsSection2Title, body: t.termsSection2Body),
    (title: t.termsSection3Title, body: t.termsSection3Body),
    (title: t.termsSection4Title, body: t.termsSection4Body),
    (title: t.termsSection5Title, body: t.termsSection5Body),
    (title: t.termsSection6Title, body: t.termsSection6Body),
    (title: t.termsSection7Title, body: t.termsSection7Body),
    (title: t.termsSection8Title, body: t.termsSection8Body),
    (title: t.termsSection9Title, body: t.termsSection9Body),
    (title: t.termsSection10Title, body: t.termsSection10Body),
    (title: t.termsSection11Title, body: t.termsSection11Body),
    (title: t.termsSection12Title, body: t.termsSection12Body),
    (title: t.termsSection13Title, body: t.termsSection13Body),
    (title: t.termsSection14Title, body: t.termsSection14Body),
    (title: t.termsSection15Title, body: t.termsSection15Body),
    (title: t.termsSection16Title, body: t.termsSection16Body),
    (title: t.termsSection17Title, body: t.termsSection17Body),
    (title: t.termsSection18Title, body: t.termsSection18Body),
    (title: t.termsSection19Title, body: t.termsSection19Body),
    (title: t.termsSection20Title, body: t.termsSection20Body),
  ];
}
