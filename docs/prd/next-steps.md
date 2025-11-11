# Next Steps

## UX Expert Prompt

**Objective:** Create minimal wireframes or design guidance for the NaviMap single-screen map interface.

**Context:** NaviMap is a single-screen mobile navigation app with extreme minimalism (no UI chrome). Review the PRD sections: Goals, UI Design Goals, and Epic structure. Focus on visual hierarchy, marker design, route polyline styling, and error toast positioning.

**Deliverable:** Simple wireframe or design specifications for:
- Current location marker (blue dot with accuracy circle)
- Destination pin (red marker icon)
- Route polyline (color, width, opacity recommendations)
- Toast message positioning and styling
- Loading indicators

**Note:** This is optional for MVP development but would help architect visualize the design intent.

---

## Architect Prompt

**Objective:** Create the technical architecture document (`docs/architecture.md`) for NaviMap based on this PRD.

**Context:** You are designing the architecture for a Flutter-based mobile navigation MVP with a 7-day development timeline. The application must be simple, performant, and use 100% open-source technologies with zero backend infrastructure.

**Key Inputs:**
- Review `docs/prd.md` (this document) completely
- Review `docs/brief.md` for additional context
- Focus on Technical Assumptions section for constraints
- Study Epic and Story structure for implementation sequence

**Your Architecture Must Address:**

1. **Application Structure:**
   - Flutter project organization (lib/ structure)
   - Widget tree architecture for single-screen app
   - State management implementation (Provider pattern)
   - Service layer design (LocationService, RoutingService)

2. **External Integrations:**
   - OSRM/GraphHopper API integration patterns
   - OpenStreetMap tile loading and caching strategy
   - GPS/location service integration (geolocator)
   - Error handling and fallback mechanisms

3. **Data Flow:**
   - Location updates → UI rendering pipeline
   - Destination tap → route calculation → polyline display
   - State management flow diagrams
   - Event handling architecture

4. **Performance Optimization:**
   - Map tile caching strategy (50MB limit)
   - Polyline rendering optimization
   - Memory management approach
   - 60fps interaction targets

5. **Platform-Specific Considerations:**
   - Android permissions implementation
   - iOS permissions implementation
   - Cross-platform testing strategy
   - Build configuration (API levels, deployment targets)

6. **Code Organization:**
   - Package structure by feature
   - Naming conventions
   - Separation of concerns (UI vs business logic)
   - Testing approach (unit tests for critical paths)

7. **Technical Decisions Rationale:**
   - Why Provider over other state management
   - Why OSRM primary with GraphHopper fallback
   - Why no backend/database
   - Why single-screen architecture

**Deliverables:**
- `docs/architecture.md` with complete technical design
- Architecture diagrams (component, data flow, state management)
- Package structure specification
- API integration patterns
- Error handling strategy
- Performance optimization plan

**Success Criteria:**
- Architecture enables Epic 1-3 story implementation
- Meets all NFRs (performance, security, size constraints)
- Clear enough for AI agent to implement stories independently
- Addresses all technical risks identified in PRD checklist

**Timeline:** Architecture document should be completed before development begins (Day 1 of sprint).

---

**PRD Status:** ✅ Complete and Validated  
**Next Agent:** @architect  
**Action Required:** Create architecture.md

