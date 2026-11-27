import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_palette.dart';
import '../widgets/responsive_container.dart';

const _estadosTicket = ['Abierto', 'En proceso', 'Cerrado'];

/// Panel exclusivo de la cuenta `soporte` en la PWA.
/// Lista todos los tickets de la tienda y permite responderlos y cerrarlos.
class SoportePanelScreen extends StatefulWidget {
  const SoportePanelScreen({super.key});

  @override
  State<SoportePanelScreen> createState() => _SoportePanelScreenState();
}

class _SoportePanelScreenState extends State<SoportePanelScreen> {
  static const _filtros = ['Todos', 'Abierto', 'En proceso', 'Cerrado'];

  List<Map<String, dynamic>> _tickets = const [];
  String _filtro = 'Todos';
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _snack(String mensaje, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensaje,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: error ? Colors.redAccent : AppPalette.acentoPrincipal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _cargar() async {
    if (mounted) setState(() => _cargando = true);
    try {
      final tickets = await ApiService.obtenerTicketsSoporte();
      if (!mounted) return;
      setState(() {
        _tickets = tickets;
        _error = null;
        _cargando = false;
      });
    } on SesionExpiradaException catch (e) {
      await ApiService.cerrarSesion();
      if (mounted) {
        setState(() {
          _error = e.toString();
          _cargando = false;
        });
        _snack(e.toString(), error: true);
      }
    } catch (e) {
      if (!mounted) return;
      final mensaje = e.toString().replaceAll('Exception: ', '');
      final esRed = mensaje.contains('ClientException') ||
          mensaje.contains('SocketException') ||
          mensaje.contains('TimeoutException');
      setState(() {
        _error = esRed ? 'No fue posible obtener la información.' : mensaje;
        _cargando = false;
      });
    }
  }

  int get _abiertos => _tickets
      .where((t) => _texto(t['estado']).toLowerCase() != 'cerrado')
      .length;

  List<Map<String, dynamic>> get _visibles => _filtro == 'Todos'
      ? _tickets
      : _tickets
          .where((t) => _texto(t['estado']) == _filtro)
          .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.fondo,
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: AppPalette.acentoPrincipal,
        foregroundColor: Colors.black,
        tooltip: 'Actualizar tickets',
        onPressed: _cargar,
        child: const Icon(Icons.refresh),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 1240,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'CENTRO DE SOPORTE',
                  style: TextStyle(
                    color: AppPalette.secundario,
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Atender tickets',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppPalette.acentoPrincipal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_abiertos abiertos',
                        style: const TextStyle(
                          color: AppPalette.acentoPrincipal,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Revisa las solicitudes y responde a los jugadores.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 18),
                _filtrosFila(),
                const SizedBox(height: 14),
                if (_cargando)
                  const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppPalette.acentoPrincipal,
                      ),
                    ),
                  )
                else if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: _decoracionTarjeta(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_error!, style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _cargar,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                          style: _estiloBoton(),
                        ),
                      ],
                    ),
                  )
                else if (_visibles.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(40),
                    decoration: _decoracionTarjeta(),
                    child: const Center(
                      child: Text(
                        'No hay tickets en este estado.',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ),
                  )
                else
                  for (final ticket in _visibles) ...[
                    _tarjetaTicket(ticket),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filtrosFila() {
    return Wrap(
      spacing: 8,
      children: [
        for (final filtro in _filtros)
          ChoiceChip(
            label: Text(
              filtro,
              style: TextStyle(
                color: _filtro == filtro ? Colors.black : Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            selected: _filtro == filtro,
            selectedColor: AppPalette.acentoPrincipal,
            backgroundColor: AppPalette.panelOscuro,
            side: const BorderSide(color: AppPalette.borde),
            onSelected: (_) => setState(() => _filtro = filtro),
          ),
      ],
    );
  }

  Widget _tarjetaTicket(Map<String, dynamic> ticket) {
    final estado = _texto(ticket['estado']);
    final prioridad = _texto(ticket['prioridad']);
    final usuario = _usuario(ticket);
    final fecha = _fecha(ticket['fecha_creacion']);
    final respondido = _texto(ticket['respuesta']).isNotEmpty;

    return InkWell(
      onTap: () => _abrirTicket(ticket),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _decoracionTarjeta(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '#${_texto(ticket['id'])}  ${_texto(ticket['asunto'])}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _etiqueta(estado, _colorEstado(estado)),
                const SizedBox(width: 6),
                _etiqueta(prioridad, _colorPrioridad(prioridad)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _texto(ticket['descripcion']),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            if (respondido) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppPalette.acentoPrincipal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Respuesta: ${_texto(ticket['respuesta'])}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.person_outline,
                    size: 13, color: AppPalette.secundario),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    usuario,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ),
                if (fecha.isNotEmpty)
                  Text(
                    fecha,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                if (respondido) ...[
                  const SizedBox(width: 10),
                  const Icon(Icons.reply, size: 13, color: Colors.white54),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirTicket(Map<String, dynamic> ticket) async {
    final respondido = await showDialog<bool>(
      context: context,
      builder: (_) => _ResponderTicket(
        ticket: ticket,
        onGuardar: _guardar,
      ),
    );
    if (respondido == true) await _cargar();
  }

  Future<bool> _guardar(
    int id, {
    required String estado,
    required String respuesta,
  }) async {
    try {
      await ApiService.actualizarTicketSoporte(
        id,
        estado: estado,
        respuesta: respuesta,
      );
      _snack('Ticket actualizado');
      return true;
    } on SesionExpiradaException catch (e) {
      await ApiService.cerrarSesion();
      _snack(e.toString(), error: true);
    } catch (e) {
      _snack(
        e.toString().replaceAll('Exception: ', ''),
        error: true,
      );
    }
    return false;
  }

  String _texto(dynamic valor) => valor?.toString() ?? '';

  String _usuario(Map<String, dynamic> ticket) {
    final usuario = ticket['usuarios'];
    if (usuario is Map<String, dynamic>) {
      final nombre = _texto(usuario['nombre']);
      final correo = _texto(usuario['correo']);
      return nombre.isNotEmpty ? '$nombre · $correo' : correo;
    }
    if (usuario is List && usuario.isNotEmpty && usuario.first is Map) {
      final mapa = Map<String, dynamic>.from(usuario.first as Map);
      return _texto(mapa['nombre']);
    }
    return 'Jugador';
  }

  String _fecha(dynamic valor) {
    final texto = _texto(valor);
    if (texto.isEmpty) return '';
    final fecha = DateTime.tryParse(texto);
    if (fecha == null) return texto.length > 10 ? texto.substring(0, 10) : texto;
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }

  Color _colorEstado(String estado) {
    return switch (estado.toLowerCase()) {
      'cerrado' => Colors.white54,
      'en proceso' => AppPalette.secundario,
      _ => AppPalette.acentoPrincipal,
    };
  }

  Color _colorPrioridad(String prioridad) {
    return switch (prioridad.toLowerCase()) {
      'alta' => Colors.redAccent,
      'media' => Colors.orangeAccent,
      _ => AppPalette.secundario,
    };
  }

  Widget _etiqueta(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texto,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  BoxDecoration _decoracionTarjeta() {
    return BoxDecoration(
      color: AppPalette.panelOscuro,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppPalette.borde),
    );
  }

  ButtonStyle _estiloBoton() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppPalette.acentoPrincipal,
      foregroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    );
  }
}

class _ResponderTicket extends StatefulWidget {
  final Map<String, dynamic> ticket;
  final Future<bool> Function(
    int id, {
    required String estado,
    required String respuesta,
  }) onGuardar;

  const _ResponderTicket({required this.ticket, required this.onGuardar});

  @override
  State<_ResponderTicket> createState() => _ResponderTicketState();
}

class _ResponderTicketState extends State<_ResponderTicket> {
  late String _estado;
  late TextEditingController _respuesta;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final actual = widget.ticket['estado']?.toString() ?? 'Abierto';
    _estado = _estadosTicket.contains(actual) ? actual : 'Abierto';
    _respuesta = TextEditingController(
      text: widget.ticket['respuesta']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _respuesta.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    final respuesta = _respuesta.text.trim();
    var estado = _estado;
    if (respuesta.isNotEmpty && estado == 'Abierto') estado = 'En proceso';
    if (estado == 'Cerrado' && respuesta.isEmpty) {
      setState(() {
        _error = 'Escribe una respuesta antes de cerrar el ticket.';
      });
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
      _estado = estado;
    });
    final id = int.tryParse(widget.ticket['id']?.toString() ?? '') ?? 0;
    final guardado = await widget.onGuardar(
      id,
      estado: estado,
      respuesta: respuesta,
    );
    if (mounted) {
      setState(() => _guardando = false);
      if (guardado) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    return Dialog(
      backgroundColor: AppPalette.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppPalette.borde),
      ),
      child: Container(
        width: ancho < 600 ? double.maxFinite : 520,
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ticket #${widget.ticket['id'] ?? ''}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.ticket['asunto']?.toString() ?? '',
                style: const TextStyle(
                  color: AppPalette.acentoPrincipal,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                widget.ticket['descripcion']?.toString() ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
              const SizedBox(height: 18),
              const Text(
                'Estado',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _estado,
                decoration: _decoracionCampo(),
                dropdownColor: AppPalette.panel,
                items: [
                  for (final estado in _estadosTicket)
                    DropdownMenuItem(
                      value: estado,
                      child: Text(
                        estado,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                ],
                onChanged: (valor) {
                  if (valor != null) setState(() => _estado = valor);
                },
              ),
              const SizedBox(height: 14),
              const Text(
                'Respuesta',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _respuesta,
                maxLines: 4,
                onChanged: (valor) {
                  if (valor.trim().isNotEmpty && _estado == 'Abierto') {
                    setState(() => _estado = 'En proceso');
                  }
                },
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _decoracionCampo(hint: 'Escribe la respuesta...'),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _guardando ? null : _guardar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.acentoPrincipal,
                      foregroundColor: Colors.black,
                    ),
                    child: Text(_guardando ? 'Guardando...' : 'Guardar respuesta'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoracionCampo({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
      filled: true,
      fillColor: AppPalette.panelOscuro,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppPalette.borde),
      ),
    );
  }
}
