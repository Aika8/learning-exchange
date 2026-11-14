# 0014. Russian and English from day one, switchable at runtime

- Status: Accepted
- Date: 2026-11-12
- Pattern(s): Message catalogue / Externalised strings, Observer (locale change notifies UI), Fallback locale

## Context
Aika wants both Russian and English immediately, switchable in settings without restart, in the game and the apps.
Retrofitting i18n later means touching every screen.

## Decision
- No user-visible string literals in UI code: keys only. Lint/test fails on hard-coded strings in screens.
- Mobile + web: `i18next` + `react-i18next`, device locale via `expo-localization` as the initial value, user choice persisted.
- Game: Godot `TranslationServer` with CSV (or PO) catalogues; changing locale emits a signal and scenes re-read texts.
- Backend: returns codes and data, not sentences — except assistant texts, generated in the requested locale (`Accept-Language`).
  Glossary and catalogue names carry `ru` and `en`.
- Fallback locale: `ru`; a test checks that every key exists in both locales.
- Numbers and dates via locale formatters (`Intl.NumberFormat`, Godot helpers); money stays integer minor units underneath.

## Why this and not the alternatives
| Alternative | Why not |
|---|---|
| Russian first, English later | Every screen touched twice; layout breaks found late |
| Server-rendered texts for everything | Clients can't switch instantly or work offline |

## Pros
- Instant switch; layouts tested with both lengths from the start.
- Same discipline everywhere — one more pattern to recognise.

## Risks and costs
- Slower first screens (keys instead of text). Mitigation: write `ru` and `en` together in the same commit.
- Translation quality of game lore — Aika reviews ru, English reviewed separately before release.

## How to explain it
"Texts live in message catalogues, the UI only knows keys. Switching language is an event that UI components observe."
