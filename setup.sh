#!/bin/bash
# MeshMonitor Deployment Setup
# Dieses Skript richtet MeshMonitor auf einem frischen Raspi ein.
# Voraussetzung: Docker, Docker Compose, git

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== MeshMonitor Deployment Setup ==="
echo ""

# 1. Docker Volume erstellen (falls nicht vorhanden)
echo "[1/5] Docker Volume erstellen..."
docker volume create meshmonitor-data 2>/dev/null || true

# 2. Container starten
echo "[2/5] Container starten..."
docker compose up -d

# 3. Warten bis MeshMonitor bereit ist
echo "[3/5] Warte auf MeshMonitor..."
until docker exec meshmonitor test -d /data 2>/dev/null; do
    sleep 2
done
sleep 5

# 4. GeoJSON-Overlays ins Volume kopieren
echo "[4/5] GeoJSON-Overlays kopieren..."
docker exec meshmonitor mkdir -p /data/geojson
for f in overlays/*.geojson; do
    [ -f "$f" ] && docker cp "$f" meshmonitor:/data/geojson/
done
if [ -f overlays/manifest.json ]; then
    docker cp overlays/manifest.json meshmonitor:/data/geojson/
fi

# 5. Custom Styles ins Volume kopieren
echo "[5/5] Custom MapLibre Styles kopieren..."
docker exec meshmonitor mkdir -p /data/map-styles
for f in tiles/styles-meshmonitor/*.json; do
    [ -f "$f" ] && docker cp "$f" meshmonitor:/data/map-styles/
done

echo ""
echo "=== Setup abgeschlossen ==="
echo ""
echo "MeshMonitor: http://localhost:8080"
echo "Tileserver:  http://localhost:8081"
echo ""
echo "Nächste Schritte:"
echo "  1. MeshMonitor öffnen und Custom Tile Server einrichten:"
echo "     Name: Austria"
echo "     URL:  http://localhost:8081/data/v3/{z}/{x}/{y}.pbf"
echo "  2. Custom Style in Settings > Map Styles hochladen"
echo "     (Dateien liegen unter tiles/styles-meshmonitor/)"
echo ""
echo "Hinweis: Die austria.mbtiles muss manuell nach tiles/ kopiert werden."
