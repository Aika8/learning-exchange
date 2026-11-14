# clients/web — debug client

React 19 + Vite 8 + TypeScript + TanStack Query. Thin, for developers and demos.

- Run: `npm install && npm run dev` → http://localhost:5173 (backend: `make dev`). Backend URL: `VITE_API_URL` (`.env.example`).
- Screen: ladder (order book), trades tape, order form (limit/market, fee estimate), my orders with cancel, balances,
  simulation clock (pause/speed), ru/en switch.
- API types: `src/api/schema.d.ts` is generated from `api/openapi.yaml` (`npm run gen:api`); never edit it.
- Tests: `npm test` (vitest: money, i18n keys; then `tsc`), `npx playwright test` (E2E against the running backend;
  first time: `npx playwright install chromium`).
