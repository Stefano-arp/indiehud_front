import 'package:flutter/material.dart';

import '../models/juego.dart';
import '../theme/app_palette.dart';

/// Secciones tipo escaparate, derivadas del catálogo ya cargado.
///
/// No consulta endpoints nuevos: destacados, novedades y categorías se calculan
/// en cliente para que la Tienda se parezca a un cliente de escritorio sin
/// duplicar peticiones ni dependencias.
class SeccionesTienda extends StatelessWidget {
  final List<Juego> juegos;
  final ValueChanged<Juego> onAbrir;

  const SeccionesTienda({
    super.key,
    required this.juegos,
    required this.onAbrir,
  });

  @override
  Widget build(BuildContext context) {
    if (juegos.isEmpty) return const SizedBox.shrink();

    final destacados = [...juegos]
      ..sort((a, b) => b.precio.compareTo(a.precio));
    final novedades = [...juegos]
      ..sort((a, b) => b.id.compareTo(a.id));

    final porCategoria = <String, List<Juego>>{};
    for (final juego in juegos) {
      final categoria = juego.categoria.trim();
      if (categoria.isEmpty || categoria == 'General') continue;
      porCategoria.putIfAbsent(categoria, () => []).add(juego);
    }
    final categorias = porCategoria.keys.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bloque(
          titulo: 'Destacados para ti',
          juegos: destacados.take(4).toList(),
          onAbrir: onAbrir,
        ),
        const SizedBox(height: 28),
        _bloque(
          titulo: 'Novedades',
          juegos: novedades.take(5).toList(),
          onAbrir: onAbrir,
        ),
        for (final categoria in categorias) ...[
          const SizedBox(height: 28),
          _bloque(
            titulo: 'Explora: $categoria',
            juegos: (porCategoria[categoria] ?? []).take(4).toList(),
            onAbrir: onAbrir,
          ),
        ],
      ],
    );
  }

  Widget _bloque({
    required String titulo,
    required List<Juego> juegos,
    required ValueChanged<Juego> onAbrir,
  }) {
    if (juegos.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 3, height: 18, color: AppPalette.acentoPrincipal),
            const SizedBox(width: 10),
            Text(
              titulo,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final juego in juegos)
              SizedBox(width: 210, child: _tarjeta(juego, onAbrir)),
          ],
        ),
      ],
    );
  }

  Widget _tarjeta(Juego juego, ValueChanged<Juego> onAbrir) {
    return InkWell(
      onTap: () => onAbrir(juego),
      hoverColor: AppPalette.acento.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppPalette.panel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppPalette.borde),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                juego.portadaUrl,
                fit: BoxFit.cover,
                cacheWidth: 420,
                errorBuilder: (_, __, ___) => Container(
                  color: AppPalette.borde,
                  child: Center(
                    child: Icon(Icons.gamepad,
                        color: AppPalette.acentoPrincipal, size: 30),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    juego.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    juego.categoria,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppPalette.secundario,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '\$${juego.precio.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppPalette.acentoPrincipal,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
