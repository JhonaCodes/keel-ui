/// La base entera en memoria, indexada por clave.
///
/// Existe porque `flutter_local_db` no tiene consulta por prefijo: solo sabe
/// devolver UNA clave o TODA la base. Y devolver toda la base no es barato —
/// serializa a JSON, cruza el FFI, se decodifica, y después se re-serializa y
/// re-parsea registro por registro— así que hacerlo una vez por cada consulta
/// por prefijo era leer 5,5 MB veinte veces seguidas para arrancar.
///
/// Acá no hay I/O ni FFI: es un mapa y tres operaciones. Se separa del
/// [LocalDatabase] justamente para poder probar la parte que, si se
/// desincroniza, hace que la UI muestre datos viejos.
class KeyIndex {
  KeyIndex([Map<String, Map<String, dynamic>>? initial])
    : _byKey = {
        for (final entry in (initial ?? const {}).entries)
          entry.key: Map<String, dynamic>.from(entry.value),
      };

  final Map<String, Map<String, dynamic>> _byKey;

  int get length => _byKey.length;

  /// Todo entra y sale COPIADO.
  ///
  /// Antes cada lectura devolvía objetos recién parseados del JSON, así que
  /// nadie podía pisarle el registro guardado a otro. Devolver la referencia
  /// del índice cambiaría esa regla en silencio: un `record['x'] = y` en
  /// cualquier repositorio corrompería la base en memoria sin un solo error.
  /// La copia es un mapa chico; lo que se sacó de encima era decodificar
  /// megabytes de JSON.
  Map<String, dynamic> _copy(Map<String, dynamic> data) =>
      Map<String, dynamic>.from(data);

  Map<String, dynamic>? get(String key) {
    final data = _byKey[key];
    return data == null ? null : _copy(data);
  }

  void put(String key, Map<String, dynamic> data) => _byKey[key] = _copy(data);

  void remove(String key) => _byKey.remove(key);

  /// Los registros cuya clave arranca con [prefix], sin la clave.
  ///
  /// Es lo que pide un repositorio: reconstruye la clave desde el `id` del
  /// propio payload.
  List<Map<String, dynamic>> withPrefix(String prefix) => [
    for (final entry in _byKey.entries)
      if (entry.key.startsWith(prefix)) _copy(entry.value),
  ];

  /// Los mismos, pero CON su clave.
  ///
  /// Una migración que renombra prefijos no puede reconstruirla desde el
  /// payload: la clave vieja es justamente lo único que tiene para leer.
  List<({String key, Map<String, dynamic> data})> entriesWithPrefix(
    String prefix,
  ) => [
    for (final entry in _byKey.entries)
      if (entry.key.startsWith(prefix))
        (key: entry.key, data: _copy(entry.value)),
  ];

  /// Aplica encima lo que se escribió mientras el índice se estaba cargando.
  ///
  /// El valor nulo es un borrado. Sin esto, una escritura que cae entre que
  /// se pidió la base y que llegó se perdería del índice y volvería a
  /// aparecer recién en el próximo arranque.
  void applyPending(Map<String, Map<String, dynamic>?> pending) {
    for (final entry in pending.entries) {
      final data = entry.value;
      if (data == null) {
        _byKey.remove(entry.key);
      } else {
        _byKey[entry.key] = _copy(data);
      }
    }
  }
}
