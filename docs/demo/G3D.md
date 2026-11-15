# G3D demo — «Летопись Ветров» in 3D (`game3d/`)

Second game client, same world and genre, stylised low-poly with soft toon light (ADR-0017, `docs/design/game3d-style.md`).
Everything you see is generated in code; no imported art (`game3d/ASSETS.md`).

## Run
```
make dev            # exchange + bots on :8080
make game3d         # opens the 3D client
```
Another port: `cd game3d && godot --path . -- --server=http://localhost:8090`. `F3` shows fps.

Self-run demo that produced the screenshots below (Apple M5, 1920×1080, Forward+/Metal, 97–120 fps in every scene):
```
cd game3d && godot --path . --resolution 1920x1080 -- --server=http://localhost:8090 --demo=../docs/demo/g3d
```

## 1. Main menu over the live archipelago — ru/en on the fly
![menu ru](g3d/1-menu-ru.jpg)
![menu en](g3d/2-menu-en.jpg)

## 2. Spark Harbour — walk the captain (WASD + mouse), talk to Mara (E), fly the camera (Tab)
![walk](g3d/3-harbour-walk.jpg)
![mara](g3d/4-harbour-mara.jpg)
![fly](g3d/5-harbour-fly.jpg)

## 3. Exchange hall — the live order book on a 3D board (WebSocket), limit and market orders
Real terms lead (order book, spread, limit/market order), lore names are small captions (the Ladder, the Chasm, step onto a rung, leap over the Chasm).
![board](g3d/6-hall-board.jpg)
Limit buy below the best bid — stays in the book as `New`, funds go to "in orders":
![limit](g3d/7-hall-limit.jpg)
Market buy of 2 — `Filled 2 of 2`; English switched on the fly:
![market](g3d/8-hall-market-en.jpg)

## 4. Voyage to Silk Reach — the exchange clock runs (GET /clock + `clock` channel), the market keeps trading
![departure](g3d/9-voyage-departure.jpg)
![open sky](g3d/10-voyage-open-sky.jpg)
![arrival](g3d/11-voyage-silk-reach.jpg)

## Tests
`make test-game3d` — 21 GUT tests headless: sim clock, voyage route and wind, board layout, the 3D stream's clock
extension, procedural meshes, i18n (every key in ru and en, every key used in code exists, contract codes translated).
