# clients/mobile — «Ветрило»

Expo SDK 58 + React Native + TypeScript strict (ADR-0010). A plain learning bank and broker: real finance terms only,
it knows nothing about the game. Design: `docs/design/` (tokens copied to `src/theme/tokens.json`, a test keeps them equal).

## Run
1. Backend: `make dev` at the repo root (http://localhost:8080).
2. Here: `npm install`, then
   - iOS simulator: `npx expo start --ios` (needs Xcode; the simulator reaches the backend at `localhost`);
   - Android emulator: set `EXPO_PUBLIC_API_URL=http://10.0.2.2:8080`, then `npx expo start --android`;
   - phone with Expo Go: `EXPO_PUBLIC_API_URL=http://<your-mac-ip>:8080 npx expo start`;
   - browser (react-native-web): `npx expo start --web` → http://localhost:8081.

## Screens (M1)
`src/app/`: `login` (dev login by name, language switch), `home` (S01: cash balance, accounts), `instrument`
(S03 + S04: last price, order book with spread, my open orders, trades tape, Buy/Sell → order ticket with fee and total),
`settings` (S10b: ru/en switch, log out).

## Screens (M2a, M2b)
- `fx` (currency exchange), `deposits` (savings, rule of 72), `statement`; Invest tab now lists every instrument from
  `GET /instruments` with real names from `/bff/mobile/catalogue`, shows «Торги остановлены» when `tradingOpen` is false,
  and links a STOCK to its company card and a BOND to its bond screen.
- `company?id=…` — company card from `/bff/mobile/companies/{id}`: key metrics (price, EPS TTM, P/E, debt/profit,
  dividend yield), last report vs consensus with surprise, earnings calendar and past reports, dividends, insider trades,
  a candle chart from `/instruments/{id}/candles` drawn with Views (no chart library) with dividend ex-dates marked,
  and the red «Отчёт сегодня ночью — риск гэпа для твоего стопа» banner when the BFF sends `gapWarning`.
- `calendar` (from «Ещё») — central bank (policy, inflation, real and deposit rates, next decision and consensus, regime)
  and the economic calendar with done/scheduled and consensus vs actual.
- `bonds` and `bonds?id=…` (from «Ещё» or the Invest tab) — YTM always shown, modified duration, coupons, rating, status.
- `real` (tab «Реальный мир») — real quotes with source, time and a «образец данных» badge, base rate with decisions,
  paper («учебные») positions: open (with `Idempotency-Key`) and close, P&L.
- Pure helpers in `src/m2b.ts` (gap-warning rule, chart scaling, ×100 ratios, idempotency keys), tested in `test/m2b.test.mjs`.
  POSTs that create something (orders, stops, deposits, paper positions) send an `Idempotency-Key`.

## Code map
- `src/api/schema.d.ts` — generated from `api/openapi.yaml` (`npm run gen:api`); never edit.
- `src/api/client.ts` (openapi-fetch + bearer token), `src/api/socket.ts` (WebSocket channels, auto-resubscribe).
- `src/store/session.ts` — Zustand (token, language), persisted in AsyncStorage.
- `src/i18n/{ru,en}.json` — every UI string; `src/money.ts` — integer minor units, no floats.
- `src/config.ts` + `app.json` — product name, bundle ids and API URL in one place.

## Tests
- `npm test`: i18n keys equal in ru/en and every `t('…')` key exists; tokens equal the design file; `money.ts` equals the
  web client's; M2b helpers (`test/m2b.test.mjs`); `tsc --noEmit`.
- E2E: `.maestro/skeleton.yaml` (Maestro) — written, not yet run in CI (needs a simulator and Maestro installed).
