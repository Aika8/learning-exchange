# Mobile design «Ветрило»

Claude Design canvas: https://claude.ai/artifact/ErJSxuvqL1oYrAacmJUVA9 (private; share from the page's Share menu).

Source prompt: `docs/prompts/claude-design-mobile.md`. Tokens: `tokens.json`. Artboard sources (`.dc.html`) and the canvas index: `canvas/`.

## What is on the canvas
- **Part 1 · Design system** — brand lockup (sail symbol), tone of voice, light/dark palettes, type scale (Golos Text + Inter tabular figures), components with states: buttons, amount field, segmented control, chips incl. «учебные деньги» and term chip, order book row with depth bars, spread indicator, balance card, operation row, tab bar, toast, empty state, bottom sheet.
- **Screens 1–4** (Home, Exchange, Instrument + order book, Order ticket): RU light · RU dark · EN light.
- **Screens 5–17**: RU light — Orders & stops, Leverage ×4, Deposit, Statement, Assistant, Glossary, Settings (RU/EN switch), Onboarding ×3, Real world, Company, Economic calendar, Bond, Fund, Order ticket (ATR stop + journal).

## Rules kept
Plain learning bank, no game words or motifs; original palette (deep blue-teal + amber, no real bank look); practice money only (UKZT/UUSD, «учебные деньги» badge); gains/losses carry sign and arrow; bid/ask differ in colour and ▲/▼; «Это не инвестиционный совет»; no buy/sell recommendations.

## Not done yet
- PNG per screen (`screens/`): export from the canvas (Share › Export) — not automated here.
- EN copy for screens 5–17 is not drawn; add EN variants when the RN client's i18n starts.
- Real-world rates show `[КУРС]` placeholders; the client fills them from the source with timestamp.
