# Core Workflows

## Workflow 1: App Launch and Initial Location Display

```mermaid
sequenceDiagram
    participant User
    participant App
    participant LocationService
    participant GPS
    participant AppState
    participant MapScreen
    participant OSM

    User->>App: Opens app
    App->>LocationService: Initialize & requestPermission()
    LocationService->>User: Show permission dialog
    User->>LocationService: Grant permission

    LocationService->>GPS: Start location stream
    GPS-->>LocationService: Position update
    LocationService->>AppState: updateLocation(UserLocation)

    App->>MapScreen: Build widget
    MapScreen->>OSM: Load map tiles
    OSM-->>MapScreen: Tile images

    AppState->>MapScreen: notifyListeners()
    MapScreen->>MapScreen: Render blue dot at location
    MapScreen->>User: Display map with current location
```

**Success Criteria:** Map loads within 3 seconds (NFR1), location appears as blue dot

---

## Workflow 2: User Sets Destination and Views Route

```mermaid
sequenceDiagram
    participant User
    participant MapScreen
    participant AppState
    participant RoutingService
    participant OSRM
    participant GraphHopper

    User->>MapScreen: Taps map at coordinates
    MapScreen->>AppState: setDestination(Destination)
    AppState->>MapScreen: notifyListeners()
    MapScreen->>User: Display red pin at tap location

    MapScreen->>AppState: setLoadingRoute(true)
    MapScreen->>User: Show loading indicator

    MapScreen->>RoutingService: calculateRoute(start, end)
    RoutingService->>OSRM: GET /route/v1/driving/...

    alt OSRM Success
        OSRM-->>RoutingService: 200 OK with route JSON
        RoutingService->>RoutingService: Parse to Route object
    else OSRM Failure
        OSRM-->>RoutingService: Error/Timeout
        RoutingService->>GraphHopper: GET /route (fallback)
        GraphHopper-->>RoutingService: Route JSON
        RoutingService->>RoutingService: Parse to Route object
    end

    RoutingService->>AppState: setRoute(Route)
    AppState->>MapScreen: notifyListeners()
    MapScreen->>MapScreen: Render blue polyline
    MapScreen->>User: Display complete route
```

**Success Criteria:** Route calculates within 5 seconds (NFR3), polyline renders smoothly

---

## Workflow 3: Location Updates While Route Active

```mermaid
sequenceDiagram
    participant GPS
    participant LocationService
    participant AppState
    participant MapScreen

    Note over MapScreen: Route already displayed

    loop Every location update
        GPS->>LocationService: New position
        LocationService->>AppState: updateLocation(newLocation)
        AppState->>MapScreen: notifyListeners()
        MapScreen->>MapScreen: Update blue dot position
    end

    Note over MapScreen: Route polyline remains unchanged<br/>(No automatic rerouting in MVP)
```

**Success Criteria:** Blue dot updates smoothly, UI responds within 100ms (NFR2)

**MVP Limitation:** No automatic rerouting when user deviates from path (out of scope)
