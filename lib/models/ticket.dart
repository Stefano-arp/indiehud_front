/// Ticket de soporte (Práctica: tablero de tickets + widget de ayuda).
/// Persistido en Supabase y cacheado en SQLite para lectura offline.
class Ticket {
  final int id;
  final String asunto;
  final String descripcion;
  final String prioridad; // Baja | Media | Alta
  final String estado; // Abierto | En proceso | Cerrado
  final String fechaCreacion;

  Ticket({
    required this.id,
    required this.asunto,
    required this.descripcion,
    required this.prioridad,
    required this.estado,
    required this.fechaCreacion,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      asunto: json['asunto']?.toString() ?? 'Sin asunto',
      descripcion: json['descripcion']?.toString() ?? '',
      prioridad: json['prioridad']?.toString() ?? 'Media',
      estado: json['estado']?.toString() ?? 'Abierto',
      fechaCreacion: json['fecha_creacion']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'asunto': asunto,
      'descripcion': descripcion,
      'prioridad': prioridad,
      'estado': estado,
      'fecha_creacion': fechaCreacion,
    };
  }

  /// Fecha corta legible (dd/mm/aaaa hh:mm) sin dependencias extra.
  String get fechaCorta {
    final dt = DateTime.tryParse(fechaCreacion)?.toLocal();
    if (dt == null) return fechaCreacion;
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(dt.day)}/${dos(dt.month)}/${dt.year} ${dos(dt.hour)}:${dos(dt.minute)}';
  }
}
