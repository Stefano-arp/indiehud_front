import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_palette.dart';

/// Pantalla para editar nombre, correo y contraseña.
class EditProfileScreen extends StatefulWidget {
  final String nombre;
  final String correo;
  final String fotoUrl;

  const EditProfileScreen({
    super.key,
    required this.nombre,
    required this.correo,
    required this.fotoUrl,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _actualCtrl = TextEditingController();
  final _nuevaCtrl = TextEditingController();

  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl.text = widget.nombre;
    _correoCtrl.text = widget.correo;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _actualCtrl.dispose();
    _nuevaCtrl.dispose();
    super.dispose();
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

  Widget _avatar() {
    return CircleAvatar(
      radius: 52,
      backgroundColor: AppPalette.borde,
      backgroundImage:
          widget.fotoUrl.isNotEmpty ? NetworkImage(widget.fotoUrl) : null,
      child: widget.fotoUrl.isEmpty
          ? Icon(Icons.person, size: 55, color: AppPalette.acentoPrincipal)
          : null,
    );
  }

  InputDecoration _deco(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white10,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Future<void> _guardar() async {
    if (_enviando || !_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);

    try {
      final nombre = _nombreCtrl.text.trim();
      final correo = _correoCtrl.text.trim();
      final actual = _actualCtrl.text.trim();
      final nueva = _nuevaCtrl.text.trim();

      if ((actual.isEmpty) != (nueva.isEmpty)) {
        throw Exception('Completa la contraseña actual y la nueva');
      }
      if (nueva.isNotEmpty && nueva.length < 6) {
        throw Exception('La nueva contraseña debe tener al menos 6 caracteres');
      }

      if (actual.isNotEmpty && nueva.isNotEmpty) {
        await ApiService.cambiarPassword(actual, nueva);
      }

      await ApiService.actualizarPerfil(
        nombre: nombre,
        correo: correo,
      );

      if (await ApiService.biometriaActiva()) {
        final token = await ApiService.leerToken();
        if (token != null) {
          await ApiService.guardarBiometria(token, nombre, correo);
        }
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.fondo,
      appBar: AppBar(
        title: const Text('Editar perfil'),
        backgroundColor: AppPalette.panel,
        foregroundColor: AppPalette.acento,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _avatar(),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _nombreCtrl,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Escribe tu nombre'
                      : null,
                  decoration: _deco('Nombre'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _correoCtrl,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Escribe tu correo';
                    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                    return regex.hasMatch(v.trim()) ? null : 'Correo no válido';
                  },
                  decoration: _deco('Correo electrónico'),
                ),
                const SizedBox(height: 28),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Cambiar contraseña (opcional)',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _actualCtrl,
                  obscureText: true,
                  decoration: _deco('Contraseña actual'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nuevaCtrl,
                  obscureText: true,
                  decoration: _deco('Nueva contraseña'),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB2FF05),
                      foregroundColor: Colors.black,
                    ),
                    onPressed: _enviando ? null : _guardar,
                    child: _enviando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black),
                          )
                        : const Text('GUARDAR CAMBIOS',
                            style: TextStyle(fontWeight: FontWeight.bold)),
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
