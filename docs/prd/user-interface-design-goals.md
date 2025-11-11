# User Interface Design Goals

## Overall UX Vision

NaviMap embraces radical minimalism with a zero-UI-chrome philosophy. The entire application is a single full-screen map view with no navigation bars, toolbars, or menus. Users interact purely through direct map manipulation (pan, zoom, tap) with all functionality discoverable through natural gestures. Visual feedback is immediate and unobtrusive: current location appears as a standard blue dot, destination as a red pin, and the route as a semi-transparent colored polyline overlay. The experience feels like using a paper map enhanced with live routing—no learning curve, no configuration, no cognitive overhead.

## Key Interaction Paradigms

- **Map-First Interface:** Full-screen map is the entire UI; no separate screens or navigation
- **Direct Manipulation:** All interactions happen through map gestures (tap, pan, zoom, pinch)
- **Immediate Feedback:** Visual state changes happen instantly (pin placement, route drawing) without loading screens
- **Stateless Simplicity:** Single destination pin model eliminates multi-pin management complexity
- **Discoverable Through Use:** Core functionality is self-evident; no tutorials, tooltips, or help screens needed
- **Graceful Degradation:** Error states displayed as non-intrusive toast messages that don't block map interaction

## Core Screens and Views

**1. Main Map Screen (Only Screen):**
- Full-screen OpenStreetMap display with standard tile rendering
- User's current location (blue dot marker, standard GPS indicator)
- Destination pin (red marker, appears on map tap)
- Route polyline (colored line from current location to destination)
- Minimal overlay: Location permission dialog (Android/iOS standard), network error toast (bottom), API error toast (bottom)

## Accessibility: None (MVP)

Accessibility features are explicitly out of scope for the one-week MVP. Post-MVP phases will address WCAG AA compliance including screen reader support, high contrast modes, and gesture alternatives. The current direct manipulation interface will require significant accessibility enhancements for users with visual or motor impairments.

## Branding

Minimal branding approach with open-source aesthetic. App icon will be a simple geometric design: red pin on blue/green map background. No splash screen—application launches directly to map for fastest time-to-value. Color scheme follows OpenStreetMap's natural palette (blue water, green parks, gray roads) with route polyline in high-visibility color (blue or magenta, 4-6px width with slight transparency). UI follows Flutter Material Design defaults to minimize custom styling and maintain cross-platform consistency.

## Target Device and Platforms: Mobile-Only (Android and iOS)

**Primary:** Android smartphones (7.0+) and iOS devices (12.0+) in portrait and landscape orientations

**Development:** Linux desktop with Android Emulator for testing, macOS for iOS builds

**Responsive Behavior:** Map scales to fill entire screen regardless of device size. Touch targets (destination pin tap) meet minimum 44x44px accessibility guidelines even though formal accessibility is out of MVP scope. No separate tablet layouts—same interface scales appropriately.

## UI Layout Reference

```
┌─────────────────────────────────────┐
│                                     │ ← Full-screen OpenStreetMap
│          🗺️ Map Tiles              │
│                                     │
│              📍 (Red Pin)           │ ← Destination marker (tap to place)
│                                     │
│          🔵 (Blue Dot)              │ ← Current location marker
│                                     │
│         ━━━━━━━━━━                 │ ← Route polyline (blue/magenta)
│                                     │
│                                     │
│  ⚠️ Toast Message (if error)       │ ← Bottom-aligned, auto-dismiss
└─────────────────────────────────────┘

Interaction Model:
- Pan: Drag to move map
- Zoom: Pinch to zoom in/out
- Tap: Place destination pin (removes previous pin)
- No UI chrome: No toolbars, buttons, or navigation
```

---
