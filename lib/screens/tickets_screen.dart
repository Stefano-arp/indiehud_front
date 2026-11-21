import 'package:flutter/material.dart';
import '../models/ticket.dart';
import '../services/api_service.dart';
import '../database/database_helper.dart';
import '../widgets/support_widget.dart';

/// Tablero de tickets de soporte conectado a Supabase (vía API Node.js),
/// con caché SQLite para lectura offline.
class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  List<Ticket> _tickets = [];
  bool _cargando = true;
  bool _modoOffline = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarTickets();
  }

  void _snack(String msg, {bool error = false}) {
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

  Future<void> _cargarTickets() async {
    if (mounted) setState(() => _cargando = true);
    try {
      final tickets = await ApiService.obtenerTickets();
      await DatabaseHelper.sincronizarTickets(tickets);
      if (mounted) {
        setState(() {
          _tickets = tickets;
          _modoOffline = false;
          _error = null;
          _cargando = false;
        });
      }
    } catch (e) {
      final locales = await DatabaseHelper.obtenerTicketsLocal();
      if (mounted) {
        setState(() {
          _tickets = locales;
          _modoOffline = true;
          _error = e.toString().replaceAll('Exception: ', '');
          _cargando = false;
        });
      }
    }
  }

  Future<void> _abrirFormulario() async {
    final creado = await showModalBottomSheet<Ticket>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _NuevoTicketSheet(),
    );

    if (creado == null) return;
    setState(() {
      _tickets = [creado, ..._tickets];
      _modoOffline = false;
    });
    await DatabaseHelper.sincronizarTickets(_tickets);
    _snack('Ticket #${creado.id} creado. Te responderemos pronto.');
  }

  Color _colorPrioridad(String p) {
    switch (p.toLowerCase()) {
      case 'alta':
        return Colors.redAccent;
      case 'media':
        return Colors.orangeAccent;
      default:
        return const Color(0xFFB2FF05);
    }
  }

  Color _colorEstado(String e) {
    switch (e.toLowerCase()) {
      case 'cerrado':
        return Colors.white54;
      case 'en proceso':
        return const Color(0xFF9D4EDD);
      default:
        return const Color(0xFFB2FF05);
    }
  }

  int get _abiertos => _tickets
      .where((t) => t.estado.toLowerCase() != 'cerrado')
      .length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFB2FF05),
        foregroundColor: Colors.black,
        onPressed: _abrirFormulario,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo ticket',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SOPORTE',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.white54,
                              letterSpacing: 1.5)),
                      Text('Mis tickets',
                          style: TextStyle(
                              fontSize: 26, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    children: [
                      if (_modoOffline)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orangeAccent),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.cloud_off,
                                  size: 14, color: Colors.orangeAccent),
                              SizedBox(width: 4),
                              Text('OFFLINE',
                                  style: TextStyle(
                                      color: Colors.orangeAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white70),
                        onPressed: _cargarTickets,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SupportWidget(
                onAbrirTicket: _abrirFormulario,
                ticketsAbiertos: _abiertos,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _cargando
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Color(0xFFB2FF05)),
                            SizedBox(height: 12),
                            Text('Consultando...'),
                          ],
                        ),
                      )
                    : _tickets.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.confirmation_number_outlined,
                                    size: 60, color: Colors.white24),
                                const SizedBox(height: 12),
                                Text(
                                  _modoOffline
                                      ? 'Sin conexión y sin tickets en caché.\nConéctate para crear uno nuevo.'
                                      : 'Aún no tienes tickets.\nToca "Nuevo ticket" para contactar a soporte.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white54),
                                ),
                                if (_modoOffline && _error != null) ...[
                                  const SizedBox(height: 8),
                                  Text(_error!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: Colors.orangeAccent,
                                          fontSize: 12)),
                                ],
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 90),
                            itemCount: _tickets.length,
                            itemBuilder: (_, i) =>
                                _buildTicketCard(_tickets[i]),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTicketCard(Ticket t) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '#${t.id} · ${t.asunto}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _colorEstado(t.estado).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _colorEstado(t.estado)),
                  ),
                  child: Text(
                    t.estado,
                    style: TextStyle(
                        color: _colorEstado(t.estado),
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              t.descripcion,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.circle,
                    size: 8, color: _colorPrioridad(t.prioridad)),
                const SizedBox(width: 5),
                Text('Prioridad ${t.prioridad}',
                    style: TextStyle(
                        color: _colorPrioridad(t.prioridad), fontSize: 11)),
                const Spacer(),
                Text(t.fechaCorta,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Formulario de creación de ticket (widget de soporte).
class _NuevoTicketSheet extends StatefulWidget {
  const _NuevoTicketSheet();

  @override
  State<_NuevoTicketSheet> createState() => _NuevoTicketSheetState();
}

class _NuevoTicketSheetState extends State<_NuevoTicketSheet> {
  final _asuntoCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _prioridad = 'Media';
  bool _enviando = false;

  @override
  void dispose() {
    _asuntoCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final asunto = _asuntoCtrl.text.trim();
    final descripcion = _descCtrl.text.trim();

    if (asunto.length < 4) {
      _error('El asunto debe tener al menos 4 caracteres');
      return;
    }
    if (descripcion.length < 10) {
      _error('Describe tu problema con al menos 10 caracteres');
      return;
    }

    setState(() => _enviando = true);
    try {
      final ticket = await ApiService.crearTicket(
        asunto: asunto,
        descripcion: descripcion,
        prioridad: _prioridad,
      );
      if (mounted) Navigator.pop(context, ticket);
    } catch (e) {
      if (mounted) {
        setState(() => _enviando = false);
        _error(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  InputDecoration _deco(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.support_agent, color: Color(0xFFB2FF05)),
                SizedBox(width: 8),
                Text('Nuevo ticket de soporte',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _asuntoCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: _deco('Asunto (ej. Error al comprar)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: _deco('Describe tu problema'),
            ),
            const SizedBox(height: 16),
            const Text('Prioridad',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['Baja', 'Media', 'Alta'].map((p) {
                final sel = _prioridad == p;
                return ChoiceChip(
                  label: Text(p),
                  selected: sel,
                  selectedColor: const Color(0xFFB2FF05),
                  backgroundColor: Colors.white10,
                  labelStyle: TextStyle(
                    color: sel ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  onSelected: (_) => setState(() => _prioridad = p),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB2FF05),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _enviando ? null : _enviar,
                icon: _enviando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  _enviando ? 'ENVIANDO...' : 'ENVIAR TICKET',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
