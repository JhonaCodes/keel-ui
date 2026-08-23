/// Quién hizo Keel, dónde encontrarlo y bajo qué condiciones se puede usar.
///
/// Están acá y no escritos dentro del widget porque son datos de la app, no
/// decoración de una pantalla: el aviso de licencia tiene que decir lo mismo
/// en el panel que en cualquier otro lado donde haga falta mostrarlo.
abstract final class KeelAbout {
  /// El canal donde se habla de Keel.
  static const community = 'https://discord.gg/dHesKPVYg';

  static const website = 'https://jhonacode.com';

  /// El único canal autorizado de descarga. Lo dice la licencia y lo dice la
  /// pantalla: una copia que no vino de acá no es responsabilidad del autor.
  static const download = 'https://jhonacode.com';

  static const author = 'JhonaCode';

  static const copyright =
      '© 2026 Jhonatan Ortiz (JhonaCode). Todos los derechos reservados.';

  /// El resumen que se muestra en pantalla. El texto completo está en el
  /// archivo `LICENSE`, y este resumen no lo reemplaza: lo anuncia.
  static const licenseNotice =
      'Software propietario. No es de código abierto: no se puede usar, '
      'copiar, modificar ni distribuir sin permiso escrito del autor. '
      'Distribución exclusiva desde jhonacode.com.';
}
