import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/juego.dart';
import '../services/api_service.dart';
import '../theme/app_palette.dart';
import '../widgets/responsive_container.dart';

/// Panel exclusivo de la cuenta `desarrollador` en la PWA.
/// Muestra el catálogo real y permite publicar, editar y eliminar juegos.
class DesarrolladorPanelScreen extends StatefulWidget {
  const DesarrolladorPanelScreen({super.key});

  @override
  State<DesarrolladorPanelScreen> createState() =>
      _DesarrolladorPanelScreenState();
}

class _DesarrolladorPanelScreenState extends State<DesarrolladorPanelScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titulo = TextEditingController();
  final _descripcion = TextEditingController();
  final _categoria = TextEditingController();
  final _precio = TextEditingController(text: '9.99');
  final _desarrollador = TextEditingController(text: 'IndieHub Studio');
  final _portadaUrl = TextEditingController();
  final _busquedaCatalogo = TextEditingController();

  Map<String, dynamic> _estadisticas = <String, dynamic>{};
  List<Juego> _juegos = const [];
  Uint8List? _portadaBytes;
  String? _portadaNombre;
  int? _editandoId;
  bool _cargando = true;
  bool _publicando = false;
  String? _error;

  static const _etiquetasEstadisticas = [
    ('Juegos publicados', 'juegos_publicados', 'En el catálogo'),
    ('Ventas', 'ventas', 'Últimos 30 días'),
    ('Visitas', 'visitas', 'Últimos 30 días'),
    ('Ingresos', 'ingresos', 'Últimos 30 días'),
    ('Valoración media', 'valoracion_media', 'De la tienda'),
  ];

  List<Juego> get _juegosFiltrados {
    final texto = _busquedaCatalogo.text.trim().toLowerCase();
    if (texto.isEmpty) return _juegos;
    return _juegos
        .where(
          (juego) =>
              juego.titulo.toLowerCase().contains(texto) ||
              juego.categoria.toLowerCase().contains(texto) ||
              juego.desarrollador.toLowerCase().contains(texto),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _titulo.dispose();
    _descripcion.dispose();
    _categoria.dispose();
    _precio.dispose();
    _desarrollador.dispose();
    _portadaUrl.dispose();
    _busquedaCatalogo.dispose();
    super.dispose();
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
      final stats = await ApiService.obtenerEstadisticasDesarrollador();
      final juegos = await ApiService.obtenerJuegos();
      if (!mounted) return;
      setState(() {
        _estadisticas = stats;
        _juegos = juegos;
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No fue posible obtener la información.';
        _cargando = false;
      });
    }
  }

  Future<void> _elegirPortada() async {
    try {
      final imagen = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (imagen == null || !mounted) return;
      final bytes = await imagen.readAsBytes();
      if (!mounted) return;
      setState(() {
        _portadaBytes = bytes;
        _portadaNombre = imagen.name;
      });
    } catch (_) {
      _snack('No se pudo seleccionar la portada', error: true);
    }
  }

  Future<void> _guardarJuego() async {
    if (_publicando || !_formKey.currentState!.validate()) return;
    if (_editandoId == null &&
        _portadaBytes == null &&
        _portadaUrl.text.trim().isEmpty) {
      _snack('Sube una portada o indica una URL', error: true);
      return;
    }

    final id = _editandoId;
    setState(() => _publicando = true);
    try {
      if (id == null) {
        await ApiService.publicarJuego(
          titulo: _titulo.text,
          descripcion: _descripcion.text,
          categoria: _categoria.text,
          precio: double.tryParse(_precio.text.trim()) ?? 0,
          desarrollador: _desarrollador.text,
          portadaUrl: _portadaUrl.text,
          portadaBytes: _portadaBytes,
        );
      } else {
        await ApiService.actualizarJuego(
          id,
          titulo: _titulo.text,
          descripcion: _descripcion.text,
          categoria: _categoria.text,
          precio: double.tryParse(_precio.text.trim()) ?? 0,
          desarrollador: _desarrollador.text,
          portadaUrl: _portadaUrl.text,
          portadaBytes: _portadaBytes,
        );
      }
      if (!mounted) return;
      _limpiarFormulario();
      _snack(id == null ? 'Juego publicado correctamente' : 'Juego actualizado');
      await _cargar();
    } on SesionExpiradaException catch (e) {
      await ApiService.cerrarSesion();
      _snack(e.toString(), error: true);
    } catch (e) {
      _snack(
        e.toString().replaceAll('Exception: ', ''),
        error: true,
      );
    } finally {
      if (mounted) setState(() => _publicando = false);
    }
  }

  void _limpiarFormulario() {
    if (mounted) setState(() {});
    _titulo.clear();
    _descripcion.clear();
    _categoria.clear();
    _precio.text = '9.99';
    _desarrollador.text = 'IndieHub Studio';
    _portadaUrl.clear();
    _portadaBytes = null;
    _portadaNombre = null;
    _editandoId = null;
  }

  void _iniciarEdicion(Juego juego) {
    setState(() {
      _editandoId = juego.id;
      _titulo.text = juego.titulo;
      _descripcion.text = juego.descripcion;
      _categoria.text = juego.categoria;
      _precio.text = juego.precio.toStringAsFixed(2);
      _desarrollador.text = juego.desarrollador;
      _portadaUrl.text = juego.portadaUrl;
      _portadaBytes = null;
      _portadaNombre = null;
    });
    final contexto = _formKey.currentContext;
    if (contexto != null) {
      Scrollable.ensureVisible(
        contexto,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _eliminar(Juego juego) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppPalette.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppPalette.borde),
        ),
        title: const Text(
          'Eliminar juego',
          style: TextStyle(color: Colors.white, fontSize: 17),
        ),
        content: Text(
          '¿Eliminar “${juego.titulo}” de la tienda? También se quitará de las bibliotecas de los jugadores.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    try {
      await ApiService.eliminarJuego(juego.id);
      if (_editandoId == juego.id) _limpiarFormulario();
      _snack('Juego eliminado de la tienda');
      await _cargar();
    } on SesionExpiradaException catch (e) {
      await ApiService.cerrarSesion();
      _snack(e.toString(), error: true);
    } catch (e) {
      _snack(
        e.toString().replaceAll('Exception: ', ''),
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.fondo,
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 1240,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _encabezado(),
                const SizedBox(height: 20),
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
                  _mensajeError()
                else ...[
                  _tarjetas(),
                  const SizedBox(height: 16),
                  _actividadMensual(),
                  const SizedBox(height: 16),
                  _contenidoAncho(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _encabezado() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PANEL DE DESARROLLADOR',
          style: TextStyle(
            color: AppPalette.secundario,
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Gestiona el catálogo',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Publica juegos y revisa el rendimiento de la tienda.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _mensajeError() {
    return Container(
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
    );
  }

  Widget _tarjetas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        final columnas = ancho >= 1000 ? 5 : ancho >= 640 ? 3 : 2;
        final anchoTarjeta = (ancho - 12 * (columnas - 1)) / columnas;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in _etiquetasEstadisticas)
              SizedBox(
                width: anchoTarjeta,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: _decoracionTarjeta(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$1,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 9,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _valorEstadistica(item.$2),
                        style: const TextStyle(
                          color: AppPalette.acentoPrincipal,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.$3,
                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _valorEstadistica(String clave) {
    final valor = _estadisticas[clave];
    if (valor == null) return '—';
    if (clave == 'ingresos') {
      return '\$${_numero(valor).toStringAsFixed(0)}';
    }
    if (clave == 'valoracion_media') {
      return _numero(valor).toStringAsFixed(1);
    }
    final numero = _numero(valor).round();
    final texto = numero.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return texto;
  }

  double _numero(dynamic valor) {
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor?.toString() ?? '') ?? 0;
  }

  Widget _actividadMensual() {
    final tendencia = _estadisticas['tendencia'];
    final puntos = tendencia is List ? tendencia : const <dynamic>[];
    final maximo = puntos
        .map((p) => _numero(p is Map ? p['juegos'] : null))
        .fold<double>(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _decoracionTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Actividad mensual',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final punto in puntos)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            _numero(punto is Map ? punto['juegos'] : null)
                                .round()
                                .toString(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: maximo == 0
                                ? 4
                                : 70 *
                                    (_numero(
                                            punto is Map ? punto['juegos'] : null) /
                                        maximo),
                            decoration: BoxDecoration(
                              color: AppPalette.secundario,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            punto is Map ? '${punto['mes'] ?? ''}' : '',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contenidoAncho() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        final formulario = _formulario();
        final catalogo = _catalogo();
        if (ancho < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              formulario,
              const SizedBox(height: 16),
              catalogo,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: formulario),
            const SizedBox(width: 16),
            Expanded(flex: 3, child: catalogo),
          ],
        );
      },
    );
  }

  Widget _formulario() {
    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _decoracionTarjeta(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _editandoId == null ? 'Publicar nuevo juego' : 'Editar juego',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_editandoId != null) ...[
              const SizedBox(height: 4),
              Text(
                'ID #$_editandoId · los cambios se guardarán en la tienda',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
            const SizedBox(height: 14),
            _campo('Título', _titulo),
            const SizedBox(height: 10),
            _campo('Descripción', _descripcion, multilinea: true),
            const SizedBox(height: 10),
            _campo('Categoría', _categoria),
            const SizedBox(height: 10),
            _campo('Precio', _precio, teclado: TextInputType.number),
            const SizedBox(height: 10),
            _campo('Desarrollador', _desarrollador),
            const SizedBox(height: 10),
            _campo('URL de portada (opcional)', _portadaUrl),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _elegirPortada,
              icon: const Icon(Icons.image_outlined, size: 16),
              label: Text(
                _portadaNombre ?? 'Seleccionar imagen de portada',
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppPalette.acentoPrincipal,
                side: const BorderSide(color: AppPalette.borde),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _publicando ? null : _guardarJuego,
              icon: _publicando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _editandoId == null ? Icons.upload_file : Icons.save_outlined,
                    ),
              label: Text(
                _publicando
                    ? 'Guardando...'
                    : _editandoId == null
                        ? 'Publicar juego'
                        : 'Guardar cambios',
              ),
              style: _estiloBoton(),
            ),
            if (_editandoId != null)
              TextButton(
                onPressed: _publicando ? null : _limpiarFormulario,
                child: const Text(
                  'Cancelar edición',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _campo(
    String etiqueta,
    TextEditingController control, {
    bool multilinea = false,
    TextInputType teclado = TextInputType.text,
  }) {
    return TextFormField(
      controller: control,
      keyboardType: teclado,
      maxLines: multilinea ? 3 : 1,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: etiqueta,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
        filled: true,
        fillColor: AppPalette.panelOscuro,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppPalette.borde),
        ),
      ),
      validator: (valor) {
        if (multilinea || etiqueta == 'URL de portada (opcional)') return null;
        if (valor == null || valor.trim().isEmpty) return 'Campo obligatorio';
        if (etiqueta == 'Precio' && double.tryParse(valor.trim()) == null) {
          return 'Indica un precio válido';
        }
        return null;
      },
    );
  }

  Widget _catalogo() {
    final visibles = _juegosFiltrados;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _decoracionTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Catálogo de la tienda',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppPalette.acentoPrincipal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_juegos.length} juegos',
                  style: const TextStyle(
                    color: AppPalette.acentoPrincipal,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Actualizar catálogo',
                icon: const Icon(Icons.refresh, color: Colors.white54, size: 18),
                onPressed: _cargar,
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _busquedaCatalogo,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Buscar en el catálogo...',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
              prefixIcon: const Icon(Icons.search, size: 16, color: Colors.white38),
              filled: true,
              fillColor: AppPalette.fondo,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppPalette.borde),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_juegos.isEmpty)
            const Text(
              'Todavía no hay juegos publicados.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            )
          else if (visibles.isEmpty)
            const Text(
              'No hay juegos que coincidan con la búsqueda.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            )
          else
            for (final juego in visibles) ...[
              _filaJuego(juego),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  Widget _filaJuego(Juego juego) {
    final editando = _editandoId == juego.id;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: editando
            ? AppPalette.secundario.withValues(alpha: 0.12)
            : AppPalette.fondo,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: editando ? AppPalette.secundario : AppPalette.borde,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              width: 54,
              height: 32,
              child: Image.network(
                juego.portadaUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppPalette.borde,
                  child: const Icon(Icons.image_not_supported_outlined,
                      color: Colors.white38, size: 16),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  juego.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${juego.categoria} · ${juego.desarrollador}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '\$${juego.precio.toStringAsFixed(2)}',
            style: const TextStyle(
              color: AppPalette.acentoPrincipal,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            tooltip: 'Editar juego',
            icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 17),
            onPressed: () => _iniciarEdicion(juego),
          ),
          IconButton(
            tooltip: 'Eliminar juego',
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 17),
            onPressed: () => _eliminar(juego),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    );
  }
}
