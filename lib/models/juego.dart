class Juego {
  final int id;
  final String titulo;
  final String descripcion;
  final double precio;
  final String desarrollador;
  final String portadaUrl;
  final String categoria;
  final bool esFavorito;

  Juego({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.precio,
    required this.desarrollador,
    required this.portadaUrl,
    required this.categoria,
    this.esFavorito = false,
  });

  // Convierte el JSON de tu API Node.js a un objeto Juego en Flutter
  factory Juego.fromJson(Map<String, dynamic> json) {
    bool fav = false;
    final rawFav = json['es_favorito'];
    if (rawFav is int) {
      fav = rawFav == 1;
    } else if (rawFav is bool) {
      fav = rawFav;
    } else if (rawFav is String) {
      fav = rawFav == '1' || rawFav.toLowerCase() == 'true';
    }
    return Juego(
      id: (json['id'] is int)
          ? json['id'] as int
          : int.tryParse(json['id'].toString()) ?? 0,
      titulo: json['titulo']?.toString() ?? 'Sin título',
      descripcion: json['descripcion']?.toString() ?? '',
      precio: double.tryParse(json['precio'].toString()) ?? 0.0,
      desarrollador: json['desarrollador']?.toString() ?? 'Indie Dev',
      portadaUrl: json['portada_url']?.toString() ??
          'https://images.unsplash.com/photo-1605806616949-1e87b487cb2a?q=80&w=600&auto=format&fit=crop',
      categoria: json['categoria']?.toString() ?? 'General',
      esFavorito: fav,
    );
  }

  // Convierte el objeto a un Mapa para guardarlo en SQLite (Modo Offline)
  // es_favorito se guarda como INTEGER 0/1 (Práctica 4).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titulo': titulo,
      'descripcion': descripcion,
      'precio': precio,
      'desarrollador': desarrollador,
      'portada_url': portadaUrl,
      'categoria': categoria,
      'es_favorito': esFavorito ? 1 : 0,
    };
  }

  Juego copyWith({bool? esFavorito}) {
    return Juego(
      id: id,
      titulo: titulo,
      descripcion: descripcion,
      precio: precio,
      desarrollador: desarrollador,
      portadaUrl: portadaUrl,
      categoria: categoria,
      esFavorito: esFavorito ?? this.esFavorito,
    );
  }
}
