# 0010. Mobile app: React Native with Expo and TypeScript

- Status: Accepted
- Date: 2026-11-12
- Pattern(s): — (technology choice); inside the app: container/presentational components, server-state cache

## Context
Aika asked for "the most popular stack, considered the best". In developer surveys the two leaders for cross-platform
mobile are **Flutter** and **React Native**, roughly on par; native Kotlin/Swift is used by large banks but means two apps.
The React Native docs recommend starting new apps with the Expo framework.

## Decision
- Expo (latest SDK), React Native, TypeScript strict, Expo Router (file-based navigation).
- Server state: TanStack Query over a client generated from `api/openapi.yaml`; WebSocket for market data.
- Local UI state: Zustand. Forms: React Hook Form + Zod.
- Styling: design tokens from `docs/design/tokens.json` (produced with Gemini, ADR pending) → a typed theme; light and dark.
- Charts: a maintained RN chart library (implementer picks and records why).
- Testing: Jest + React Native Testing Library; one Maestro E2E flow for the skeleton.
- Runs in Expo Go / development build on iOS and Android simulators and on a phone.

## Why this and not the alternatives
| Alternative | Why not (for us) |
|---|---|
| Flutter | Equally strong; but Dart is a third language next to Java and TS, and the web client would not share code |
| Native Kotlin + Swift | Two codebases for one learner |
| Kotlin/Compose Multiplatform | Closest to Aika's Java; iOS side less mature, smaller ecosystem for AI agents |

## Pros
- TypeScript shared with the web client (same generated API client, same domain types).
- Very fast iteration (hot reload, Expo Go on a real phone).
- Huge ecosystem; AI agents generate good React code.

## Risks and costs
- Performance of heavy, constantly updating views (order book at high rate) — throttle updates, memoised rows, measure.
- Library churn in the RN ecosystem — pin versions, use Expo-supported packages.

## How to explain it
"Cross-platform with React Native and Expo: one TypeScript codebase for iOS and Android that shares the API client with the web app.
Flutter would have been an equally valid choice; we picked RN to keep one language across the frontends."
