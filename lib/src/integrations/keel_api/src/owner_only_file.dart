part of '../keel_api.dart';

/// A secret kept on disk in a file only this user can read and write (0600):
/// the account's refresh token, the node's own token.
///
/// The file is created empty, restricted to its owner and checked, and only
/// THEN written, so nothing secret is ever on disk with a wider mode. A
/// machine that cannot restrict it keeps nothing.
abstract final class OwnerOnlyFile {
  /// `rw-------`.
  static const int mode = 0x180;

  /// Writes [contents] to [target] through an owner-only staging file that
  /// a rename puts in place (the rename keeps the mode and replaces the old
  /// file in one step). Why not, when it could not; nothing is left behind
  /// then.
  static Future<Result<void, String>> write(
    File target,
    String contents,
  ) async {
    File? staging;
    try {
      await target.parent.create(recursive: true);
      staging = File('${target.path}.part');
      if (await staging.exists()) await staging.delete();
      await staging.create();
      if (!await _restrictToOwner(staging)) {
        await staging.delete();
        return Err('the file could not be made owner-only');
      }
      await staging.writeAsString(contents, flush: true);
      await staging.rename(target.path);
      return Ok(null);
    } on FileSystemException catch (error) {
      if (staging != null && await staging.exists()) await staging.delete();
      return Err(error.message);
    }
  }

  /// `chmod 600`, then checks it took. On Windows the profile's own ACL is
  /// what keeps other users out, and there is no mode to set.
  static Future<bool> _restrictToOwner(File file) async {
    if (Platform.isWindows) return true;
    final result = await Process.run('chmod', ['600', file.path]);
    if (result.exitCode != 0) return false;
    final current = (await file.stat()).mode & 0x1FF;
    return current == mode;
  }
}
