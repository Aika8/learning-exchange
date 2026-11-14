# api/

Contract first (ADR-0003). The contract changes here, in its own commit, before server or client code.

- `openapi.yaml` (OpenAPI 3.1) — REST commands and queries under `/api/v1`, plus the payload schemas of WebSocket messages
  (`Ws*Message`), so one generated client types both.
- `asyncapi.yaml` (AsyncAPI 3) — the WebSocket at `/ws`: channels `market.{id}.book`, `market.{id}.trades`, `clock`,
  `account.{accountId}`.

## Rules
- Money, prices, quantities: integers in minor units (int64). `Instrument.priceScale` says how many decimals to show.
- Errors: `Problem { code, message }`; clients translate `code`, never show `message` to users.
- Commands may carry `Idempotency-Key`; a repeated key returns the first result.

## Generated clients
- Web and mobile: `openapi-typescript` → `src/api/schema.d.ts` (`npm run gen:api` in each client), used with `openapi-fetch`.
- Server: hand-written Spring controllers checked by `ContractTest` (every response is validated against this file).
- Godot: plain `HTTPRequest` + `WebSocketPeer`; see "Using from another client" below.

## Using from another client (e.g. the Godot game)
1. `POST /api/v1/auth/dev-login {"name":"Captain"}` → `{token, account}`.
2. Send `Authorization: Bearer <token>` on `/me`, `/orders`, `/me/deposits`, `PUT /clock`.
3. Open `ws://localhost:8080/ws?token=<token>` and send
   `{"op":"subscribe","channel":"market.SILK-SPARK.book"}` (and `.trades`, `clock`, `account.<accountId>`).
   The first message on each channel is a snapshot; later ones are updates.
4. Show prices as `price / 10^priceScale` of the quote asset; never use floats to compute money.

Lint: `npx @redocly/cli lint api/openapi.yaml`, `npx @asyncapi/cli validate api/asyncapi.yaml`.
