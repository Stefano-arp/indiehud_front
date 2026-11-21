import 'package:flutter/material.dart';

/// Widget reutilizable de soporte: tarjeta con acceso rápido
/// al formulario de creación de tickets.
class SupportWidget extends StatelessWidget {
  final VoidCallback onAbrirTicket;
  final int ticketsAbiertos;

  const SupportWidget({
    super.key,
    required this.onAbrirTicket,
    this.ticketsAbiertos = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF2B0B3F), Color(0xFF1A1A1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF9D4EDD).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF9D4EDD),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.support_agent, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¿Necesitas ayuda?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  ticketsAbiertos == 0
                      ? 'Abre un ticket y te responderemos pronto.'
                      : 'Tienes $ticketsAbiertos ticket(s) abierto(s).',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB2FF05),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onPressed: onAbrirTicket,
            child: const Text(
              'TICKET',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
