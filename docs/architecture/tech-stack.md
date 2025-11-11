# Tech Stack

## Technology Stack Table

| Category                 | Technology     | Version | Purpose                           | Rationale                                                                                         |
| ------------------------ | -------------- | ------- | --------------------------------- | ------------------------------------------------------------------------------------------------- |
| **Mobile Framework**     | Flutter        | 3.24+   | Cross-platform mobile development | Official stable version, mature ecosystem, excellent performance, single codebase for Android/iOS |
| **Language**             | Dart           | 3.5+    | Application language              | Required by Flutter, strong typing, null safety, modern async/await                               |
| **Map Rendering**        | flutter_map    | 7.0.0   | Interactive map display           | Open-source, OSM-compatible, actively maintained, no proprietary SDKs                             |
| **Map Tiles**            | OpenStreetMap  | N/A     | Map tile provider                 | Free, open-source, no API keys, aligns with NFR5                                                  |
| **Coordinate Utilities** | latlong2       | 0.9.0   | Lat/Lng calculations              | Required by flutter_map, geographic calculations                                                  |
| **Location Services**    | geolocator     | 12.0.0  | GPS/positioning                   | Cross-platform, robust permissions handling, actively maintained                                  |
| **HTTP Client**          | http           | 1.2.0   | API requests                      | Official Dart package, simple, sufficient for REST calls                                          |
| **State Management**     | provider       | 6.1.0   | Reactive state updates            | Official recommendation, simple, perfect for small apps                                           |
| **Primary Routing API**  | OSRM           | N/A     | Route calculation                 | Free demo server, no API key, fast, reliable                                                      |
| **Fallback Routing API** | GraphHopper    | N/A     | Route calculation backup          | Free tier (500/day), API key required, good fallback                                              |
| **Unit Testing**         | flutter_test   | SDK     | Unit/widget tests                 | Built-in Flutter testing framework                                                                |
| **Mocking**              | mockito        | 5.4.0   | Test mocking                      | Industry standard for Dart/Flutter                                                                |
| **Build Tool**           | Flutter CLI    | 3.24+   | Build/run/test                    | Official tooling, integrated with SDK                                                             |
| **Linting**              | flutter_lints  | 4.0.0   | Code quality                      | Official lint rules, enforces best practices                                                      |
| **CI/CD**                | GitHub Actions | N/A     | Automated builds/tests            | Free for public repos, good Flutter support                                                       |
| **Version Control**      | Git            | 2.40+   | Source control                    | Industry standard                                                                                 |
| **License**              | MIT or GPL v3  | N/A     | Open-source license               | Per NFR10, community-friendly                                                                     |

**Notes:**

- No connectivity detection package needed - relying on API error handling
- flutter_map handles tile caching internally - no additional package required
- No database, local storage, analytics, or crash reporting per privacy requirements
