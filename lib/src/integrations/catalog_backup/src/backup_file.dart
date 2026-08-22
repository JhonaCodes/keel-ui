part of '../catalog_backup.dart';

/// Versión del formato del archivo de respaldo.
///
/// Las secciones elegibles ([BackupSection]) y el preview ([BackupPreview])
/// no viven acá: son de `catalog_shape`, porque el vault hace las mismas dos
/// preguntas —qué viaja y qué pisa— sobre la misma forma.
const kBackupFormatVersion = 1;
