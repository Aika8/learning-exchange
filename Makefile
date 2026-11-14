.PHONY: test test-backend test-web test-mobile dev reset repl web mobile mobile-web gen-api e2e clean

# Run every test in the repo: backend (Gradle) and both clients (unit tests, i18n keys, type check).
test: test-backend test-web test-mobile

test-backend:
	./gradlew test

test-web:
	cd clients/web && npm test

test-mobile:
	cd clients/mobile && npm test

# Start the exchange with its bots: REST + WebSocket on http://localhost:8080 (journal in data/journal.jsonl).
dev:
	./gradlew --console=plain :backend:app:bootRun

# Forget the market: delete the journal so the next `make dev` starts from an empty exchange.
reset:
	rm -f data/journal.jsonl

# Order-book REPL from increment 1 (no accounts, no fees).
repl:
	./gradlew -q --console=plain :backend:repl:run

# Clients (run each in its own terminal while `make dev` is running).
web:
	cd clients/web && npm install && npm run dev

mobile:
	cd clients/mobile && npm install && npx expo start

mobile-web:
	cd clients/mobile && npm install && npx expo start --web

# Regenerate TypeScript API types from api/openapi.yaml in both clients.
gen-api:
	cd clients/web && npm run gen:api
	cd clients/mobile && npm run gen:api

# Web end-to-end test (Playwright); needs `make dev` running.
e2e:
	cd clients/web && npx playwright test

clean:
	./gradlew clean
