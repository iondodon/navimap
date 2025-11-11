# Open Questions and Future Considerations

## Known Limitations (MVP)

1. **No Turn-by-Turn Navigation:** MVP only visualizes routes, does not provide voice guidance or step-by-step directions
2. **No Route Recalculation:** If user deviates from route, no automatic rerouting occurs
3. **No Offline Maps:** Requires internet for map tiles and routing (could add later with offline tile storage)
4. **No Route Alternatives:** Always shows single shortest route (could add alternate routes UI)
5. **No ETA Updates:** Route duration is static estimate from API, not updated with traffic
6. **Single Transportation Mode:** Car-only routing (could add walking, cycling, public transit)
7. **No Address Search:** Destination selection only via map tap (could add geocoding/search)
8. **No Route History:** No saved routes or favorites (could add local storage)
9. **No Multi-Stop Routes:** Single origin-destination only (could add waypoints)
10. **No Customization:** No theme selection, map style options, or settings screen

## Technical Debt to Address Post-MVP

**Code Quality:**

- Add comprehensive integration tests
- Implement proper logging framework (instead of print statements)
- Add crash reporting (e.g., Sentry, Firebase Crashlytics)
- Implement analytics to understand user behavior (opt-in only)

**Architecture:**

- Consider BLoC pattern if app grows beyond single screen
- Abstract map provider (currently tightly coupled to flutter_map)
- Implement repository pattern more formally (currently lightweight)

**Performance:**

- Benchmark tile loading on slow networks
- Profile memory usage during long sessions
- Optimize route polyline rendering for very long routes (1000+ points)

**Security:**

- Implement certificate pinning if self-hosting routing API
- Add API key rotation mechanism for GraphHopper
- Consider obfuscating API keys (though limited value for free public APIs)

## Post-MVP Feature Roadmap

**Phase 2 - Navigation Enhancements (Week 2-3):**

- Turn-by-turn directions UI (text list of steps)
- Automatic rerouting when user deviates
- Multiple route options (fastest, shortest, scenic)
- Traffic-aware routing (requires different API or paid tier)

**Phase 3 - User Experience (Week 4-5):**

- Address/place search (integrate Nominatim geocoding API)
- Route history and favorites (local SQLite storage)
- Settings screen (map style, units, routing preferences)
- Dark mode support

**Phase 4 - Advanced Features (Week 6-8):**

- Offline map downloads (switch to offline routing engine)
- Multi-stop routes with waypoints
- Alternative transportation modes (walking, cycling)
- Share route with others (deep linking)

**Phase 5 - Community & Polish (Week 9-12):**

- Voice guidance (TTS integration)
- Accessibility improvements (screen reader support)
- Localization (i18n for multiple languages)
- Contribution guidelines for open-source community

## Unanswered Questions for Product Team

1. **GraphHopper API Key:** Who manages the free tier API key? What happens when 500 requests/day exceeded?
2. **Self-Hosting:** Should we self-host OSRM for better reliability and no rate limits?
3. **App Store Presence:** Should this be published under personal account or create organization account?
4. **Branding:** Is "NaviMap" final name? Need logo/icon design for app stores
5. **License Choice:** MIT (permissive) vs GPL v3 (copyleft) - which aligns with project goals?
6. **Support Strategy:** How to handle user support requests? GitHub issues only? Email?
7. **Privacy Policy Hosting:** Where to host the required privacy policy document?
8. **Monetization:** Will this remain 100% free forever? Donations? Sponsorships?

## Research Needed Before Production

**Legal/Compliance:**

- Review OpenStreetMap tile usage policy in detail (attribution requirements)
- Verify OSRM demo server is acceptable for production use or should self-host
- Confirm GraphHopper free tier terms of service
- App store content rating (ESRB, PEGI equivalent for navigation apps)

**Technical Validation:**

- Test OSRM reliability under load (response times, availability)
- Measure actual tile download sizes and data usage
- Validate GPS accuracy across different device models
- Test on low-end devices (e.g., Android 7.0 with 2GB RAM)

**Market Validation:**

- Survey potential users on feature priorities
- Analyze competitor apps (OsmAnd, MAPS.ME) for differentiation
- Determine if "simplicity" value prop resonates with target users

---
