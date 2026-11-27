#!/usr/bin/env python3
"""Genera los iconos IndieHub (gamepad neón) sin dependencias de Flutter.

Requiere Pillow (ya instalada en el entorno de desarrollo). Los PNG se
sobrescriben en sus destinos nativos: Android, web/PWA e iOS.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]

FONDO = (18, 18, 18, 255)  # #121212
PANEL = (30, 30, 30, 255)  # #1E1E1E
VERDE = (178, 255, 5, 255)  # #B2FF05
MORADO = (157, 78, 221, 255)  # #9D4EDD


def _icono(size: int, *, maskable: bool = False) -> Image.Image:
    """Dibuja el icono a 4x y lo reduce con antialias."""
    escala = 4
    ancho = size * escala
    imagen = Image.new("RGBA", (ancho, ancho), FONDO)
    dibujo = ImageDraw.Draw(imagen)

    margen = int(ancho * 0.035)
    dibujo.rounded_rectangle(
        [margen, margen, ancho - margen, ancho - margen],
        radius=int(ancho * 0.20),
        fill=PANEL,
    )

    # Resplandor morado suave detrás del gamepad.
    brillo = Image.new("RGBA", (ancho, ancho), (0, 0, 0, 0))
    ImageDraw.Draw(brillo).ellipse(
        [ancho * 0.15, ancho * 0.24, ancho * 0.85, ancho * 0.78],
        fill=(MORADO[0], MORADO[1], MORADO[2], 64),
    )
    imagen = Image.alpha_composite(
        imagen, brillo.filter(ImageFilter.GaussianBlur(ancho * 0.055))
    )
    dibujo = ImageDraw.Draw(imagen)

    factor = 0.78 if maskable else 0.92
    cx = cy = ancho / 2

    def punto(x: float, y: float) -> tuple[float, float]:
        return cx + x * ancho * factor, cy + y * ancho * factor

    def caja(x1: float, y1: float, x2: float, y2: float):
        return (*punto(x1, y1), *punto(x2, y2))

    # Agarraderas y cuerpo del gamepad.
    dibujo.polygon(
        [
            punto(-0.30, 0.00),
            punto(-0.17, 0.00),
            punto(-0.09, 0.27),
            punto(-0.23, 0.29),
        ],
        fill=VERDE,
    )
    dibujo.polygon(
        [
            punto(0.17, 0.00),
            punto(0.30, 0.00),
            punto(0.23, 0.29),
            punto(0.09, 0.27),
        ],
        fill=VERDE,
    )
    dibujo.rounded_rectangle(
        caja(-0.33, -0.16, 0.33, 0.10),
        radius=int(ancho * factor * 0.12),
        fill=VERDE,
    )

    # Cruceta.
    redondez = int(ancho * factor * 0.02)
    dibujo.rounded_rectangle(
        caja(-0.24, -0.055, -0.10, 0.005), radius=redondez, fill=FONDO
    )
    dibujo.rounded_rectangle(
        caja(-0.19, -0.105, -0.15, 0.055), radius=redondez, fill=FONDO
    )

    # Botones de acción (uno morado para el acento secundario).
    radio = ancho * factor * 0.033
    x1, y1 = punto(0.16, -0.055)
    x2, y2 = punto(0.24, 0.025)
    dibujo.ellipse(
        [x1 - radio, y1 - radio, x1 + radio, y1 + radio], fill=MORADO
    )
    dibujo.ellipse(
        [x2 - radio, y2 - radio, x2 + radio, y2 + radio],
        fill=FONDO,
        outline=VERDE,
        width=max(1, int(ancho * factor * 0.008)),
    )

    return imagen.convert("RGB").resize((size, size), Image.Resampling.LANCZOS)


def guardar(ruta: Path, imagen: Image.Image) -> None:
    ruta.parent.mkdir(parents=True, exist_ok=True)
    imagen.save(ruta, format="PNG", optimize=True)
    print(f"{ruta.relative_to(ROOT)}: {imagen.width}x{imagen.height}")


def main() -> None:
    android = ROOT / "android/app/src/main/res"
    for densidad, tamano in {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }.items():
        guardar(android / f"mipmap-{densidad}/ic_launcher.png", _icono(tamano))

    web = ROOT / "web"
    guardar(web / "favicon.png", _icono(32))
    guardar(web / "icons/Icon-192.png", _icono(192))
    guardar(web / "icons/Icon-512.png", _icono(512))
    guardar(web / "icons/Icon-maskable-192.png", _icono(192, maskable=True))
    guardar(web / "icons/Icon-maskable-512.png", _icono(512, maskable=True))

    ios = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contenido = json.loads((ios / "Contents.json").read_text(encoding="utf-8"))
    for entrada in contenido["images"]:
        nombre = entrada.get("filename")
        if not nombre:
            continue
        base = float(entrada["size"].split("x")[0])
        escala = float(entrada["scale"].rstrip("x"))
        guardar(ios / nombre, _icono(round(base * escala)))


if __name__ == "__main__":
    main()
