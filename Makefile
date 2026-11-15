.PHONY: test test-backend test-web test-mobile test-game test-game3d game game3d assets dev reset repl web mobile mobile-web gen-api e2e clean

# Run every test in the repo: backend (Gradle), both clients (unit tests, i18n keys, type check) and the game.
# Works in a clean clone: client dependencies are installed with `npm ci` first. Without Godot the game tests are
# skipped with a note (CI has no Godot). E2E is separate: `make e2e`.
test: test-backend test-web test-mobile test-game test-game3d

test-backend:
	./gradlew test

# `npm ci` runs when node_modules is missing or older than package-lock.json (always in a clean clone).
clients/%/node_modules/.ci-stamp: clients/%/package-lock.json
	cd clients/$* && npm ci
	touch $@

test-web: clients/web/node_modules/.ci-stamp
	cd clients/web && npm test

test-mobile: clients/mobile/node_modules/.ci-stamp
	cd clients/mobile && npm test

# Game: GUT unit tests headless (needs Godot 4 on PATH: `brew install --cask godot`).
test-game:
	@if command -v godot >/dev/null 2>&1; then \
		cd game && godot --headless --path . --import >/dev/null 2>&1; godot --headless --path . -s addons/gut/gut_cmdln.gd; \
	else \
		echo "test-game: skipped, godot is not on PATH (brew install --cask godot)"; \
	fi

# 3D game client (ADR-0017): GUT unit tests headless.
test-game3d:
	@if command -v godot >/dev/null 2>&1; then \
		cd game3d && godot --headless --path . --import >/dev/null 2>&1; godot --headless --path . -s addons/gut/gut_cmdln.gd; \
	else \
		echo "test-game3d: skipped, godot is not on PATH"; \
	fi

# Download the CC0 art of game3d (ADR-0019): game3d/assets.lock → game3d/assets/ (git-ignored), MD5-checked.
assets:
	game3d/tools/fetch_assets.sh

# Start the 3D game «Летопись Ветров» (run `make dev` and `make assets` first).
game3d:
	cd game3d && godot --headless --path . --import >/dev/null 2>&1; godot --path .

# Start the game «Летопись Ветров» (run `make dev` first).
game:
	cd game && godot --headless --path . --import >/dev/null 2>&1; godot --path .

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
