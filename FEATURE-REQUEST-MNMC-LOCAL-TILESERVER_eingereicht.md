# Feature Request: Local TileServer Support für MNMC

**Repository:** https://github.com/meshtastic/network-management-client
**Typ:** Enhancement

## Title
Support for local TileServer GL / self-hosted vector tiles

## Problem

The app already supports changing the map style URL in settings, which is great. However, for deployments without reliable internet (field operations, remote areas), there's no documented or supported path to use a local tile server.

## Proposed solution

Rather than implementing a full offline map download system (which is complex and on the roadmap), a simpler intermediate step would make a huge difference:

1. **Document** that users can point the style URL to a local TileServer GL (Light) instance serving vector tiles from MBTiles files
2. **Ensure glyphs and sprites resolve correctly** when using a local style JSON (currently MapLibre needs proper `glyphs` and `sprite` URLs in the style — if these point to external CDNs, labels won't render offline)
3. **Optionally** add a "Local TileServer" preset in Map Settings (e.g. `http://localhost:8081/styles/{style}/style.json`)

This approach works today with minimal code changes:
- Users obtain MBTiles files independently (OpenMapTiles downloads, Tilemaker, Protomaps, etc.)
- A TileServer GL Light container runs alongside the app
- The existing style URL config points to the local server

## Why this matters

This unblocks offline use cases immediately without needing to build tile download infrastructure. The full "region download" feature can still come later as a convenience layer on top.

## Reference

MeshMonitor recently implemented this exact approach — local TileServer GL Light + custom MapLibre style JSON upload. Works fully offline on Raspberry Pi deployments.
