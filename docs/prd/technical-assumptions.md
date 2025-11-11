# Technical Assumptions

## Repository Structure: Monorepo

Single Flutter project repository containing Android and iOS platform targets. Standard Flutter project structure with platform-specific directories. Development and testing occur on Linux host using Android emulator and iOS simulator. This aligns with Flutter best practices for cross-platform mobile applications and simplifies the one-week development timeline by maintaining a single codebase.

## Service Architecture

**Single-Screen Monolithic Flutter Application** with layered service architecture:

- **Presentation Layer:** Single MapScreen widget (full-screen map UI)
- **Service Layer:** LocationService (GPS/positioning), RoutingService (API integration with OSRM/GraphHopper)
- **State Management:** Provider package for reactive UI updates
- **Data Layer:** Ephemeral state only (current location, destination pin, active route)—no persistent storage or database

Architecture follows Flutter's recommended pattern for simple applications. No backend infrastructure required; all logic runs client-side with external API calls for routing calculations.

## Testing Requirements

**MVP Testing Approach (Minimal):**

- **Manual Testing:** Primary validation on Android Emulator (Linux host) and Android physical device if available
- **iOS Testing:** iOS Simulator testing (requires macOS access) or defer to post-MVP validation
- **Unit Tests:** Critical business logic only (route parsing, coordinate transformations)
- **Integration Tests:** None for MVP (time constraint)
- **End-to-End Tests:** Manual user flow testing (launch → location → tap → route display)

**Post-MVP Testing Evolution:**
- Add Flutter integration tests for core user flows
- Implement widget tests for map interactions
- Set up CI/CD pipeline with automated test runs
- Test on multiple Android versions and iOS devices

**Rationale:** One-week timeline on Linux development machine requires Android Emulator as primary testing platform. iOS testing may be limited without macOS access but can be validated post-MVP or via CI/CD services.

## Additional Technical Assumptions and Requests

**Core Technology Stack:**
- **Flutter SDK:** Version 3.24+ (latest stable), Dart 3.5+
- **Map Rendering:** flutter_map ^7.0.0 (open-source, OSM-compatible)
- **Map Tiles:** OpenStreetMap tile servers (tile.openstreetmap.org)
- **Location Services:** geolocator ^12.0.0 (cross-platform GPS)
- **HTTP Client:** http ^1.2.0 (for routing API calls)
- **State Management:** provider ^6.1.0 (official, simple)
- **Coordinate Utilities:** latlong2 ^0.9.0 (LatLng calculations)

**Routing API Integration:**
- **Primary:** OSRM Demo Server (http://router.project-osrm.org) - free, no API key
- **Fallback:** GraphHopper Free Tier (requires API key, 500 requests/day limit)
- **Route Profile:** Car/driving mode only for MVP
- **Request Strategy:** Direct HTTP GET with coordinate parameters
- **Error Handling:** Exponential backoff on failures, fallback to secondary API if primary unavailable

**Build and Deployment:**
- **Development Platform:** Linux (Ubuntu/Debian) with Android Studio/VS Code
- **Android Build:** APK for emulator/device testing, AAB for future Play Store release
- **iOS Build:** Requires macOS for building (can develop Flutter code on Linux, build on macOS later)
- **Testing Platforms:** Android Emulator on Linux (primary), physical Android device (preferred), iOS Simulator on macOS (secondary/post-MVP)
- **Build Tools:** Flutter CLI (`flutter build apk`, `flutter run`, `flutter emulators`)

**Platform-Specific Requirements:**
- **Target Platforms:** Android 7.0+ (API 24+) and iOS 12.0+ for end users only
- **Development Environment:** Linux desktop with Android SDK and emulator
- **Android Permissions:** ACCESS_FINE_LOCATION, INTERNET (declared in AndroidManifest.xml)
- **iOS Permissions:** NSLocationWhenInUseUsageDescription (Info.plist)
- **Emulator Testing:** Android Emulator with Google Play Services for GPS simulation

**Performance Targets:**
- **App Launch Time:** < 3 seconds to map display
- **Map Tile Loading:** Progressive loading with visible feedback
- **Route Calculation:** < 5 seconds under normal network (depends on API response time)
- **Memory Usage:** < 200MB RAM footprint
- **Battery Impact:** Minimal GPS usage (location updates only when app active)

**Development Environment Requirements:**
- Flutter SDK properly configured (`flutter doctor` passes all checks)
- Android SDK with API level 24+ tools installed
- Android Emulator with system image and Google Play Services
- Git for version control
- Internet connectivity for package downloads and API testing

**API Rate Limiting and Compliance:**
- OSRM demo server: Respect fair use policy, implement request throttling
- OpenStreetMap tiles: Follow tile usage policy (max 2 requests/second, proper User-Agent header)
- Implement local caching for map tiles to reduce server load
- Add User-Agent header: "NaviMap/1.0 (Open Source Navigation MVP)"

**Security Considerations:**
- All external API calls over HTTPS
- No API keys stored in source code (use environment variables for GraphHopper if needed)
- No user data collection or transmission
- Location data never leaves device except as routing request parameters
- Open-source codebase for community security review

**Code Quality Standards:**
- Follow Dart style guide and Flutter best practices
- Use meaningful variable/function names
- Comment complex logic (routing calculations, coordinate transformations)
- Organize code by feature (services, models, widgets)
- Keep widget tree shallow for performance

**Dependency Management:**
- Pin major versions in pubspec.yaml to ensure reproducible builds
- Minimize external dependencies (only essential packages)
- Prefer packages with high pub.dev scores and active maintenance
- Document any platform-specific dependency quirks

---

