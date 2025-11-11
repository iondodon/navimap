# Introduction

This document outlines the complete architecture for **NaviMap**, a privacy-first, open-source mobile navigation application built with Flutter. NaviMap is designed for rapid MVP development (7-day timeline) with zero backend infrastructure - the application runs entirely on the client device and integrates with free open-source routing APIs (OSRM and GraphHopper).

Unlike traditional fullstack applications, NaviMap is a **mobile-first client application** that:

- Runs natively on Android (7.0+) and iOS (12.0+) via Flutter
- Uses OpenStreetMap for map rendering
- Calls external routing APIs for route calculations
- Stores zero persistent data (ephemeral state only)
- Requires no authentication, user accounts, or custom backend

This architecture serves as the definitive guide for AI-assisted development, ensuring consistency across all implementation phases while maintaining the radical simplicity demanded by the PRD.

## Starter Template or Existing Project

**N/A - Greenfield Flutter Project**

This is a greenfield project starting from `flutter create`. While Flutter provides starter templates, we're building from scratch to maintain minimal dependencies and full control over architecture decisions. The standard Flutter project structure will be adapted for our specific needs.

## Change Log

| Date       | Version | Description                   | Author              |
| ---------- | ------- | ----------------------------- | ------------------- |
| 2025-11-11 | 1.0     | Initial architecture document | Winston (Architect) |
