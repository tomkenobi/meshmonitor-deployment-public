# Feature Request: GeoJSON Overlay Layer Support

**Repository:** https://github.com/yeraze/meshmonitor
**Typ:** Enhancement

## Title
Support for GeoJSON overlay layer on map

## Description

It would be very useful to have the ability to load a GeoJSON file as an overlay on top of the active tile layer. This would allow users to display custom points of interest, boundaries, or areas relevant to their deployment — without having to bake them into pre-rendered raster tiles.

### Use Case

In a public safety / emergency services deployment with 50-60 nodes, we need to display:
- Emergency gathering points
- Municipal boundaries
- Key infrastructure (hospitals, fire stations, etc.)
- Custom operational zones

Currently, the only way to include these is to pre-render them into raster tiles via QGIS, which means re-rendering every time something changes.

### Proposed Solution

Since MeshMonitor already uses Leaflet (react-leaflet), GeoJSON support is essentially built-in. A minimal implementation could:

1. Allow uploading one or more `.geojson` files via Map Settings
2. Store them in the `/data` volume
3. Render them as a Leaflet `<GeoJSON>` layer on top of the active tileset
4. Support basic styling (color, opacity, icon for point features)

### Technical Notes

- `react-leaflet` has a native `<GeoJSON>` component
- The overlay should render independently of the active tileset (raster or vector)
- Multiple GeoJSON layers with toggle visibility would be ideal
- Minimal change footprint — no impact on existing tile logic

### References

- Leaflet GeoJSON: https://leafletjs.com/reference.html#geojson
- react-leaflet GeoJSON: https://react-leaflet.js.org/docs/api-components/#geojson
