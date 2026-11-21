import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/juego.dart';
import '../models/ticket.dart';

class ApiService {
  // Producción Render (https:// + puerto 443, sin :3000).
  // - Producción Render: https://indiehud-backend.onrender.com/api
  // - Móvil físico en LAN: http://192.168.1.78:3000/api
  // - Linux Desktop: http://localhost:3000/api
  // - Emulador Android: http://10.0.2.2:3000/api
  // La URL puede sobrescribirse en pruebas o compilaciones con:
  //   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
  // Esto elimina el valor fijo que obligaba a editar el código fuente.
  static String baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://indiehud-backend.onrender.com/api',
  );

  // Cliente HTTP inyectable: permite pruebas unitarias con MockClient.
  static http.Client httpClient = http.Client();

  // Tiempo máximo de espera para evitar bloqueos indefinidos sin red.
  static Duration timeout = const Duration(seconds: 12);

  // Guardar, leer y borrar Token y datos de sesión
  static Future<void> guardarSesion(String token, String nombre, String correo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    await prefs.setString('usuario_nombre', nombre);
    await prefs.setString('usuario_correo', correo);
  }

  static Future<String?> leerToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<Map<String, String?>> leerUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'nombre': prefs.getString('usuario_nombre'),
      'correo': prefs.getString('usuario_correo'),
    };
  }

  static Future<void> cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // 1. Obtener catálogo (Con soporte para buscador y filtro de categoría)
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

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Juego.fromJson(json)).toList();
    } else {
      throw Exception('No fue posible obtener la información.');
    }
  }

  // 2. Registro de usuario
  static Future<void> registrar(String nombre, String correo, String password) async {
    final response = await httpClient.post(
      Uri.parse('$baseUrl/registro'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'nombre': nombre, 'correo': correo, 'password': password}),
    ).timeout(timeout);

    if (response.statusCode != 201) {
      final data = json.decode(response.body);
      throw Exception(data['error'] ?? 'Error al registrar usuario');
    }
  }

  // 3. Iniciar Sesión
  static Future<Map<String, dynamic>> login(String correo, String password) async {
    final response = await httpClient.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'correo': correo, 'password': password}),
    ).timeout(timeout);

    final data = json.decode(response.body);

    if (response.statusCode == 200) {
      await guardarSesion(
        data['token'],
        data['usuario']['nombre'],
        data['usuario']['correo'],
      );
      return data;
    } else {
      throw Exception(data['error'] ?? 'Correo o contraseña incorrectos');
    }
  }

  // 4. Obtener "Mi Biblioteca" desde la nube
  static Future<List<Juego>> obtenerBiblioteca() async {
    final token = await leerToken();
    if (token == null) throw Exception('No has iniciado sesión');

    final response = await httpClient.get(
      Uri.parse('$baseUrl/biblioteca'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(timeout);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Juego.fromJson(json)).toList();
    } else {
      throw Exception('Error al obtener tu biblioteca');
    }
  }

  // 5. Comprar un juego
  static Future<void> comprarJuego(int juegoId) async {
    final token = await leerToken();
    if (token == null) throw Exception('Inicia sesión en la pestaña Profile para comprar');

    final response = await httpClient.post(
      Uri.parse('$baseUrl/biblioteca/comprar'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({'juego_id': juegoId}),
    ).timeout(timeout);

    if (response.statusCode != 201) {
      final data = json.decode(response.body);
      throw Exception(data['error'] ?? 'No se pudo completar la compra');
    }
  }

  // 6. Crear ticket de soporte (protegido con JWT)
  static Future<Ticket> crearTicket({
    required String asunto,
    required String descripcion,
    required String prioridad,
  }) async {
    final token = await leerToken();
    if (token == null) {
      throw Exception('Inicia sesión en Profile para crear un ticket');
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

    final data = json.decode(response.body);
    if (response.statusCode == 201) {
      return Ticket.fromJson(data['ticket'] ?? data);
    }
    throw Exception(data['error'] ?? 'No se pudo crear el ticket');
  }

  // 7. Obtener mis tickets de soporte (protegido con JWT)
  static Future<List<Ticket>> obtenerTickets() async {
    final token = await leerToken();
    if (token == null) throw Exception('Inicia sesión para ver tus tickets');

    final response = await httpClient.get(
      Uri.parse('$baseUrl/tickets'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(timeout);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Ticket.fromJson(json)).toList();
    }
    throw Exception('No se pudieron obtener tus tickets');
  }
}