# Feature Request: Custom MapLibre style support for vector tiles

**Repository:** https://github.com/yeraze/meshmonitor
**Typ:** Enhancement

## Title
Custom MapLibre style support for vector tiles (fixes offline rendering)

## Problem

When using vector tiles (`.pbf`) from a local TileServer GL Light, the map renders without any text labels (street names, place names, house numbers) and without icons. This is because the built-in MapLibre style in `VectorTileLayer.tsx` references the font `Open Sans Regular` in multiple symbol layers but does not define a `glyphs` or `sprite` URL in the style object.

Without these URLs, MapLibre GL cannot load the font data or icon sprites, making the map unusable for offline scenarios.

## Proposed solution

Allow users to provide a custom MapLibre GL style JSON for vector tile rendering. This could be:

1. **A style URL field in Map Settings** — pointing to a local or remote style JSON (e.g. `http://localhost:8081/styles/bright/style.json` from TileServer GL Light, or `https://api.thunderforest.com/styles/{style}/style.json?apikey={key}`)
2. **A local file upload** — similar to the new GeoJSON overlay feature, users could upload a `style.json` to `/data/styles/`
3. **Auto-detection** — when a TileServer GL Light URL is configured, MeshMonitor could automatically discover available styles via the TileServer's API

This would solve two problems at once:
- **Offline rendering**: users can set `glyphs` and `sprite` URLs pointing to the local tile server, which already serves fonts at `/fonts/{fontstack}/{range}.pbf`
- **Custom styling**: users can adjust map colors, simplify the map for overview displays, or optimize contrast for projector use — without needing the full TileServer GL for server-side rasterization

The infrastructure is already in place: MeshMonitor uses `maplibre-gl` + `@maplibre/maplibre-gl-leaflet`, and TileServer GL Light serves complete style JSONs with local font and sprite references.

## Steps to reproduce the offline issue

1. Set up MeshMonitor with TileServer GL Light and a local `.mbtiles` file
2. Configure a custom vector tile server (`http://localhost:8081/data/v3/{z}/{x}/{y}.pbf`)
3. Disconnect from the internet
4. Observe: map geometry renders, but all labels and icons are missing

## Additional note

The [Configurator](https://meshmonitor.org/configurator.html) states that TileServer GL Light "supports both vector (.pbf) and raster (.png) tiles", but the light version does not support server-side rasterization — raster tile URLs return 404. Only the full TileServer GL can rasterize, which is too resource-heavy for Raspberry Pi deployments.

## Context

We're deploying MeshMonitor on Raspberry Pis for a public safety mesh network (50-60 nodes) in Austria. Full offline capability — including properly labeled maps — is critical for emergency operations.
