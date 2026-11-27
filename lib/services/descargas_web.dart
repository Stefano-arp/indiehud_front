import 'package:shared_preferences/shared_preferences.dart';

/// Estado local de la biblioteca web (descargas simuladas y favoritos).
///
/// No hay archivos de juegos reales en el proyecto: igual que Steam, la web
/// registra el estado de la descarga y permite administrarlo. El móvil sigue
/// usando SQLite para su copia local.
class DescargasWebService {
  static const String _claveDescargas = 'indiehub_web_descargas';
  static const String _claveFavoritos = 'indiehub_web_favoritos';

  static Future<Set<int>> _leer(String clave) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(clave) ?? [])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
  }

  static Future<void> _guardar(String clave, Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final ordenados = ids.toList()..sort();
    await prefs.setStringList(
      clave,
      ordenados.map((id) => id.toString()).toList(),
    );
  }

  static Future<bool> estaDescargado(int id) async =>
      (await _leer(_claveDescargas)).contains(id);

  static Future<void> marcarDescargado(int id) async {
    final ids = await _leer(_claveDescargas);
    ids.add(id);
    await _guardar(_claveDescargas, ids);
  }

  static Future<void> quitarDescarga(int id) async {
    final ids = await _leer(_claveDescargas);
    ids.remove(id);
    await _guardar(_claveDescargas, ids);
  }

  static Future<bool> esFavorito(int id) async =>
      (await _leer(_claveFavoritos)).contains(id);

  static Future<void> alternarFavorito(int id, {required bool valor}) async {
    final ids = await _leer(_claveFavoritos);
    if (valor) {
      ids.add(id);
    } else {
      ids.remove(id);
    }
    await _guardar(_claveFavoritos, ids);
  }
}
