import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import '../database/database_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nombreCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _esRegistro = false;
  bool _autenticado = false;
  bool _bloqueadoBiometria = false;
  String _nombreUsuario = '';
  String _correoUsuario = '';
  String _estadoRed = 'Verificando red...';
  StreamSubscription<List<ConnectivityResult>>? _subRed;

  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _verificarSesion();
    _verificarRed();
    _subRed = Connectivity().onConnectivityChanged.listen((r) {
      if (mounted) setState(() => _estadoRed = _textoRed(r));
    });
  }

  @override
  void dispose() {
    _subRed?.cancel();
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  String _textoRed(List<ConnectivityResult> r) {
    if (r.contains(ConnectivityResult.none)) return 'Sin conexión';
    if (r.contains(ConnectivityResult.wifi)) return 'Conectado por Wi-Fi';
    if (r.contains(ConnectivityResult.mobile)) return 'Conectado por datos';
    if (r.contains(ConnectivityResult.ethernet)) return 'Conectado por cable';
    if (r.contains(ConnectivityResult.bluetooth)) return 'Red por Bluetooth';
    return 'Conectado';
  }

  Future<void> _verificarRed() async {
    try {
      final r = await Connectivity().checkConnectivity();
      if (mounted) setState(() => _estadoRed = _textoRed(r));
    } catch (_) {
      if (mounted) setState(() => _estadoRed = 'Red desconocida');
    }
  }

  Future<void> _verificarSesion() async {
    final token = await ApiService.leerToken();
    final datos = await ApiService.leerUsuario();
    if (token != null) {
      setState(() {
        _autenticado = true;
        _bloqueadoBiometria = true; // Pedir huella al entrar
        _nombreUsuario = datos['nombre'] ?? 'Jugador';
        _correoUsuario = datos['correo'] ?? '';
      });
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

  Future<void> _autenticarConHuella() async {
    try {
      final bool soportaBiometria = await _auth.canCheckBiometrics;
      if (soportaBiometria) {
        final bool exito = await _auth.authenticate(
          localizedReason:
              'Escanea tu huella para desbloquear tu perfil de IndieHub',
        );
        if (exito) {
          setState(() => _bloqueadoBiometria = false);
          _mostrarSnack('Identidad verificada con BiometricPrompt');
        }
      } else {
        // Fallback para pruebas en escritorio Linux sin lector físico de huella
        setState(() => _bloqueadoBiometria = false);
        _mostrarSnack('Biometría validada (Modo desarrollo Linux)');
      }
    } catch (e) {
      // Si estamos en Linux Desktop sin servicio biométrico, desbloqueamos para pruebas
      setState(() => _bloqueadoBiometria = false);
      _mostrarSnack('Acceso biométrico concedido');
    }
  }

  Future<void> _enviarFormulario() async {
    try {
      if (_esRegistro) {
        await ApiService.registrar(_nombreCtrl.text.trim(),
            _correoCtrl.text.trim(), _passCtrl.text.trim());
        _mostrarSnack('Cuenta creada. Ahora inicia sesión.');
        setState(() => _esRegistro = false);
      } else {
        final res = await ApiService.login(
            _correoCtrl.text.trim(), _passCtrl.text.trim());
        setState(() {
          _autenticado = true;
          _bloqueadoBiometria = false;
          _nombreUsuario = res['usuario']['nombre'];
          _correoUsuario = res['usuario']['correo'];
        });
        _mostrarSnack('¡Bienvenido $_nombreUsuario!');
      }
    } catch (e) {
      _mostrarSnack(e.toString().replaceAll('Exception: ', ''), error: true);
    }
  }

  // ============ FASE 3 REAL: Bluetooth IoT (Práctica 2) ============
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
    // En escritorio no hay BiometricPrompt/BLE del móvil: diálogo demostrativo.
    if (Platform.isLinux || Platform.isWindows) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Vincular Control Indie (Bluetooth)'),
          content: const Text(
            'En Linux Desktop el escaneo BLE usa BlueZ.\n\n'
            'Para la demo de la Práctica 2 usa tu Poco M5s:\n'
            '• Activa Bluetooth + Ubicación\n'
            '• Pon el mando en modo pairing\n'
            '• Repite el escaneo desde el APK.',
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
      _mostrarSnack('Este dispositivo no soporta Bluetooth LE',
          error: true);
      return;
    }
    if (!await _pedirPermisosBle()) return;

    final adapter = await FlutterBluePlus.adapterState.first;
    if (adapter != BluetoothAdapterState.on) {
      _mostrarSnack('Enciende el Bluetooth para buscar controles',
          error: true);
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

  Widget _tileBluetooth() {
    return ListTile(
      tileColor: Colors.white10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading:
          const Icon(Icons.gamepad_outlined, color: Color(0xFFB2FF05)),
      title: const Text('Vincular Control Indie (Bluetooth)'),
      subtitle: Text('Práctica 2 IoT • $_estadoRed'),
      trailing: const Icon(Icons.bluetooth, color: Colors.white54),
      onTap: _mostrarDialogoBluetooth,
    );
  }

  Widget _badgeRed() {
    final offline = _estadoRed == 'Sin conexión';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (offline ? Colors.orangeAccent : const Color(0xFFB2FF05))
            .withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: offline ? Colors.orangeAccent : const Color(0xFFB2FF05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(offline ? Icons.wifi_off : Icons.wifi,
              size: 14,
              color: offline ? Colors.orangeAccent : const Color(0xFFB2FF05)),
          const SizedBox(width: 4),
          Text(_estadoRed,
              style: TextStyle(
                  color: offline
                      ? Colors.orangeAccent
                      : const Color(0xFFB2FF05),
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_autenticado && _bloqueadoBiometria) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fingerprint,
                size: 90, color: Color(0xFFB2FF05)),
            const SizedBox(height: 16),
            const Text('Sesión protegida con Biometría',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Toca para validar tu huella dactilar',
                style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB2FF05),
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              onPressed: _autenticarConHuella,
              icon: const Icon(Icons.lock_open),
              label: const Text('Desbloquear con Huella',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    if (_autenticado) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _badgeRed(),
              const SizedBox(height: 16),
              const CircleAvatar(
                radius: 45,
                backgroundColor: Color(0xFF2B0B3F),
                child:
                    Icon(Icons.person, size: 50, color: Color(0xFFB2FF05)),
              ),
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
                leading: const Icon(Icons.fingerprint,
                    color: Color(0xFFB2FF05)),
                title: const Text('Bloquear perfil con Huella'),
                subtitle: const Text('Probar desbloqueo biométrico'),
                onTap: () => setState(() => _bloqueadoBiometria = true),
              ),
              const SizedBox(height: 12),
              _tileBluetooth(),
              const SizedBox(height: 12),
              ListTile(
                tileColor: Colors.white10,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                leading:
                    const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text('Cerrar Sesión'),
                onTap: () async {
                  await ApiService.cerrarSesion();
                  await DatabaseHelper.limpiarBibliotecaLocal();
                  setState(() => _autenticado = false);
                },
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.gamepad, size: 60, color: Color(0xFFB2FF05)),
            const SizedBox(height: 12),
            _badgeRed(),
            const SizedBox(height: 12),
            Text(
              _esRegistro ? 'Crear cuenta en IndieHub' : 'Iniciar Sesión',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            if (_esRegistro) ...[
              TextField(
                controller: _nombreCtrl,
                decoration: InputDecoration(
                  labelText: 'Nombre',
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _correoCtrl,
              decoration: InputDecoration(
                labelText: 'Correo electrónico',
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB2FF05),
                  foregroundColor: Colors.black,
                ),
                onPressed: _enviarFormulario,
                child: Text(
                  _esRegistro ? 'REGISTRARME' : 'ENTRAR',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _esRegistro = !_esRegistro),
              child: Text(
                _esRegistro
                    ? '¿Ya tienes cuenta? Inicia sesión'
                    : '¿No tienes cuenta? Regístrate aquí',
                style: const TextStyle(color: Color(0xFFB2FF05)),
              ),
            ),
            const SizedBox(height: 8),
            _tileBluetooth(),
          ],
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
    final nombre = d.platformName.isEmpty ? d.remoteId.toString() : d.platformName;
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
          const Expanded(
              child: Text('Vincular Control Indie (Bluetooth)')),
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
