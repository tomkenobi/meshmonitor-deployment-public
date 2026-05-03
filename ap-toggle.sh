#!/bin/bash
# ap-toggle.sh — Schaltet den MeshMonitor-AP an/aus
#
# Usage: ./ap-toggle.sh
#
# Wenn der AP aktiv ist:  fährt ihn runter -> NetworkManager faellt auf
#                         autoconnect-Profil zurueck (HasenNetz / Pixel-Hotspot)
# Wenn der AP inaktiv ist: aktiviert ihn -> Pi strahlt SSID 'MeshMonitor' aus
#                         unter 10.42.0.1, SSH ueber LAN bricht ab.
#
# Voraussetzungen:
# - NetworkManager-Profil 'MeshMonitor-AP' existiert (siehe Deployment-Anleitung)
# - sudo-Berechtigung fuer nmcli

set -euo pipefail

PROFILE="MeshMonitor-AP"

if ! nmcli -t -f NAME connection show | grep -qx "$PROFILE"; then
    echo "FEHLER: Profil '$PROFILE' existiert nicht."
    echo "Lege es zuerst an — siehe MeshMonitor-Deployment-Anleitung, Sektion 3 (Modus B)."
    exit 1
fi

if nmcli -t -f NAME connection show --active | grep -qx "$PROFILE"; then
    echo "AP-Mode ist AKTIV  -> wird deaktiviert ..."
    sudo nmcli connection down "$PROFILE"
    echo "OK. NetworkManager faellt auf autoconnect-Profil zurueck (HasenNetz)."
    sleep 2
else
    echo "AP-Mode ist INAKTIV -> wird aktiviert ..."
    echo "ACHTUNG: SSH-Verbindung ueber LAN (192.168.8.x) bricht jetzt ab."
    echo "         Pi strahlt SSID 'MeshMonitor' aus, IP 10.42.0.1"
    sudo nmcli connection up "$PROFILE"
fi

echo
echo "--- Status nach Toggle ---"
nmcli device status | grep -E "DEVICE|wifi"
