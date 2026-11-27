#!/usr/bin/env bash
set -euo pipefail

# Flutter 3.50 genera un service worker que solo se desregistra.
# Compilamos y luego reemplazamos ese archivo por el service worker con caché real.
flutter build web --release
cp web/pwa_service_worker.js build/web/flutter_service_worker.js
echo "PWA lista en build/web (service worker con cache offline)."
