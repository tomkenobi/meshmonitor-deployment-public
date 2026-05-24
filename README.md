# MeshMonitor — Offline-Deployment auf Raspberry Pi

Deployment-Konfiguration für [MeshMonitor](https://github.com/yeraze/meshmonitor) (v4.1.2) mit lokalem Vector-Tileserver, Caddy-Reverse-Proxy und mDNS-Hostname-Routing. Zielplattform: Raspberry Pi 4/5 mit Docker. Funktioniert vollständig offline (kein Internet, kein bestehendes Netzwerk nötig).

## Architektur

```
[Meshtastic-Node] --USB--> [serial-bridge :4403] ---+
                                                    |
                          [meshmonitor :3001] <-----+   (intern)
                                  ^
                                  | (intern)
   Browser --http://meshmonitor.local--> [Caddy :80]
                                                  \
                                                   +--> /tiles/*  ->  [tileserver :8080]  (intern)
```

Eine einzige öffentliche URL (`http://meshmonitor.local/`), Caddy macht Path-Routing. `meshmonitor` und `tileserver` haben keine externen Ports — der gesamte Verkehr läuft durch Caddy.

**Warum mDNS-Hostname statt fester IP:** Identisches Image lässt sich auf jedem Pi deployen, MapLibre-Style braucht keine pro-Pi-Anpassung. Tile-, Sprite- und Glyph-URLs zeigen alle auf denselben Hostnamen — vermeidet das CSP-Problem (siehe unten).

## Voraussetzungen

- Raspberry Pi 4 (4 GB) oder Pi 5
- Docker + Docker Compose
- Meshtastic-Node per USB
- `austria.mbtiles` (separat, **nicht im Repo** — zu groß)

## Schnellstart

```bash
git clone <repo> ~/meshmonitor
cd ~/meshmonitor

# MBTiles separat reinkopieren
cp /pfad/zu/austria.mbtiles tiles/

# udev-Regel (siehe unten) installieren, dann:
docker compose up -d

# Browser: http://meshmonitor.local/
```

## Container-Stack (`docker-compose.yml`)

| Container | Image | Funktion | Externer Port |
|---|---|---|---|
| `meshmonitor-caddy` | `caddy:2-alpine` | Reverse-Proxy | **80** |
| `meshmonitor` | `ghcr.io/yeraze/meshmonitor:latest` | Web-UI + Backend | — (intern) |
| `meshmonitor-tileserver` | `maptiler/tileserver-gl-light:latest` | Vector-Tile-Server | — (intern) |
| `meshtastic-serial-bridge` | `ghcr.io/yeraze/meshtastic-serial-bridge:latest` | USB→TCP für Node | 4403 |

## Caddy-Konfiguration (`Caddyfile`)

```caddy
:80 {
    encode gzip

    # Tileserver unter /tiles/* — Prefix wegstrippen
    handle_path /tiles/* {
        reverse_proxy meshmonitor-tileserver:8080
    }

    # Alles andere → MeshMonitor
    handle {
        reverse_proxy meshmonitor:3001
    }
}
```

`handle_path` strippt das `/tiles/`-Prefix vor Weiterleitung an den Tileserver.

## MeshMonitor einrichten

Nach `docker compose up -d` Browser auf `http://meshmonitor.local/` öffnen, einloggen (Default-Credentials siehe MeshMonitor-Doku — sofort ändern).

### Source (Multi-Source-Architektur)

**Settings → Sources → Add:**

| Feld | Wert |
|---|---|
| Type | `TCP` |
| Host | `meshtastic-serial-bridge` |
| Port | `4403` |

### Custom Tile Server

**Settings → Map → Custom Tile Servers → Add:**

| Feld | Wert |
|---|---|
| Name | Austria |
| Tile URL | `http://meshmonitor.local/tiles/data/v3/{z}/{x}/{y}.pbf` |
| Max Zoom | `14` |

### MapLibre-Style

**Settings → Map Styles → Upload Style** — die vier vorbereiteten Files in `tiles/styles-meshmonitor/` (`bright.json`, `dark-matter.json`, `fiord.json`, `positron.json`) hochladen. Alle URLs in den Files zeigen bereits auf `http://meshmonitor.local/tiles/...`.

> [!important] CSP-Falle bei Style-URL-Mismatch
>
> MeshMonitor whitelistet im CSP-Header **nur** den Hostnamen, der unter „Custom Tile Server" eingetragen ist. Wenn die Style-Datei zusätzliche URLs auf einem **anderen** Hostnamen verwendet (z.B. Sprite oder Glyphs auf Container-internem `meshmonitor-tileserver:8080`), blockt der Browser diese Requests **ohne UI-Rückmeldung** → Karte bleibt grau.
>
> Lösung: Tile-, Sprite- und Glyph-URLs müssen **denselben Hostnamen** verwenden. Die mitgelieferten Style-Dateien sind entsprechend vorbereitet.

## USB-Geräteerkennung (udev)

Damit die Node unabhängig von der USB-Reihenfolge gefunden wird:

`/etc/udev/rules.d/99-meshtastic.rules`:

```
# ESP32-S3 (Heltec MeshPocket, LilyGO T-Deck Plus)
SUBSYSTEM=="tty", ATTRS{idVendor}=="303a", ATTRS{idProduct}=="1001", SYMLINK+="meshtastic"
# nRF52840, SenseCAP T1000-E
SUBSYSTEM=="tty", ATTRS{idVendor}=="239a", ATTRS{idProduct}=="8029", SYMLINK+="meshtastic"
# nRF52840, LilyGO T-Echo (Adafruit-Vendor, eink-Variante)
SUBSYSTEM=="tty", ATTRS{idVendor}=="239a", ATTRS{idProduct}=="4405", SYMLINK+="meshtastic"
```

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

Im Compose mountet `/dev/meshtastic` als `/dev/ttyACM0` in den Container. Liste erweitern, wann immer eine neue Node hinzukommt — `lsusb` listet die `idVendor:idProduct`-Kombination, sobald die Node am Pi steckt.

## Container-Lifecycle ans Device binden (systemd-Wrapper)

> **Vorfall 2026-05-03 → 2026-05-05:** Der `serial-bridge`-Container ist nach einem kurzen Node-Disconnect mit Exit-Code 137 + `no such file or directory` für `/dev/ttyACM0` in den `failed`-State gegangen. **`restart: unless-stopped` reanimiert in diesem Fall NICHT** — bekannte Docker-Eigenheit bei Device-Mount-Fehlern. Container war 47 Stunden tot, ohne dass irgendwas davon Notiz nahm.

Saubere Lösung: ein systemd-Service als Wrapper, der den Container-Lifecycle direkt an das Device-Lifecycle koppelt. Wenn der `/dev/meshtastic`-Symlink verschwindet (Node abgesteckt), stoppt systemd den Container automatisch. Wenn das Device wieder da ist, startet systemd den Container automatisch.

`/etc/systemd/system/meshtastic-serial-bridge.service`:

```ini
[Unit]
Description=Meshtastic Serial Bridge Container
Requires=docker.service dev-meshtastic.device
After=docker.service dev-meshtastic.device
BindsTo=dev-meshtastic.device

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/tomkenobi/meshmonitor
ExecStart=/usr/bin/docker compose up -d serial-bridge
ExecStop=/usr/bin/docker compose stop serial-bridge

[Install]
WantedBy=multi-user.target
```

Aktivieren:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now meshtastic-serial-bridge.service
```

`BindsTo=dev-meshtastic.device` ist der entscheidende Direktiv: systemd beobachtet den udev-Symlink `/dev/meshtastic` und triggert Service-Lifecycle-Events synchron mit dem Device. **Voraussetzung:** udev-Regel oben erzeugt diesen Symlink für die jeweilige Node-Vendor:Product-Kombination.

**Verifikations-Test:**
1. Node abstecken → `docker ps` zeigt serial-bridge gestoppt
2. Node wieder anstecken → `docker ps` zeigt serial-bridge laufend
3. Pi rebooten ohne angesteckte Node → Service wartet, kein Crashloop
4. Node während Boot anstecken → Service startet im Moment des Device-Erscheinens

`restart: always` im compose-File (statt `unless-stopped`) ist eine zusätzliche Schicht — fängt Container-interne Crashes ab, während der systemd-Wrapper Device-Disconnects abfängt.

## WLAN Access Point (Einsatz-Modus)

Im Einsatz fungiert der Pi als eigenständiger WLAN-AP. Tablets/Laptops verbinden sich direkt mit dem Pi, kein Internet nötig. Konfiguration via NetworkManager (Pi-OS Bookworm/Trixie default):

```bash
sudo nmcli connection add type wifi ifname wlan0 con-name "MeshMonitor-AP" \
    autoconnect yes ssid "MeshMonitor"
sudo nmcli connection modify "MeshMonitor-AP" \
    802-11-wireless.mode ap \
    802-11-wireless.band bg \
    802-11-wireless.channel 7 \
    ipv4.method shared \
    ipv4.addresses 10.42.0.1/24 \
    wifi-sec.key-mgmt wpa-psk \
    wifi-sec.psk "<SICHERES-PASSWORT>"
```

`ipv4.method shared` startet automatisch DHCP. Tablets bekommen IPs aus `10.42.0.0/24`, der Pi ist `10.42.0.1`.

Im AP-Mode bleibt der Pi via Ethernet wartbar — Pi 4 kann AP über `wlan0` und Internet/Wartung über `eth0` parallel betreiben.

## GeoJSON-Overlays

MeshMonitor scannt `/data/geojson/` automatisch. Files dort werden ohne UI-Aktion als Layer erfasst.

```bash
docker cp overlays/example-area.geojson meshmonitor:/data/geojson/
docker cp overlays/manifest.json meshmonitor:/data/geojson/
```

`manifest.json` steuert Anzeigename, Farbe, Sichtbarkeit:

```json
{
  "layers": [
    {
      "id": "example-area",
      "name": "Beispiel-Bereich",
      "filename": "example-area.geojson",
      "visible": true,
      "style": { "color": "#3498db", "weight": 2, "fillOpacity": 0.3 }
    }
  ]
}
```

**Polygon-/Linien-Layer** sind vorzuziehen (skalieren mit Zoom). Punkt-Layer haben fixe Pixelgröße und verdecken bei niedrigem Zoom.

## MBTiles aus OSM-Daten erzeugen (Tilemaker)

```bash
# OSM-Rohdaten holen
wget https://download.geofabrik.de/europe/austria-latest.osm.pbf

# Mit Tilemaker (https://github.com/systemed/tilemaker) verarbeiten
tilemaker --input austria-latest.osm.pbf --output austria.mbtiles \
    --config config-openmaptiles.json --process process-openmaptiles.lua
```

Datenquelle in `tiles/config.json` **muss** `v3` heißen — MeshMonitor erwartet diesen Identifier.

## GeoJSON-Overlays aus MBTiles extrahieren

```bash
# Layer extrahieren
ogr2ogr -f GeoJSON /tmp/alle.geojson -t_srs EPSG:4326 tiles/austria.mbtiles <layername>

# Auf Einsatzgebiet zuschneiden
ogr2ogr -f GeoJSON overlays/<output>.geojson \
    -lco COORDINATE_PRECISION=6 -lco RFC7946=YES \
    /tmp/alle.geojson -spat <west> <south> <east> <north>
```

Verfügbare Layer (OpenMapTiles-Schema): `boundary`, `waterway`, `transportation`, `building`, `water`, `landuse`, `housenumber`, `poi`.

Beispielgebiet Graz + Umland: `-spat 15.289287 47.009469 15.584722 47.143331`

## Update

```bash
# Backup vor Update
docker run --rm -v meshmonitor-data:/data -v "$PWD":/backup alpine \
    tar czf /backup/meshmonitor-data-$(date +%F).tar.gz -C /data .

# Update
docker compose pull
docker compose up -d
```

## Hinweise

- Bei Änderungen an `tiles/config.json` oder den Tileserver-Styles: `docker compose restart tileserver`
- Bounds in `tiles/config.json` begrenzen den verfügbaren Kartenausschnitt
- Pi 4 mit High-Endurance microSD ≥ 64 GB empfohlen für Dauerbetrieb
