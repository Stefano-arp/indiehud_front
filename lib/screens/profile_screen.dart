import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';

import '../database/database_helper.dart';
import '../services/api_service.dart';
import '../services/session_controller.dart';
import '../theme/app_palette.dart';
import '../widgets/responsive_container.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  /// Cuando se abre desde la Tienda sin sesión, vuelve al catálogo al entrar.
  final bool devolverAlEntrar;

  /// Fuerza la guía sin Bluetooth nativo. En producción se decide por
  /// plataforma; el parámetro permite probar el comportamiento web/desktop.
  final bool? sinBluetoothNativo;

  const ProfileScreen({
    super.key,
    this.devolverAlEntrar = false,
    this.sinBluetoothNativo,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nombreCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _esRegistro = false;
  bool _enviando = false;
  bool _autenticado = false;
  bool _bioDisponible = false;
  String _nombreUsuario = '';
  String _correoUsuario = '';
  String _fotoUrl = '';

  // Verificación web -> app.
  bool _esperandoWeb = false;
  bool _verificandoWeb = false;
  String _codigoWeb = '';
  Timer? _timerWeb;
  Timer? _timerSolicitudes;
  final Set<String> _solicitudesVistas = <String>{};
  bool _dialogoSolicitudAbierto = false;

  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _verificarSesion();
    _cargarPreferenciasBiometricas();
    _timerSolicitudes = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _consultarSolicitudesWeb(),
    );
  }

  @override
  void dispose() {
    _timerWeb?.cancel();
    _timerSolicitudes?.cancel();
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarPreferenciasBiometricas() async {
    final activa = await ApiService.biometriaActiva();
    if (mounted) setState(() => _bioDisponible = activa);
  }

  Future<void> _verificarSesion() async {
    final token = await ApiService.leerToken();
    final datos = await ApiService.leerUsuario();
    if (token == null || !mounted) return;

    setState(() {
      _autenticado = true;
      _nombreUsuario = datos['nombre'] ?? 'Jugador';
      _correoUsuario = datos['correo'] ?? '';
      _fotoUrl = datos['foto_url'] ?? '';
    });
    await _recargarPerfil(silent: true);
  }

  Future<void> _recargarPerfil({bool silent = false}) async {
    try {
      final perfil = await ApiService.obtenerPerfil();
      if (!mounted) return;
      setState(() {
        _nombreUsuario = perfil['nombre']?.toString() ?? _nombreUsuario;
        _correoUsuario = perfil['correo']?.toString() ?? _correoUsuario;
        _fotoUrl = perfil['foto_url']?.toString() ?? _fotoUrl;
      });
    } catch (_) {
      if (!silent && mounted) {
        _mostrarSnack('No se pudo actualizar tu perfil', error: true);
      }
    }
  }

  void _mostrarSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: error ? Colors.redAccent : const Color(0xFFB2FF05),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool> _verificarHuellaLocal(String razon) async {
    if (kIsWeb) return false;
    // El escritorio no tiene BiometricPrompt; se mantiene el acceso local.
    if (Platform.isLinux || Platform.isWindows) return true;
    try {
      final puede = await _auth.canCheckBiometrics;
      final dispositivo = await _auth.isDeviceSupported();
      if (!puede && !dispositivo) {
        _mostrarSnack('Este dispositivo no soporta biometría', error: true);
        return false;
      }
      return await _auth.authenticate(
        localizedReason: razon,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (_) {
      _mostrarSnack('No se pudo verificar tu identidad', error: true);
      return false;
    }
  }

  Future<void> _guardarHuella({
    required String token,
    required String nombre,
    required String correo,
  }) async {
    await ApiService.guardarBiometria(token, nombre, correo);
    await ApiService.actualizarBiometriaRemota(true);
    if (mounted) setState(() => _bioDisponible = true);
  }

  Future<void> _entrarConHuella() async {
    if (!_bioDisponible) {
      _mostrarSnack('Primero activa el acceso con huella', error: true);
      return;
    }
    final ok = await _verificarHuellaLocal(
        'Confirma tu huella para entrar a IndieHub');
    if (!ok) return;

    final restored = await ApiService.restaurarSesionBiometrica();
    if (!restored) {
      _mostrarSnack('No hay una sesión biométrica guardada', error: true);
      return;
    }
    final datos = await ApiService.leerUsuario();
    if (!mounted) return;
    setState(() {
      _autenticado = true;
      _nombreUsuario = datos['nombre'] ?? 'Jugador';
      _correoUsuario = datos['correo'] ?? '';
      _fotoUrl = datos['foto_url'] ?? '';
    });
    _mostrarSnack('¡Bienvenido $_nombreUsuario!');
    _volverALaTiendaSiCorresponde();
  }

  Future<void> _preguntarActivarHuella() async {
    if (kIsWeb || !Platform.isAndroid || _bioDisponible) return;
    final aceptar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Acceso con huella'),
        content: const Text(
          '¿Quieres entrar con tu huella la próxima vez sin escribir correo y contraseña?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ahora no', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Activar',
                style: TextStyle(color: Color(0xFFB2FF05))),
          ),
        ],
      ),
    );
    if (aceptar != true) return;
    final ok = await _verificarHuellaLocal('Confirma tu huella para activar el acceso');
    if (!ok) return;
    final token = await ApiService.leerToken();
    if (token == null) return;
    await _guardarHuella(
        token: token, nombre: _nombreUsuario, correo: _correoUsuario);
    _mostrarSnack('Acceso con huella activado');
  }

  void _volverALaTiendaSiCorresponde() {
    Future.microtask(() {
      // Tanto la pestaña como la ruta de acceso vuelven a la Tienda al entrar.
      SessionController.irA(0);
      if (!widget.devolverAlEntrar || !mounted) return;
      final nav = Navigator.of(context);
      if (nav.canPop()) nav.pop();
    });
  }

  void _aplicarSesion(Map<String, dynamic> res) {
    final usuario = res['usuario'] is Map<String, dynamic>
        ? res['usuario'] as Map<String, dynamic>
        : <String, dynamic>{};
    setState(() {
      _autenticado = true;
      _nombreUsuario = usuario['nombre']?.toString() ?? 'Jugador';
      _correoUsuario = usuario['correo']?.toString() ?? '';
      _fotoUrl = usuario['foto_url']?.toString() ?? '';
    });
    _volverALaTiendaSiCorresponde();
  }

  Future<void> _iniciarVerificacionWeb(String correo, String password) async {
    try {
      final res = await ApiService.solicitarBiometriaWeb(correo, password);
      final id = res['solicitud_id']?.toString();
      if (id == null) throw Exception('No se pudo iniciar la verificación');

      _timerWeb?.cancel();
      setState(() {
        _esperandoWeb = true;
        _codigoWeb = res['codigo']?.toString() ?? '';
      });
      _timerWeb = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _verificarEstadoWeb(id),
      );
    } catch (_) {
      // Si el backend aún no tiene la tabla, no bloqueamos el login web.
      final res = await ApiService.login(correo, password);
      _aplicarSesion(res);
      _mostrarSnack('Verificación web no disponible. Usa la app para activarla.',
          error: true);
    }
  }

  Future<void> _verificarEstadoWeb(String id) async {
    if (_verificandoWeb || !mounted) return;
    setState(() => _verificandoWeb = true);
    try {
      final estado = await ApiService.verificarSolicitudWeb(id);
      if (estado == 'aprobada') {
        _timerWeb?.cancel();
        final datos = await ApiService.leerUsuario();
        if (!mounted) return;
        setState(() {
          _esperandoWeb = false;
          _autenticado = true;
              _nombreUsuario = datos['nombre'] ?? 'Jugador';
          _correoUsuario = datos['correo'] ?? '';
          _fotoUrl = datos['foto_url'] ?? '';
        });
        _mostrarSnack('Acceso aprobado desde tu app');
        _volverALaTiendaSiCorresponde();
      } else if (estado == 'rechazada') {
        _timerWeb?.cancel();
        if (mounted) setState(() => _esperandoWeb = false);
        _mostrarSnack('La solicitud fue rechazada o expiró', error: true);
      }
    } catch (_) {
      // Se reintenta en el siguiente tick.
    } finally {
      if (mounted) setState(() => _verificandoWeb = false);
    }
  }

  Future<void> _consultarSolicitudesWeb() async {
    if (!mounted || !_autenticado || kIsWeb || !Platform.isAndroid) return;
    final solicitudes = await ApiService.obtenerSolicitudesWeb();
    for (final solicitud in solicitudes) {
      final id = solicitud['id']?.toString();
      if (id == null || _solicitudesVistas.contains(id)) continue;
      _solicitudesVistas.add(id);
      if (!_dialogoSolicitudAbierto) {
        _dialogoSolicitudAbierto = true;
        _mostrarDialogoSolicitud(id, solicitud['codigo']?.toString() ?? '------');
      }
    }
  }

  Future<void> _mostrarDialogoSolicitud(String id, String codigo) async {
    if (!mounted) return;
    final aprobado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Row(
          children: [
            Icon(Icons.fingerprint, color: Color(0xFFB2FF05)),
            SizedBox(width: 10),
            Expanded(child: Text('Inicio de sesión web')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Alguien quiere iniciar sesión en IndieHub Web.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            const Text('Código de verificación',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 6),
            SelectableText(
              codigo,
              style: const TextStyle(
                fontSize: 28,
                letterSpacing: 8,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB2FF05),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Confirma con tu huella solo si fuiste tú.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context, false);
              try {
                await ApiService.responderSolicitudWeb(id, false);
                _mostrarSnack('Solicitud rechazada');
              } catch (e) {
                _mostrarSnack(e.toString().replaceAll('Exception: ', ''),
                    error: true);
              }
            },
            child: const Text('Rechazar',
                style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aprobar con huella',
                style: TextStyle(color: Color(0xFFB2FF05))),
          ),
        ],
      ),
    );

    _dialogoSolicitudAbierto = false;
    if (aprobado == true) await _aprobarSolicitud(id);
  }

  // La aprobación se maneja aparte para poder pedir huella tras cerrar el diálogo.
  Future<void> _aprobarSolicitud(String id) async {
    final ok = await _verificarHuellaLocal(
        'Confirma tu huella para aprobar el acceso web');
    if (!ok) return;
    try {
      await ApiService.responderSolicitudWeb(id, true);
      _mostrarSnack('Acceso aprobado');
    } catch (e) {
      _mostrarSnack(e.toString().replaceAll('Exception: ', ''), error: true);
    }
  }

  Future<void> _enviarFormulario() async {
    if (_enviando || !_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);
    final correo = _correoCtrl.text.trim();
    final password = _passCtrl.text.trim();

    try {
      if (_esRegistro) {
        await ApiService.registrar(
          _nombreCtrl.text.trim(),
          correo,
          password,
        );
        // Registro con huella: se crea la sesión y se pide la huella en Android.
        if (kIsWeb) {
          setState(() => _esRegistro = false);
          _mostrarSnack('Cuenta creada. Inicia sesión para continuar.');
          return;
        }
        final res = await ApiService.login(correo, password);
        _aplicarSesion(res);
        final token = await ApiService.leerToken();
        if (token != null) {
          final ok = await _verificarHuellaLocal(
              'Confirma tu huella para activar el acceso biométrico');
          if (ok) {
            await _guardarHuella(
                token: token,
                nombre: _nombreUsuario,
                correo: _correoUsuario);
          }
        }
        _mostrarSnack('¡Bienvenido $_nombreUsuario!');
        return;
      }

      if (kIsWeb) {
        // Las cuentas staff entran directo: nunca se les pide huella.
        String rol;
        try {
          rol = await ApiService.consultarRolAcceso(correo, password);
        } catch (_) {
          // Si el endpoint aún no está desplegado, el login devuelve el rol.
          final res = await ApiService.login(correo, password);
          final usuario = res['usuario'] is Map<String, dynamic>
              ? res['usuario'] as Map<String, dynamic>
              : <String, dynamic>{};
          final rolLogin = usuario['rol']?.toString() ?? 'usuario';
          if (rolLogin != 'usuario') {
            _aplicarSesion(res);
            _mostrarSnack('¡Bienvenido $_nombreUsuario!');
            return;
          }
          await ApiService.cerrarSesion();
          await _iniciarVerificacionWeb(correo, password);
          return;
        }
        if (rol != 'usuario') {
          final res = await ApiService.login(correo, password);
          _aplicarSesion(res);
          _mostrarSnack('¡Bienvenido $_nombreUsuario!');
          return;
        }
        await _iniciarVerificacionWeb(correo, password);
        return;
      }

      final res = await ApiService.login(correo, password);
      final datosUsuario = res['usuario'] is Map<String, dynamic>
          ? res['usuario'] as Map<String, dynamic>
          : <String, dynamic>{};
      final rol = datosUsuario['rol']?.toString() ?? 'usuario';
      if (rol != 'usuario') {
        await ApiService.cerrarSesion();
        throw Exception('Esta cuenta solo está disponible en la web');
      }
      _aplicarSesion(res);
      _mostrarSnack('¡Bienvenido $_nombreUsuario!');
      await _preguntarActivarHuella();
    } catch (e) {
      _mostrarSnack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  String? _validarCorreo(String? valor) {
    if (valor == null || valor.trim().isEmpty) return 'Escribe tu correo';
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(valor.trim()) ? null : 'Correo no válido';
  }

  String? _validarPassword(String? valor) {
    if (valor == null || valor.isEmpty) return 'Escribe tu contraseña';
    if (valor.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }

  Future<void> _abrirEdicion() async {
    final actualizado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          nombre: _nombreUsuario,
          correo: _correoUsuario,
          fotoUrl: _fotoUrl,
        ),
      ),
    );
    if (actualizado == true) {
      await _recargarPerfil();
      _mostrarSnack('Perfil actualizado');
    }
  }

  Future<void> _cerrarSesion({bool olvidarHuella = false}) async {
    await ApiService.cerrarSesion();
    if (olvidarHuella) {
      await ApiService.actualizarBiometriaRemota(false);
      await ApiService.olvidarBiometria();
    }
    try {
      await DatabaseHelper.limpiarBibliotecaLocal();
    } catch (_) {
      // La web no siempre dispone de SQLite; no bloquea el cierre de sesión.
    }
    if (!mounted) return;
    setState(() {
      _autenticado = false;
      _bioDisponible = olvidarHuella ? false : _bioDisponible;
      _esRegistro = false;
    });
  }

  // ============ Bluetooth IoT (solo en perfil autenticado) ============
  Future<bool> _pedirPermisosBle() async {
    if (!Platform.isAndroid) return true;
    final estados = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    final scanOk = estados[Permission.bluetoothScan]?.isGranted ?? false;
    final connOk = estados[Permission.bluetoothConnect]?.isGranted ?? false;
    if (!scanOk || !connOk) {
      _mostrarSnack(
          'Activa permisos de Bluetooth y ubicación para escanear',
          error: true);
      return false;
    }
    return true;
  }

  Future<void> _mostrarDialogoBluetooth() async {
    // En web y escritorio se informa cómo usar la función desde el móvil;
    // FlutterBluePlus no tiene canal nativo en esas plataformas.
    if (widget.sinBluetoothNativo ??
        (kIsWeb || Platform.isLinux || Platform.isWindows)) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Vincular Control Indie (Bluetooth)'),
          content: const Text(
            'El escaneo BLE está disponible en la app de Android.\n\n'
            '• Activa Bluetooth y ubicación\n'
            '• Pon el control en modo emparejamiento\n'
            '• Usa “Vincular Control Indie” desde tu móvil',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido',
                  style: TextStyle(color: Color(0xFFB2FF05))),
            ),
          ],
        ),
      );
      return;
    }

    if (!await FlutterBluePlus.isSupported) {
      _mostrarSnack('Este dispositivo no soporta Bluetooth LE', error: true);
      return;
    }
    if (!await _pedirPermisosBle()) return;

    final adapter = await FlutterBluePlus.adapterState.first;
    if (adapter != BluetoothAdapterState.on) {
      _mostrarSnack('Enciende el Bluetooth para buscar controles', error: true);
      try {
        await FlutterBluePlus.turnOn();
      } catch (_) {}
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DialogoBle(
        onVinculado: (nombre) =>
            _mostrarSnack('🎮 $nombre vinculado como Control Indie'),
        onError: (msg) => _mostrarSnack(msg, error: true),
      ),
    );
  }

  InputDecoration _decoAcceso(String etiqueta, IconData icono) {
    final borde = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: AppPalette.borde),
    );
    final enfocado = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppPalette.acentoPrincipal, width: 2),
    );
    return InputDecoration(
      labelText: etiqueta,
      labelStyle: TextStyle(color: AppPalette.textoSuave),
      prefixIcon: Icon(icono, color: AppPalette.acento, size: 20),
      filled: true,
      fillColor: AppPalette.panelOscuro,
      border: borde,
      enabledBorder: borde,
      focusedBorder: enfocado,
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.orangeAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.orangeAccent, width: 2),
      ),
      errorStyle: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
    );
  }

  Widget _tileBluetooth() {
    return ListTile(
      tileColor: Colors.white10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(Icons.gamepad_outlined, color: AppPalette.acento),
      title: const Text('Vincular Control Indie (Bluetooth)'),
      subtitle: const Text('Conecta tu control por Bluetooth'),
      trailing: const Icon(Icons.bluetooth, color: Colors.white54),
      onTap: _mostrarDialogoBluetooth,
    );
  }

  Widget _avatar({double radius = 45}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF2B0B3F),
      backgroundImage:
          _fotoUrl.isNotEmpty ? NetworkImage(_fotoUrl) as ImageProvider : null,
      child: _fotoUrl.isEmpty
          ? Icon(Icons.person, size: radius, color: const Color(0xFFB2FF05))
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_esperandoWeb) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.fingerprint, size: 80, color: Color(0xFFB2FF05)),
              const SizedBox(height: 20),
              const Text('Confirma el acceso desde tu app',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              const Text(
                'Abre IndieHub en tu celular, inicia sesión y aprueba esta solicitud con tu huella.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 24),
              const Text('Código de verificación',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 8),
              SelectableText(
                _codigoWeb,
                style: const TextStyle(
                  fontSize: 30,
                  letterSpacing: 8,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB2FF05),
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(color: Color(0xFFB2FF05)),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  _timerWeb?.cancel();
                  setState(() => _esperandoWeb = false);
                },
                child: const Text('Cancelar',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ),
      );
    }

    if (_autenticado) {
      return SafeArea(
        child: ResponsiveContainer(
          padding: const EdgeInsets.all(24),
          maxWidth: 900,
          child: SingleChildScrollView(
            child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _avatar(),
              const SizedBox(height: 16),
              Text(_nombreUsuario,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              Text(_correoUsuario,
                  style: const TextStyle(color: Colors.white54)),
              const SizedBox(height: 24),
              ListTile(
                tileColor: Colors.white10,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                leading:
                    const Icon(Icons.edit, color: Color(0xFFB2FF05)),
                title: const Text('Editar perfil'),
                subtitle: const Text('Nombre, correo y contraseña'),
                onTap: _abrirEdicion,
              ),
              if (!kIsWeb && !_bioDisponible) ...[
                const SizedBox(height: 12),
                ListTile(
                  tileColor: Colors.white10,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  leading: const Icon(Icons.lock_open,
                      color: Color(0xFFB2FF05)),
                  title: const Text('Activar acceso con huella'),
                  subtitle: const Text('Entra sin escribir tu contraseña'),
                  onTap: _preguntarActivarHuella,
                ),
              ],
              const SizedBox(height: 12),
              _tileBluetooth(),
              const SizedBox(height: 12),
              ListTile(
                tileColor: Colors.white10,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text('Cerrar Sesión'),
                onTap: () => _cerrarSesion(),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _cerrarSesion(olvidarHuella: true),
                child: const Text('Cerrar sesión y olvidar huella',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ),
      ),
    );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppPalette.panel,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppPalette.borde),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppPalette.acentoPrincipal.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppPalette.acentoPrincipal.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Icon(Icons.sports_esports,
                      color: AppPalette.acentoPrincipal, size: 30),
                ),
                const SizedBox(height: 18),
                Text(
                  _esRegistro ? 'Crear cuenta' : 'Iniciar sesión',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      decoration: TextDecoration.none,
                      decorationColor: Colors.transparent),
                ),
                const SizedBox(height: 6),
                Text(
                  _esRegistro
                      ? 'Únete a IndieHub y guarda tus juegos favoritos.'
                      : 'Bienvenido de nuevo a IndieHub.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppPalette.textoSuave, fontSize: 13),
                ),
                const SizedBox(height: 24),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_esRegistro) ...[
                        TextFormField(
                          controller: _nombreCtrl,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Escribe tu nombre'
                              : null,
                          decoration: _decoAcceso('Nombre', Icons.person_outline),
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextFormField(
                        controller: _correoCtrl,
                        keyboardType: TextInputType.emailAddress,
                        validator: _validarCorreo,
                        decoration:
                            _decoAcceso('Correo electrónico', Icons.alternate_email),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: true,
                        validator: _validarPassword,
                        decoration: _decoAcceso('Contraseña', Icons.lock_outline),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppPalette.acentoPrincipal,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _enviando ? null : _enviarFormulario,
                          child: _enviando
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.black),
                                )
                              : Text(
                                  _esRegistro ? 'Crear cuenta' : 'Entrar',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_bioDisponible && !kIsWeb) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppPalette.acentoPrincipal,
                        side: BorderSide(
                            color: AppPalette.acentoPrincipal
                                .withValues(alpha: 0.6)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _entrarConHuella,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Entrar con huella',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
                if (kIsWeb && !_esRegistro) ...[
                  const SizedBox(height: 12),
                  Text(
                    'La verificación se aprueba desde la app en tu celular.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppPalette.textoSuave, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _esRegistro = !_esRegistro),
                  child: Text(
                    _esRegistro
                        ? '¿Ya tienes cuenta? Inicia sesión'
                        : '¿No tienes cuenta? Crear cuenta',
                    style: TextStyle(
                        color: AppPalette.acentoPrincipal,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Diálogo real de escaneo BLE con flutter_blue_plus (Android físico).
class _DialogoBle extends StatefulWidget {
  final void Function(String nombre) onVinculado;
  final void Function(String msg) onError;
  const _DialogoBle({required this.onVinculado, required this.onError});

  @override
  State<_DialogoBle> createState() => _DialogoBleState();
}

class _DialogoBleState extends State<_DialogoBle> {
  List<ScanResult> _resultados = [];
  bool _escaneando = true;
  StreamSubscription<List<ScanResult>>? _sub;
  StreamSubscription<bool>? _subScan;

  @override
  void initState() {
    super.initState();
    _sub = FlutterBluePlus.scanResults.listen((r) {
      if (mounted) setState(() => _resultados = List.of(r));
    });
    _subScan = FlutterBluePlus.isScanning.listen((s) {
      if (mounted) setState(() => _escaneando = s);
    });
    _iniciar();
  }

  Future<void> _iniciar() async {
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    } catch (e) {
      widget.onError('No se pudo escanear: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _subScan?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _vincular(BluetoothDevice d) async {
    final nombre =
        d.platformName.isEmpty ? d.remoteId.toString() : d.platformName;
    try {
      await FlutterBluePlus.stopScan();
      await d.connect(timeout: const Duration(seconds: 8));
      if (mounted) Navigator.pop(context);
      widget.onVinculado(nombre);
    } catch (e) {
      widget.onError('No se pudo vincular $nombre: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Row(
        children: [
          const Expanded(child: Text('Vincular Control Indie (Bluetooth)')),
          if (_escaneando)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFFB2FF05)),
            ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: _resultados.isEmpty
            ? Center(
                child: Text(
                  _escaneando
                      ? 'Buscando mandos y accesorios BLE...\nPon tu control en modo pairing.'
                      : 'No se encontraron dispositivos.\nReintenta el escaneo.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              )
            : ListView.builder(
                itemCount: _resultados.length,
                itemBuilder: (_, i) {
                  final r = _resultados[i];
                  final d = r.device;
                  final nombre = d.platformName.isEmpty
                      ? 'Dispositivo ${d.remoteId}'
                      : d.platformName;
                  return ListTile(
                    leading: const Icon(Icons.gamepad_outlined,
                        color: Color(0xFFB2FF05)),
                    title: Text(nombre,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${d.remoteId} • RSSI ${r.rssi} dBm',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11)),
                    trailing: TextButton(
                      onPressed: () => _vincular(d),
                      child: const Text('VINCULAR',
                          style: TextStyle(
                              color: Color(0xFFB2FF05),
                              fontWeight: FontWeight.bold)),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await FlutterBluePlus.stopScan();
            await _iniciar();
          },
          child: const Text('Reintentar',
              style: TextStyle(color: Colors.white70)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar',
              style: TextStyle(color: Color(0xFFB2FF05))),
        ),
      ],
    );
  }
}
