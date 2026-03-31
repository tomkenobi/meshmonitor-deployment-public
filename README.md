# MeshMonitor - Offline-Karten Setup

Deployment-Anleitung für MeshMonitor mit lokalem Tileserver (tileserver-gl-light) und Vektor-Karten aus MBTiles.

Zielplattform: Raspberry Pi mit Docker. Das Mesh-Netzwerk umfasst 50-60 Nodes, MeshMonitor wird auf einer Handvoll Raspis deployed (nicht pro Node).

Alternativ kann eine Konfiguration über den [MeshMonitor Configurator](https://meshmonitor.org/configurator.html) generiert werden.

## Voraussetzungen

- Docker und Docker Compose
- Meshtastic-Node per USB angeschlossen (`/dev/ttyACM0`)
- MBTiles-Datei (z.B. `austria.mbtiles`, erstellt mit Tilemaker)

## Verzeichnisstruktur

```
meshmonitor/
├── .env                        # Optionale Umgebungsvariablen
├── docker-compose.yml          # Docker Compose für alle Services
├── README.md
├── tiles/                      # Tileserver-Daten
│   ├── config.json             # Tileserver-Konfiguration
│   ├── austria.mbtiles         # Kartendaten (OpenMapTiles-Schema)
│   ├── fonts/                  # Glyphen für Kartenbeschriftung
│   ├── sprites/                # Icons für Kartenstile
│   └── styles/                 # Kartenstile
│       ├── bright/
│       ├── dark-matter/
│       ├── fiord/
│       ├── overview/
│       └── positron/
└── overlays/                   # QGIS-Projekte und GeoJSON-Overlays
```

## Deployment

### 1. Container starten

```bash
cd meshmonitor
docker compose up -d
```

Das startet drei Container:

| Container | Port | Funktion |
|---|---|---|
| `meshtastic-serial-bridge` | 4403 | USB-zu-TCP Bridge für Meshtastic-Node |
| `meshmonitor` | 8080 | MeshMonitor Weboberfläche |
| `meshmonitor-tileserver` | 8081 | Tileserver GL Light (Vektor-Karten) |

### 2. Custom Tile Server einrichten

In MeshMonitor unter **Settings > Map > Add Custom Tile Server**:

| Feld | Wert |
|---|---|
| **Name** | Austria (oder gewünschter Name) |
| **Tile URL** | `http://localhost:8081/data/v3/{z}/{x}/{y}.pbf` |
| **Attribution** | `© OpenStreetMap contributors \| OpenMapTiles` |

Anschliessend den neuen Tile Server als aktive Karte auswählen.

### 3. Tileserver prüfen

Der Tileserver bietet eine eigene Weboberfläche unter `http://localhost:8081/` mit Vorschau der verfügbaren Styles und Datenquellen.

## Tiles

Tileserver GL Light liefert ausschliesslich Vektor-Tiles (kein serverseitiges Rastern). Das Styling der Karte wird von MeshMonitor clientseitig angewandt und kann nicht beeinflusst werden.

Tile-URL: `http://localhost:8081/data/v3/{z}/{x}/{y}.pbf`

## Konfiguration

### Tileserver (config.json)

Die Datei `tiles/config.json` definiert die Datenquellen und Styles. Die Datenquelle muss als `v3` benannt sein, da MeshMonitor diesen Identifier erwartet.

### Styles anpassen

Jeder Style verweist in seiner `style.json` auf die Datenquelle:

```json
"sources": {
  "openmaptiles": {
    "type": "vector",
    "url": "mbtiles://{v3}"
  }
}
```

Der Identifier `v3` muss mit dem Eintrag in `config.json` übereinstimmen.

### Umgebungsvariablen (.env)

Die `.env`-Datei wird von MeshMonitor geladen. Aktuell wird sie für optionale Konfiguration wie eine alternative Meshtastic-Node-IP genutzt (`MESHTASTIC_NODE_IP`).

## Netzwerkzugriff (WLAN Access Point)

Im Einsatzszenario fungiert der Raspi als eigenständiger WLAN Access Point. Damit ist kein bestehendes Netzwerk und kein Internet erforderlich – Strom und USB-Node reichen.

### Einsatz-Setup

```
[Meshtastic Node am Dach] ~~~Funk~~~ [Node im Stabsraum] --USB--> [Raspi] ))WLAN((  [Laptops/Tablets]
```

### Access Point einrichten

Pakete installieren (einmalig, mit Internetzugang):

```bash
sudo apt install hostapd dnsmasq
sudo systemctl unmask hostapd
```

WLAN-Interface konfigurieren (`/etc/dhcpcd.conf`):

```
interface wlan0
    static ip_address=10.0.0.1/24
    nohook wpa_supplicant
```

DHCP-Server (`/etc/dnsmasq.conf`):

```
interface=wlan0
dhcp-range=10.0.0.10,10.0.0.50,255.255.255.0,24h
# Kein Default Gateway verteilen, damit LAN-Internet parallel funktioniert
dhcp-option=3
```

Access Point (`/etc/hostapd/hostapd.conf`):

```
interface=wlan0
ssid=MeshMonitor
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
wpa=2
wpa_passphrase=<SICHERES-PASSWORT>
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
```

Hostapd-Konfiguration aktivieren (`/etc/default/hostapd`):

```
DAEMON_CONF="/etc/hostapd/hostapd.conf"
```

Dienste aktivieren und starten:

```bash
sudo systemctl enable hostapd dnsmasq
sudo systemctl start hostapd dnsmasq
```

### ALLOWED_ORIGINS anpassen

In `docker-compose.yml` die feste Access-Point-IP eintragen:

```yaml
environment:
  - ALLOWED_ORIGINS=http://localhost:8080,http://10.0.0.1:8080
```

### Zugriff im Einsatz

1. Raspi mit Strom versorgen und Meshtastic-Node per USB anschliessen
2. Laptop/Tablet mit WLAN `MeshMonitor` verbinden
3. Im Browser `http://10.0.0.1:8080` öffnen

Kein Internet, kein bestehendes Netzwerk, kein HTTPS nötig.

## USB-Geräteerkennung (udev)

Standardmässig wird die Node als `/dev/ttyACM0` erkannt. Für eine zuverlässige Zuordnung unabhängig von der USB-Reihenfolge kann eine udev-Regel einen festen Symlink `/dev/meshtastic` erstellen.

Unterstützte Geräte:

| Gerät | Chip | idVendor | idProduct |
|---|---|---|---|
| LilyGO T-Deck Plus | ESP32-S3 (nativ USB) | `303a` | `1001` |
| Heltec MeshPocket | ESP32-S3 (nativ USB) | `303a` | `1001` |
| Seeed SenseCAP T1000-E | nRF52840 (nativ USB) | `239a` | `8029` |

udev-Regel erstellen (`/etc/udev/rules.d/99-meshtastic.rules`):

```
# ESP32-S3 (T-Deck Plus, MeshPocket)
SUBSYSTEM=="tty", ATTRS{idVendor}=="303a", ATTRS{idProduct}=="1001", SYMLINK+="meshtastic"

# nRF52840 (SenseCAP T1000-E)
SUBSYSTEM=="tty", ATTRS{idVendor}=="239a", ATTRS{idProduct}=="8029", SYMLINK+="meshtastic"
```

Regel aktivieren:

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

Anschliessend in `docker-compose.yml` den festen Symlink verwenden:

```yaml
devices:
  - /dev/meshtastic:/dev/ttyACM0
environment:
  - SERIAL_DEVICE=/dev/ttyACM0
```

**Hinweis:** Die IDs basieren auf den typischen Chips dieser Geräte. Zur Verifizierung das Gerät anschliessen und `udevadm info -a /dev/ttyACM0 | grep -E "idVendor|idProduct"` ausführen.

## GeoJSON-Overlays vorkonfigurieren (Deployment)

Für ein einheitliches Deployment auf mehreren Raspis können GeoJSON-Overlays vorab ins Volume gelegt werden. MeshMonitor erkennt Dateien in `/data/geojson/` automatisch (Auto-Discovery).

Die Overlays werden über eine `manifest.json` gesteuert, die Anzeigename, Farbe und Sichtbarkeit definiert. Es können sprechende Dateinamen und IDs verwendet werden (keine UUIDs nötig).

Beispiel-Struktur im Volume (`/data/geojson/`):

```
geojson/
├── manifest.json
├── leuchttuerme.geojson
├── notstromaggregate.geojson
├── gemeindegrenzen.geojson
└── hauptverkehrsrouten.geojson
```

Beispiel `manifest.json`:

```json
{
  "layers": [
    {
      "id": "leuchttuerme",
      "name": "Leuchttürme",
      "filename": "leuchttuerme.geojson",
      "visible": true,
      "style": {
        "color": "#e74c3c",
        "opacity": 1,
        "weight": 2,
        "fillOpacity": 0.75
      },
      "createdAt": 1774820487353,
      "updatedAt": 1774820487353
    },
    {
      "id": "notstromaggregate",
      "name": "Notstromaggregate",
      "filename": "notstromaggregate.geojson",
      "visible": true,
      "style": {
        "color": "#3498db",
        "opacity": 1,
        "weight": 1,
        "fillOpacity": 0.3
      },
      "createdAt": 1774820487353,
      "updatedAt": 1774820487353
    }
  ]
}
```

So starten alle Raspis mit identischen, sauber benannten Overlays – ohne manuelle Konfiguration über die UI.

## GeoJSON-Overlays aus MBTiles extrahieren

Aus der `austria.mbtiles` können Vektordaten für Overlays extrahiert werden:

```bash
# Alle Hausnummern für ein Gebiet exportieren (zweistufig, da MVT-Driver räumlich nicht direkt filtern kann)
ogr2ogr -f GeoJSON /tmp/alle.geojson -t_srs EPSG:4326 tiles/austria.mbtiles <layername>
ogr2ogr -f GeoJSON overlays/<output>.geojson -lco COORDINATE_PRECISION=6 -lco RFC7946=YES /tmp/alle.geojson -spat <west> <south> <east> <north>
```

Verfügbare Layer in der MBTiles (OpenMapTiles-Schema):

| Layer | Inhalt | Geometrie |
|---|---|---|
| `boundary` | Gemeindegrenzen | Linie |
| `waterway` | Flussverläufe | Linie |
| `transportation` | Straßen/Verkehrsrouten | Linie |
| `transportation_name` | Straßennamen | Linie |
| `building` | Gebäude | Polygon |
| `water` | Wasserflächen | Polygon |
| `landuse` | Landnutzung | Polygon |
| `park` | Parks/Grünflächen | Polygon |
| `housenumber` | Hausnummern | Punkt |
| `poi` | Points of Interest | Punkt |

Einsatzgebiet Graz + Umland: `-spat 15.289287 47.009469 15.584722 47.143331`

**Hinweis:** Punkt-Layer (housenumber, poi) eignen sich weniger als Overlay, da die Darstellungsgrösse nicht mit dem Zoom-Level skaliert. Linien- und Polygon-Layer (boundary, waterway, transportation) funktionieren besser.

## Hinweise

- Die MBTiles-Datei wurde mit [Tilemaker](https://github.com/systemed/tilemaker) aus OSM-Daten im OpenMapTiles-Schema erzeugt.
- Bei Änderungen an `config.json` oder den Styles muss der Tileserver neu gestartet werden: `docker compose restart tileserver`
- Der Tileserver hat CORS standardmässig aktiviert.
- Bounds in der config.json begrenzen den verfügbaren Kartenausschnitt (aktuell: Österreich).
