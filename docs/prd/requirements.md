# Requirements

## Functional Requirements

**FR1:** The application SHALL display an interactive map on launch using OpenStreetMap tiles that supports pan and zoom gestures.

**FR2:** The application SHALL automatically detect and display the user's current GPS location as a blue marker on the map.

**FR3:** The application SHALL allow users to set a destination by tapping any point on the map, displaying a red pin marker at the tapped location.

**FR4:** The application SHALL maintain only one destination pin at a time, replacing any existing pin when a new destination is tapped.

**FR5:** The application SHALL calculate the shortest car route from the current location to the destination pin using OSRM or GraphHopper routing API.

**FR6:** The application SHALL display the calculated route as a colored polyline overlay on the map.

**FR7:** The application SHALL automatically recalculate and update the route when a new destination pin is placed.

**FR8:** The application SHALL request location permissions from the user on first launch with clear explanation.

**FR9:** The application SHALL handle loss of GPS signal gracefully with appropriate user feedback.

**FR10:** The application SHALL handle network connectivity loss with appropriate error messaging.

**FR11:** The application SHALL handle routing API failures with fallback mechanisms or error notifications.

## Non-Functional Requirements

**NFR1:** Map shall load and display within 3 seconds of application launch on target devices.

**NFR2:** User interactions (pan, zoom, tap) SHALL respond within 100ms for smooth user experience.

**NFR3:** Route calculation SHALL complete within 5 seconds under normal network conditions.

**NFR4:** The application SHALL successfully build and run on Android 7.0+ (API level 24+) and iOS 12.0+.

**NFR5:** The application SHALL use zero paid services or APIs, relying exclusively on free/open-source technologies.

**NFR6:** The application SHALL collect zero user data, implement no tracking, and require no user accounts.

**NFR7:** The application SHALL make all API calls over HTTPS for network security.

**NFR8:** The application package size SHALL remain under 50MB to minimize download burden.

**NFR9:** The application SHALL comply with OpenStreetMap tile usage policies and API rate limiting best practices.

**NFR10:** The codebase SHALL be released under MIT or GPL v3 license for open-source community contribution.

**NFR11:** The application SHALL achieve zero crashes during core user flow (launch → view location → set destination → see route) in testing.

**NFR12:** The application SHALL retain zero user data. All application state (location, destination, route) is ephemeral and cleared when the app is closed.

---
