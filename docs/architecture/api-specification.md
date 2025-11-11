# API Specification

Since NaviMap has no custom backend API, this section documents the **external routing APIs** we integrate with: OSRM (primary) and GraphHopper (fallback).

## OSRM API (Primary)

**Base URL:** `https://router.project-osrm.org`  
**Documentation:** http://project-osrm.org/docs/v5.24.0/api/  
**Authentication:** None required (public demo server)  
**Rate Limits:** Fair use policy (no hard limits documented)

**Endpoint:** `GET /route/v1/driving/{coordinates}`

**Request Format:**

```
GET https://router.project-osrm.org/route/v1/driving/{lon1},{lat1};{lon2},{lat2}?overview=full&geometries=geojson
```

**Query Parameters:**

- `overview=full` - Include full route geometry
- `geometries=geojson` - Return coordinates as GeoJSON (array of [lon, lat])

**Example Request:**

```
GET https://router.project-osrm.org/route/v1/driving/-122.4194,37.7749;-122.4089,37.7849?overview=full&geometries=geojson
```

**Response Schema (Success - 200 OK):**

```json
{
  "code": "Ok",
  "routes": [
    {
      "geometry": {
        "coordinates": [
          [-122.4194, 37.7749],
          [-122.418, 37.776],
          [-122.4089, 37.7849]
        ],
        "type": "LineString"
      },
      "distance": 1234.5,
      "duration": 180.2
    }
  ]
}
```

## GraphHopper API (Fallback)

**Base URL:** `https://graphhopper.com/api/1`  
**Documentation:** https://docs.graphhopper.com/  
**Authentication:** API key required (free tier: 500 requests/day)  
**Rate Limits:** 500 requests/day, 10 requests/minute

**Endpoint:** `GET /route`

**Request Format:**

```
GET https://graphhopper.com/api/1/route?point={lat1},{lon1}&point={lat2},{lon2}&vehicle=car&key={API_KEY}&points_encoded=false
```

**Response Schema (Success - 200 OK):**

```json
{
  "paths": [
    {
      "distance": 1234.5,
      "time": 180200,
      "points": {
        "coordinates": [
          [-122.4194, 37.7749],
          [-122.418, 37.776],
          [-122.4089, 37.7849]
        ]
      }
    }
  ]
}
```

## API Integration Strategy

**Fallback Logic:**

```dart
Future<Route> calculateRoute(UserLocation start, Destination end) async {
  try {
    return await _fetchRouteFromOSRM(start, end);
  } catch (e) {
    try {
      return await _fetchRouteFromGraphHopper(start, end);
    } catch (e2) {
      throw RoutingException('Both routing services failed');
    }
  }
}
```

**Configuration:**

- OSRM timeout: 5 seconds
- GraphHopper timeout: 5 seconds
- All requests over HTTPS
- User-Agent: `NaviMap/1.0 (Open Source Navigation MVP)`
