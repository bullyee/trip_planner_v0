# Anime Pilgrimage Travel Planner

A local-first mobile app for planning anime pilgrimage trips — visit the real-world locations from your favorite anime series.

## Features

- **Regions (ROI)** — Group locations by area (e.g., "Kyoto", "Akihabara"). Create, edit, delete regions.
- **Points of Interest (POI)** — Add anime locations with coordinates, address, business hours, tags, and anime series reference. Full CRUD with form validation.
- **Trip Calendar** — Week-strip navigation, day view with time-sorted schedule, backlog pool. Schedule visits from POI detail or drag from backlog. Status tracking: backlog / scheduled / completed / skipped.
- **Anime Camera** — Load a reference anime screenshot, then take a photo with your native camera while the reference floats as a draggable, resizable overlay (Android). Pinch to resize, drag to reposition. Side-by-side comparison after capture. Photos save to the POI's media assets.
- **Ticket Organizer** — Manage QR codes and booking references linked to POIs.
- **JSON Export/Import** — Full trip data serialization for backup or syncing between devices. Copy to clipboard or save to file.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter / Dart |
| State Management | Riverpod |
| Local Database | Drift (SQLite) |
| Navigation | GoRouter |
| Camera Overlay | Android SYSTEM_ALERT_WINDOW + native platform channel |
| Media | image_picker |

## Project Structure

```
lib/
  core/
    database/     # Drift tables + generated code
    providers/    # Database provider
    router/       # GoRouter route definitions
    utils/        # JSON sync utility
  features/
    home/         # Home screen, sync screen
    roi/          # Region list + detail
    poi/          # POI create/edit/detail
    calendar/     # Week strip, day view, backlog
    camera/       # Anime camera with overlay
    ticket/       # QR ticket management
  shared/
    theme/        # Material 3 light/dark theme
```

## Database Schema

Four tables via Drift (SQLite):

- **rois** — id, name, description, is_offline_cached, created_at
- **pois** — id, roi_id, name, description, address, lat, lng, business_hours, contact_info, cover_image_uri, tags, anime_series_ref
- **time_chunks** — id, poi_id, date, start_time, end_time, status
- **media_assets** — id, poi_id, type, local_uri, remote_url, metadata

## Getting Started

```bash
# Install dependencies
flutter pub get

# Generate Drift database code
dart run build_runner build --delete-conflicting-outputs

# Run on connected device
flutter run
```

## Platform Notes

| Feature | Android | iOS | Desktop |
|---------|---------|-----|---------|
| Camera overlay | Floating reference image via SYSTEM_ALERT_WINDOW | image_picker fallback | image_picker fallback |
| Photo quality | Native camera (HDR, Night Sight, etc.) | Native camera | N/A |
| Overlay interaction | Drag + pinch to resize | Not available | Not available |
| Database | SQLite via Drift | Same | Same |

On Android, the camera feature requires "Draw over other apps" permission (prompted on first use).

## License

MIT
