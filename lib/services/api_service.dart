import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/juego.dart';
import '../models/ticket.dart';
import 'session_controller.dart';

/// El backend devolvió 401 en un endpoint protegido.
class SesionExpiradaException implements Exception {
  const SesionExpiradaException();

  @override
  String toString() => 'Tu sesión expiró. Inicia sesión nuevamente.';
}

class ApiService {
  // Backend fijo en Render (https:// + puerto 443, sin :3000).
  static String baseUrl = 'https://indiehud-backend.onrender.com/api';

  // Cliente HTTP inyectable: permite pruebas unitarias con MockClient.
  static http.Client httpClient = http.Client();

  // Render puede tardar ~20 s en despertar (plan gratuito).
  static Duration timeout = const Duration(seconds: 40);

  static const _claveToken = 'jwt_token';
  static const _claveNombre = 'usuario_nombre';
  static const _claveCorreo = 'usuario_correo';
  static const _claveFoto = 'usuario_foto_url';

  static const _claveBioToken = 'biometrica_token';
  static const _claveBioNombre = 'biometrica_nombre';
  static const _claveBioCorreo = 'biometrica_correo';
  static const _claveBioActiva = 'biometrica_activa';

  /// Sincroniza el menú con la sesión persistida al arrancar la app.
  static Future<void> sincronizarSesion() async {
    final token = await leerToken();
    SessionController.activa.value = token != null && token.isNotEmpty;
  }

  /// Calienta el backend en segundo plano al arrancar la app.
  static Future<void> calentarBackend() async {
    try {
      await httpClient.get(Uri.parse('$baseUrl/juegos')).timeout(timeout);
    } catch (_) {
      // El fallback offline y los mensajes de error se encargan del resto.
    }
  }

  /// Decodifica JSON sin lanzar FormatException si Render devuelve HTML (503).
  static dynamic _decode(String body) {
    try {
      return json.decode(body);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _mapa(String body) {
    final decoded = _decode(body);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  /// Acepta tanto un array plano como el envelope paginado del backend.
  static List<dynamic>? _lista(String body) {
    final decoded = _decode(body);
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic>) {
      final datos = decoded['datos'] ?? decoded['data'];
      if (datos is List) return datos;
    }
    return null;
  }

  static String _error(Map<String, dynamic> data, String porDefecto) =>
      data['error']?.toString() ?? porDefecto;

  // ==========================================================
  // SESIÓN
  // ==========================================================
  static Future<void> guardarSesion(
    String token,
    String nombre,
    String correo, {
    String? fotoUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveToken, token);
    await prefs.setString(_claveNombre, nombre);
    await prefs.setString(_claveCorreo, correo);
    if (fotoUrl != null) await prefs.setString(_claveFoto, fotoUrl);
    SessionController.activa.value = true;
  }

  static Future<String?> leerToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_claveToken);
  }

  static Future<Map<String, String?>> leerUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'nombre': prefs.getString(_claveNombre),
      'correo': prefs.getString(_claveCorreo),
      'foto_url': prefs.getString(_claveFoto),
    };
  }

  static Future<void> cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    // Conserva el token biométrico para permitir "Entrar con huella".
    for (final clave in [_claveToken, _claveNombre, _claveCorreo, _claveFoto]) {
      await prefs.remove(clave);
    }
    SessionController.activa.value = false;
  }

  // ==========================================================
  // BIOMETRÍA LOCAL
  // ==========================================================
  static Future<void> guardarBiometria(
    String token,
    String nombre,
    String correo,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveBioToken, token);
    await prefs.setString(_claveBioNombre, nombre);
    await prefs.setString(_claveBioCorreo, correo);
    await prefs.setBool(_claveBioActiva, true);
  }

  static Future<bool> biometriaActiva() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_claveBioActiva) ?? false;
  }

  static Future<Map<String, String?>> leerBiometria() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'token': prefs.getString(_claveBioToken),
      'nombre': prefs.getString(_claveBioNombre),
      'correo': prefs.getString(_claveBioCorreo),
    };
  }

  static Future<void> olvidarBiometria() async {
    final prefs = await SharedPreferences.getInstance();
    for (final clave in [
      _claveBioToken,
      _claveBioNombre,
      _claveBioCorreo,
      _claveBioActiva,
    ]) {
      await prefs.remove(clave);
    }
  }

  static Future<bool> restaurarSesionBiometrica() async {
    final datos = await leerBiometria();
    final token = datos['token'];
    if (token == null || token.isEmpty) return false;
    await guardarSesion(token, datos['nombre'] ?? 'Jugador', datos['correo'] ?? '');
    return true;
  }

  // ==========================================================
  // CATÁLOGO
  // ==========================================================
  static Future<List<Juego>> obtenerJuegos({String? buscar, String? categoria}) async {
    final Map<String, String> queryParams = {};

    if (buscar != null && buscar.trim().isNotEmpty) {
      queryParams['buscar'] = buscar.trim();
    }
    if (categoria != null && categoria.trim().isNotEmpty && categoria != 'Todos') {
      queryParams['categoria'] = categoria.trim();
    }

    final uri = Uri.parse('$baseUrl/juegos').replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    final response = await httpClient.get(uri).timeout(timeout);
    if (response.statusCode == 401) throw const SesionExpiradaException();

    final datos = _lista(response.body);
    if (response.statusCode == 200 && datos != null) {
      return datos
          .map((juego) => Juego.fromJson(juego as Map<String, dynamic>))
          .toList();
    }
    throw Exception('No fue posible obtener la información.');
  }

  static Future<List<String>> obtenerCategorias() async {
    final response =
        await httpClient.get(Uri.parse('$baseUrl/categorias')).timeout(timeout);
    if (response.statusCode != 200) {
      throw Exception('No fue posible obtener las categorías.');
    }
    final datos = _lista(response.body);
    if (datos == null) throw Exception('No fue posible obtener las categorías.');
    return datos.map((c) => c.toString()).toList();
  }

  // ==========================================================
  // AUTENTICACIÓN
  // ==========================================================
  static Future<void> registrar(String nombre, String correo, String password) async {
    final response = await httpClient.post(
      Uri.parse('$baseUrl/registro'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'nombre': nombre, 'correo': correo, 'password': password}),
    ).timeout(timeout);

    if (response.statusCode != 201) {
      throw Exception(_error(_mapa(response.body), 'Error al registrar usuario'));
    }
  }

  static Future<Map<String, dynamic>> login(String correo, String password) async {
    final response = await httpClient.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'correo': correo, 'password': password}),
    ).timeout(timeout);

    final data = _mapa(response.body);
    if (response.statusCode != 200) {
      throw Exception(_error(data, 'Correo o contraseña incorrectos'));
    }

    final usuario = data['usuario'] is Map<String, dynamic>
        ? data['usuario'] as Map<String, dynamic>
        : <String, dynamic>{};

    await guardarSesion(
      data['token']?.toString() ?? '',
      usuario['nombre']?.toString() ?? 'Jugador',
      usuario['correo']?.toString() ?? correo,
      fotoUrl: usuario['foto_url']?.toString(),
    );
    return data;
  }

  // ==========================================================
  // PERFIL
  // ==========================================================
  static Future<Map<String, dynamic>> obtenerPerfil() async {
    final token = await leerToken();
    if (token == null) throw const SesionExpiradaException();
    final response = await httpClient.get(
      Uri.parse('$baseUrl/usuarios/perfil'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(timeout);
    if (response.statusCode == 401) throw const SesionExpiradaException();
    if (response.statusCode != 200) {
      throw Exception(_error(_mapa(response.body), 'No se pudo cargar tu perfil'));
    }
    return _mapa(response.body);
  }

  static Future<Map<String, dynamic>> actualizarPerfil({
    required String nombre,
    required String correo,
    String? fotoUrl,
  }) async {
    final token = await leerToken();
    if (token == null) throw const SesionExpiradaException();

    final body = <String, dynamic>{'nombre': nombre, 'correo': correo};
    if (fotoUrl != null) body['foto_url'] = fotoUrl;

    final response = await httpClient.put(
      Uri.parse('$baseUrl/usuarios/perfil'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(body),
    ).timeout(timeout);

    if (response.statusCode == 401) throw const SesionExpiradaException();
    final data = _mapa(response.body);
    if (response.statusCode != 200) {
      throw Exception(_error(data, 'No se pudo actualizar el perfil'));
    }

    final usuario = data['usuario'] is Map<String, dynamic>
        ? data['usuario'] as Map<String, dynamic>
        : <String, dynamic>{};
    await guardarSesion(
      data['token']?.toString() ?? token,
      usuario['nombre']?.toString() ?? nombre,
      usuario['correo']?.toString() ?? correo,
      fotoUrl: usuario['foto_url']?.toString(),
    );
    return data;
  }

  static Future<void> cambiarPassword(String actual, String nueva) async {
    final token = await leerToken();
    if (token == null) throw const SesionExpiradaException();

    final response = await httpClient.put(
      Uri.parse('$baseUrl/usuarios/password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({'actual': actual, 'nueva': nueva}),
    ).timeout(timeout);

    if (response.statusCode == 401) {
      throw Exception(_error(_mapa(response.body), 'La contraseña actual no es correcta'));
    }
    if (response.statusCode != 200) {
      throw Exception(_error(_mapa(response.body), 'No se pudo cambiar la contraseña'));
    }
  }

  static Future<void> actualizarBiometriaRemota(bool activa) async {
    final token = await leerToken();
    if (token == null) return;
    try {
      await httpClient.patch(
        Uri.parse('$baseUrl/usuarios/biometria'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'activa': activa}),
      ).timeout(timeout);
    } catch (_) {
      // La preferencia local ya quedó guardada; el backend puede estar viejo.
    }
  }

  static Future<String> subirFotoPerfil(XFile archivo) async {
    final token = await leerToken();
    if (token == null) throw const SesionExpiradaException();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/usuarios/foto'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes(
      'foto',
      await archivo.readAsBytes(),
      filename: archivo.name,
    ));

    final streamed = await httpClient.send(request).timeout(timeout);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 401) throw const SesionExpiradaException();
    final data = _mapa(response.body);
    if (response.statusCode != 200) {
      throw Exception(_error(data, 'No se pudo subir la foto'));
    }
    return data['foto_url']?.toString() ?? '';
  }

  // ==========================================================
  // BIBLIOTECA
  // ==========================================================
  static Future<List<Juego>> obtenerBiblioteca() async {
    final token = await leerToken();
    if (token == null) throw Exception('No has iniciado sesión');

    final response = await httpClient.get(
      Uri.parse('$baseUrl/biblioteca'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(timeout);

    if (response.statusCode == 401) throw const SesionExpiradaException();
    final datos = _lista(response.body);
    if (response.statusCode == 200 && datos != null) {
      return datos
          .map((juego) => Juego.fromJson(juego as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Error al obtener tu biblioteca');
  }

  static Future<void> comprarJuego(int juegoId) async {
    final token = await leerToken();
    if (token == null) {
      throw Exception('Inicia sesión para comprar');
    }

    final response = await httpClient.post(
      Uri.parse('$baseUrl/biblioteca/comprar'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({'juego_id': juegoId}),
    ).timeout(timeout);

    if (response.statusCode == 401) throw const SesionExpiradaException();
    if (response.statusCode != 201) {
      throw Exception(_error(_mapa(response.body), 'No se pudo completar la compra'));
    }
  }

  /// IDs de los juegos ya adquiridos, para no volver a ofrecer la compra.
  static Future<Set<int>> obtenerIdsBiblioteca() async {
    final token = await leerToken();
    if (token == null) throw const SesionExpiradaException();

    final response = await httpClient.get(
      Uri.parse('$baseUrl/biblioteca/ids'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(timeout);

    if (response.statusCode == 401) throw const SesionExpiradaException();
    final datos = _lista(response.body);
    if (response.statusCode == 200 && datos != null) {
      return datos
          .map((id) => int.tryParse(id.toString()))
          .whereType<int>()
          .toSet();
    }
    throw Exception('No fue posible comprobar tu biblioteca.');
  }

  /// Elimina la compra del servidor para el usuario autenticado.
  static Future<void> eliminarDeBiblioteca(int juegoId) async {
    final token = await leerToken();
    if (token == null) throw const SesionExpiradaException();

    final response = await httpClient.delete(
      Uri.parse('$baseUrl/biblioteca/$juegoId'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(timeout);

    if (response.statusCode == 401) throw const SesionExpiradaException();
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(
        _error(_mapa(response.body), 'No se pudo eliminar de tu biblioteca'),
      );
    }
  }

  // ==========================================================
  // TICKETS
  // ==========================================================
  static Future<Ticket> crearTicket({
    required String asunto,
    required String descripcion,
    required String prioridad,
  }) async {
    final token = await leerToken();
    if (token == null) {
      throw Exception('Inicia sesión para crear un ticket');
    }

    final response = await httpClient.post(
      Uri.parse('$baseUrl/tickets'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'asunto': asunto,
        'descripcion': descripcion,
        'prioridad': prioridad,
      }),
    ).timeout(timeout);

    if (response.statusCode == 401) throw const SesionExpiradaException();
    final data = _mapa(response.body);
    if (response.statusCode == 201) {
      return Ticket.fromJson(data['ticket'] ?? data);
    }
    throw Exception(_error(data, 'No se pudo crear el ticket'));
  }

  static Future<List<Ticket>> obtenerTickets() async {
    final token = await leerToken();
    if (token == null) throw Exception('Inicia sesión para ver tus tickets');

    final response = await httpClient.get(
      Uri.parse('$baseUrl/tickets'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(timeout);

    if (response.statusCode == 401) throw const SesionExpiradaException();
    final datos = _lista(response.body);
    if (response.statusCode == 200 && datos != null) {
      return datos
          .map((ticket) => Ticket.fromJson(ticket as Map<String, dynamic>))
          .toList();
    }
    throw Exception('No se pudieron obtener tus tickets');
  }

  // ==========================================================
  // BIOMETRÍA WEB -> APP
  // ==========================================================
  static Future<Map<String, dynamic>> solicitarBiometriaWeb(
    String correo,
    String password,
  ) async {
    final response = await httpClient.post(
      Uri.parse('$baseUrl/biometria/solicitar'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'correo': correo, 'password': password}),
    ).timeout(timeout);

    final data = _mapa(response.body);
    if (response.statusCode != 201) {
      throw Exception(_error(data, 'No se pudo solicitar la verificación'));
    }
    return data;
  }

  static Future<List<Map<String, dynamic>>> obtenerSolicitudesWeb() async {
    final token = await leerToken();
    if (token == null) return <Map<String, dynamic>>[];
    try {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/biometria/pendientes'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(timeout);
      if (response.statusCode == 401) throw const SesionExpiradaException();
      if (response.statusCode != 200) return <Map<String, dynamic>>[];
      final datos = _lista(response.body) ?? <dynamic>[];
      return datos
          .whereType<Map<String, dynamic>>()
          .map((s) => Map<String, dynamic>.from(s))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static Future<void> responderSolicitudWeb(String id, bool aprobar) async {
    final token = await leerToken();
    if (token == null) throw const SesionExpiradaException();

    final response = await httpClient.post(
      Uri.parse('$baseUrl/biometria/responder'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({'solicitud_id': id, 'aprobar': aprobar}),
    ).timeout(timeout);

    if (response.statusCode == 401) throw const SesionExpiradaException();
    if (response.statusCode != 200) {
      throw Exception(_error(_mapa(response.body), 'No se pudo responder'));
    }
  }

  /// Devuelve 'pendiente', 'aprobada' o 'rechazada'.
  static Future<String> verificarSolicitudWeb(String id) async {
    final response = await httpClient.post(
      Uri.parse('$baseUrl/biometria/token'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'solicitud_id': id}),
    ).timeout(timeout);

    if (response.statusCode == 200) {
      final data = _mapa(response.body);
      final usuario = data['usuario'] is Map<String, dynamic>
          ? data['usuario'] as Map<String, dynamic>
          : <String, dynamic>{};
      await guardarSesion(
        data['token']?.toString() ?? '',
        usuario['nombre']?.toString() ?? 'Jugador',
        usuario['correo']?.toString() ?? '',
        fotoUrl: usuario['foto_url']?.toString(),
      );
      return 'aprobada';
    }
    if (response.statusCode == 202) return 'pendiente';
    if (response.statusCode == 403 || response.statusCode == 410) {
      return 'rechazada';
    }
    throw Exception(_error(_mapa(response.body), 'No se pudo verificar la solicitud'));
  }
}
