#!/usr/bin/env python3
"""Genera el ícono de macOS a partir de assets/icon.png.

Se corre a mano cuando cambia el logo:

    python3 tool/genera_iconos.py

Por qué un script y no `flutter_launcher_icons`: es una dependencia de
desarrollo entera para una tarea que se hace una vez cada mucho, y que acá
además tiene una vuelta propia — el logo viene a sangre y macOS lo quiere
adentro de su grilla.

La grilla de macOS: el arte ocupa un cuadrado redondeado de 824 puntos
centrado en un lienzo de 1024, con radio 185. Sin ese margen el ícono se ve
más grande que todos sus vecinos en el Dock; sin las esquinas, se ve cuadrado
entre íconos que no lo son.
"""

from pathlib import Path

from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parent.parent
ORIGEN = RAIZ / "assets" / "icon.png"
DESTINO = RAIZ / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"

LIENZO = 1024
ARTE = 824
RADIO = 185
TAMANOS = [16, 32, 64, 128, 256, 512, 1024]


def componer() -> Image.Image:
    """El arte, escalado a la grilla y con las esquinas de macOS."""
    arte = Image.open(ORIGEN).convert("RGBA").resize(
        (ARTE, ARTE), Image.LANCZOS
    )

    mascara = Image.new("L", (ARTE, ARTE), 0)
    ImageDraw.Draw(mascara).rounded_rectangle(
        (0, 0, ARTE - 1, ARTE - 1), radius=RADIO, fill=255
    )
    arte.putalpha(mascara)

    lienzo = Image.new("RGBA", (LIENZO, LIENZO), (0, 0, 0, 0))
    margen = (LIENZO - ARTE) // 2
    lienzo.paste(arte, (margen, margen), arte)
    return lienzo


def main() -> None:
    if not ORIGEN.exists():
        raise SystemExit(f"No encontré {ORIGEN}")

    base = componer()
    for tamano in TAMANOS:
        salida = DESTINO / f"app_icon_{tamano}.png"
        base.resize((tamano, tamano), Image.LANCZOS).save(salida)
        print(f"  {salida.relative_to(RAIZ)}")

    print(f"\n{len(TAMANOS)} íconos escritos. Hace falta rebuild, no restart:")
    print("  flutter clean && flutter run -d macos")


if __name__ == "__main__":
    main()
