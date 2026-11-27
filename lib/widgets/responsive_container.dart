import 'package:flutter/material.dart';

/// Centra el contenido y limita su ancho en pantallas grandes.
/// En móvil (< 1000 px) conserva el padding y el ancho originales.
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final double umbral;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry paddingEscritorio;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 1200,
    this.umbral = 1000,
    this.padding = const EdgeInsets.all(16),
    this.paddingEscritorio = const EdgeInsets.symmetric(
      horizontal: 32,
      vertical: 24,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final escritorio = constraints.maxWidth >= umbral;
        final contenido = Padding(
          padding: escritorio ? paddingEscritorio : padding,
          child: child,
        );
        if (!escritorio) return contenido;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: contenido,
          ),
        );
      },
    );
  }
}
