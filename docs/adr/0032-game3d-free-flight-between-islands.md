# 0032. The player flies the ship: free flight between all islands replaces the scripted voyage

- Status: Proposed
- Date: 2026-11-18
- Pattern(s): Pure model + thin scene (`FlightModel`, as `VoyageModel` before it), Registry (`Ports`), State machine unchanged (`GameFlow`)
- Supersedes: the voyage scene of ADR-0023 (decision "Sailing": a fixed route with Space for the sail) and the
  instant "packet boat" of ADR-0028, 0030 and 0031. The clock rule of ADR-0006/0023 (×60 at sea) stands.

## Context
Sailing was a ride: the ship followed one curve between Spark Harbour and Silk Reach and the player could only
raise or lower the sail. Three more islands were then reached by a fade ("packet boat"), with no voyage at all.
Aika wants the player to **fly the ship themselves and choose where to go**: all five islands in one sky, seen from
afar, each with a pier to moor at; steering, height, wind that matters; time passing while under way; the storm
and the Anchor as before; Mara's plan untouched; a simple chart and compass.

Forces:
- The day loop (`GameFlow`: Port → Plan → Trading → Sailing → Chronicle) and its guard — no leaving port with cargo
  and no Anchor — are tested invariants. Flight must be the same SAILING state, not a way round it.
- What the voyage teaches is that **the market does not wait**: the exchange clock runs ×60 while under way and a
  stop can fire at sea. That must survive a voyage whose length the player now decides.
- The storm was tied to "30–72 % of the route". A free flight has no route.
- The ship must not pass through islands or leave the world, and the rule must be testable without a 3D scene, as
  the route was (`VoyageModel` had GUT tests).
- Five islands are already built in every scene; the far ones as simple shapes. 60 fps.

## Decision
1. **`FlightModel`** (pure, `scripts/flight_model.gd`) replaces `VoyageModel`. State: position, heading, speed,
   sail trim. Inputs each step: rudder, trim change, climb, and the wind. Rules:
   - speed follows trim × base speed × a wind factor — 1.5 with the wind astern, 0.5 against it; with no sail the
     ship drifts at a quarter speed, as before;
   - height is kept between a floor above the cloud sea and a ceiling;
   - **islands are solid**: each is a cylinder (centre, radius, top, depth); the ship is pushed out along the
     shortest way and loses its speed into the rock. Above an island's top there is clearance to fly over;
   - **the world has an edge**: a circle round the archipelago. Near it the Current pushes back harder and harder;
     the ship cannot cross it;
   - **mooring**: within reach of a port's berth and slow enough, the ship can moor.
2. **`Ports`** (`scripts/ports.gd`) is the one table of islands as the ship sees them: id, name key, berth, the
   cylinder, the heading on leaving. A new island is a row.
3. **The voyage scene** keeps its job (clock ×60 on leaving, ×1 on mooring; day-log `VOYAGE_START` / `VOYAGE_END`;
   the Anchor watched every two seconds; rain, lightning) and becomes thin: read the keys, step the model, draw.
   Keys: W/S trim the sail, A/D the wheel, Space up, Shift down, E moor, mouse drag looks round.
4. **Where to.** At any pier, E at the ship opens a **chart**: the other islands with bearing and distance, and
   "fly free". Choosing only sets `Game.destination` (a mark for the compass); the player may moor anywhere.
   `GameFlow` is asked for SAILING exactly as before, so Mara's rule and the Anchor guard hold. The signposts on
   the Spark Harbour wharf stay as shortcuts that pick their island and cast off the same way.
5. **The storm** belongs to the first voyage of a day, as before, and now to distance flown: it begins after the
   ship has covered 30 % of the straight distance to its destination (120 m when flying free) and lasts for the
   next 42 %. In it the ship is slower and gusts push it sideways.
6. **HUD**: a compass strip with a mark for every island (the destination in brass, with its distance) and a small
   round chart: islands, the ship, the edge of the world.
7. **Arrival** is as it was: the port scene opens on the island moored at and the island's wind restyles the
   captain (ADR-0025, 0029).

## Why this and not the alternatives
| Alternative | Why not (now) |
|---|---|
| Keep the curve, add more curves between island pairs | Twenty routes, and still a ride; "choose where to fly" is the request |
| Physics body for the ship (rigid body, colliders from island meshes) | Not testable headless as simply; trimesh colliders for far islands; a cylinder per island is enough for a ship |
| An open world with no SAILING state (walk off the pier onto the ship in the same scene) | Breaks the day loop's tested guards and the ×60 clock boundary |
| A voyage of fixed duration whatever the player does | Then steering would not matter; and "time is the price of distance" is a finance lesson worth keeping honest |
| Keep the instant packet boat as well | Two ways to travel, one of which skips the clock and the Anchor |
| Auto-pilot to the chosen island | Possible later as a comfort; first the player must be able to fly |

## Pros
- One way to travel, through the same guarded state, for all islands; a sixth island is a row in `Ports`.
- The rules of flight (wind, edge, rock, mooring) are plain code under GUT.
- The lesson gets sharper: a longer way round costs exchange time, and the stop is out there working meanwhile.

## Risks and costs
- A player can now loiter at ×60 and burn a trading day, or never arrive. The clock is honest about it (the HUD
  shows exchange time passing); nothing stops them. We notice in play.
- A cylinder is not an island: the ship stops a little before a jagged cliff or slides past a bulge. Margins are
  set so it never enters rock.
- `--demo` (the M3 screenshot run) drove the old curve; its hooks are kept by placing the ship along the straight
  line to the destination, so the pictures of `docs/demo/M3.md` will differ.
- Far islands are still simple shapes until landed on; from the air the three newest look plain.
- The 2D game (`game/`) is not touched and keeps its own voyage.

## How to explain it (teaching note)
The scene changed completely and the state machine did not change at all: SAILING is still entered by one guarded
transition and left by one. That is what a state machine buys — the rule "no cargo without an Anchor" did not have
to be found again inside a new feature. And the model is still pure: wind, rock and the world's edge are
arithmetic on a few vectors, so they are tested without drawing anything.
