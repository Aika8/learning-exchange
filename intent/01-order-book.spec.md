# Spec: in-memory order book and matching engine
Increment 01. Derived from `intent/01-order-book.md`. Status: draft for review.

This document is written for an engineer who has not seen the discussion that
produced it. Everything normative is in sections 1–8. Section 9 lists every
place where the intent was ambiguous and a decision had to be made; each such
decision is marked **[D-n]** in the body so it can be traced and overturned.

---

## 1. Scope

Build one Java class library: a matching engine for **a single instrument**,
held entirely in memory.

In scope:

- Limit and market orders, buy and sell.
- Price-time priority.
- Partial fills.
- Cancel by order id.
- A read-only view of the book.

Out of scope (restated from the intent, and binding on this increment):
accounts, positions, money, bots, REST/HTTP, persistence or journalling,
multiple instruments, news, the assistant, any UI, threading.

The deliverable is a library with no `main`, no I/O, and no dependencies
other than the test framework.

---

## 2. Domain model and units

### 2.1 Price

Price is a **`long`, expressed in whole ticks** — an integer count of the
instrument's minimum price increment. One tick is defined by convention as
one cent; the engine itself never interprets the unit. **[D-1]**

There is no floating point anywhere in the engine. Any valid price is a
`long` strictly greater than zero. There is no tick-size validation, no price
band, and no maximum price in this increment. **[D-2]**

### 2.2 Quantity

Quantity is a **`long`, in whole units** (shares). Any valid quantity is
strictly greater than zero. A maximum of `1_000_000_000` units per order is
enforced so that aggregate level quantities cannot overflow a `long` under
any realistic sequence of orders. **[D-3]**

### 2.3 Identity and sequence

The engine owns identity. The caller never supplies an order id. **[D-4]**

- Order ids are `long`, start at 1, and increase by exactly 1 per accepted
  order (rejected orders do not consume an id).
- Trade ids are `long`, start at 1, and increase by exactly 1 per trade.
- Order id **is** the arrival sequence number and is what establishes time
  priority. There is no wall-clock timestamp anywhere in the engine; this is
  what makes the engine deterministic and replayable. **[D-5]**

---

## 3. Public API

Package `engine`. Everything below is public; everything not listed is
package-private or private. All value types are immutable Java records with
validated constructors; all collections returned are unmodifiable.

### 3.1 Enums

```
enum Side { BUY, SELL }

enum OrderType { LIMIT, MARKET }

enum OrderStatus {
    RESTING,           // no quantity filled, remainder is in the book
    PARTIALLY_FILLED,  // some quantity filled; see restingQuantity for where the rest went
    FILLED,            // fully filled, nothing left
    CANCELLED,         // nothing resting, remainder withdrawn (market order with no liquidity, or an explicit cancel)
    REJECTED           // not accepted; no id consumed, book unchanged
}

enum RejectReason {
    NONE,
    NON_POSITIVE_QUANTITY,
    QUANTITY_ABOVE_LIMIT,
    NON_POSITIVE_PRICE
}

enum CancelOutcome {
    CANCELLED,       // the order was resting and is now removed
    UNKNOWN_ORDER,   // no order was ever issued that id
    NOT_RESTING      // the id is known but the order is already filled or cancelled
}
```

### 3.2 Requests

```
record OrderRequest(OrderType type, Side side, long price, long quantity) {
    static OrderRequest limit(Side side, long price, long quantity);
    static OrderRequest market(Side side, long quantity);   // price is 0 and MUST be ignored
}
```

The two factories are the only intended construction path. A market order
carries no price; the `price` component is 0 and carries no meaning. **[D-6]**

### 3.3 Results

```
record Trade(
    long tradeId,
    long price,              // always the resting order's limit price
    long quantity,
    long restingOrderId,
    long aggressingOrderId,
    Side aggressorSide)

record OrderResult(
    long orderId,            // 0 when status == REJECTED
    OrderStatus status,
    long filledQuantity,
    long restingQuantity,
    long cancelledQuantity,
    List<Trade> trades,      // in execution order; empty, never null
    RejectReason rejectReason)   // NONE unless status == REJECTED

record CancelResult(
    CancelOutcome outcome,
    long cancelledQuantity)  // 0 unless outcome == CANCELLED
```

For every accepted order:
`filledQuantity + restingQuantity + cancelledQuantity == request.quantity()`.

`status` is a derived convenience and must be consistent with the three
quantities:

| filled | resting | cancelled | status |
|---|---|---|---|
| 0 | > 0 | 0 | `RESTING` |
| 0 | 0 | > 0 | `CANCELLED` |
| > 0 | > 0 | 0 | `PARTIALLY_FILLED` |
| > 0 | 0 | > 0 | `PARTIALLY_FILLED` |
| > 0 | 0 | 0 | `FILLED` |

### 3.4 Book view

```
record PriceLevel(long price, long quantity, int orderCount)

record BookSnapshot(List<PriceLevel> bids, List<PriceLevel> asks) {
    Optional<Long> bestBid();
    Optional<Long> bestAsk();
}
```

`bids` are ordered by price **descending**, `asks` **ascending**. The full
depth of the book is returned — there is no top-N truncation. **[D-7]**
A snapshot is a detached copy: later engine mutations never change a
snapshot already handed out.

### 3.5 The engine

```
final class MatchingEngine {
    MatchingEngine();
    OrderResult submit(OrderRequest request);
    CancelResult cancel(long orderId);
    BookSnapshot snapshot();
}
```

That is the entire surface. Three methods.

`MatchingEngine` is **not thread-safe** and makes no attempt to be. It is
documented as single-threaded, caller-confined. See §9.12.

### 3.6 Error policy

Two distinct channels, and they must not be mixed. **[D-8]**

- **Programmer errors** throw unchecked exceptions immediately:
  `null` for `request`, `type`, or `side` throws `NullPointerException`.
- **Business rejections** never throw. They come back as an `OrderResult`
  with `status == REJECTED` and a `rejectReason`. Non-positive quantity,
  quantity above the limit, and non-positive price on a limit order are
  rejections, not exceptions.

A rejection leaves the book bit-for-bit unchanged and does not consume an
order id.

---

## 4. Behavioural rules

### 4.1 Matching, common to both order types

An incoming order is the **aggressor**. Orders already in the book are
**resting**. Matching happens synchronously inside `submit`, before it
returns, and runs to completion: `submit` either exhausts the aggressor's
quantity or exhausts the eligible liquidity.

Selection of the next resting order to match against:

1. **Price priority.** For a buy aggressor, the lowest-priced ask; for a
   sell aggressor, the highest-priced bid.
2. **Time priority.** Within one price level, the resting order with the
   lowest order id — the one that arrived first.

Each match produces exactly one `Trade` with
`quantity = min(aggressorRemaining, restingRemaining)`.

**The trade price is always the resting order's price.** The aggressor
therefore receives any price improvement: a buy limit at 12 hitting a resting
ask at 10 trades at 10. This is the rule stated in the intent and it has no
exceptions.

Trades appear in `OrderResult.trades` in the order they executed.

### 4.2 Limit orders

1. Validate. Reject on non-positive price or invalid quantity.
2. Match while the opposite side has liquidity **and** the price crosses:
   - BUY: while `bestAsk <= limitPrice`.
   - SELL: while `bestBid >= limitPrice`.
   An equal price crosses — a buy at 10 matches a resting ask at 10.
3. Any quantity left after matching **rests** in the book at the order's own
   limit price, at the **back** of the queue for that price level.
4. A limit order that never crosses simply rests; that is not an error.

### 4.3 Market orders

1. Validate quantity. Price is not validated and not used.
2. Match against the opposite side, sweeping price levels from best to
   worst, with no price bound at all. A market order will walk the entire
   book if it is large enough. There is no slippage protection in this
   increment. **[D-9]** — see §9.4.
3. **A market order never rests.** Any quantity left unfilled when the
   opposite side is exhausted is *cancelled*, and is reported in
   `cancelledQuantity`.
4. A market order against an empty opposite side is **accepted**, produces
   no trades, and returns `status == CANCELLED` with the full quantity
   cancelled. It is not a rejection: "there was nobody to trade with" is a
   market outcome the learner needs to see, not an input error. **[D-10]**

### 4.4 Partial fills and time priority

A resting order that is partially filled **keeps its position**: its id does
not change, it stays at the head of its queue, and its remaining quantity is
reduced in place. Partial execution never costs an order its priority.

A resting order whose quantity reaches zero is removed from the book. A price
level with no orders left is removed from the book entirely and does not
appear in a snapshot.

### 4.5 Cancel

`cancel(orderId)`:

- If the order is resting: it is removed, `CANCELLED` is returned together
  with the quantity that was still resting. If it had been partially filled,
  only the remainder is cancelled — fills are never undone.
- If the id was never issued: `UNKNOWN_ORDER`.
- If the order is known but already filled, already cancelled, or was a
  market order (which never rests): `NOT_RESTING`.

Cancel never throws for an unknown id. A cancelled order can never match
again. Cancelling an order from the middle of a queue does not disturb the
relative priority of the orders around it.

The engine retains the terminal state of every order id it has issued, so it
can distinguish `UNKNOWN_ORDER` from `NOT_RESTING` for the lifetime of the
engine instance. **[D-11]**

---

## 5. Invariants of the book

These hold after **every** completed call to `submit` and `cancel`, and are
the standing assertions the test suite should lean on.

1. **Never crossed, never locked.** If both sides are non-empty then
   `bestBid < bestAsk`. Strictly less — equality is impossible, because an
   order at an equal price would have matched.
2. **Bid ordering.** Bid price levels are strictly descending; ask price
   levels are strictly ascending. No price appears twice on a side.
3. **No empty artefacts.** Every resting order has quantity > 0. Every price
   level has quantity > 0 and `orderCount >= 1`. Levels that empty out are
   removed.
4. **Level aggregation is exact.** A level's `quantity` equals the sum of the
   remaining quantities of its orders, and `orderCount` equals their count.
5. **Quantity conservation, per order.**
   `filled + resting + cancelled == submitted`, for every order, for the
   lifetime of that order.
6. **Quantity conservation, globally.** The sum of all trade quantities
   attributable to buy aggressors equals that for sell aggressors — every
   trade has exactly one buyer and one seller.
7. **Trade price is a resting price.** Every trade's price equals the limit
   price of its `restingOrderId`, which was in the book before the aggressor
   arrived.
8. **Trade price respects the aggressor's limit.** For a buy limit
   aggressor, `trade.price <= aggressorLimitPrice`; for a sell limit
   aggressor, `trade.price >= aggressorLimitPrice`. No bound for market
   aggressors.
9. **No market order rests.** No order with `OrderType.MARKET` ever appears
   in a snapshot.
10. **Ids are unique and monotonic.** Order ids and trade ids each increase
    strictly by 1 and are never reused.
11. **Price-time priority is honoured.** If two orders rest on the same side
    and order A has a better price than B, or the same price and a lower id,
    then A fills before B — always.
12. **Determinism.** Two fresh engines given the same sequence of calls
    return equal results and produce equal snapshots. There is no clock, no
    randomness, no reliance on hash iteration order.
13. **Snapshot isolation.** A `BookSnapshot` never changes after it is
    returned.
14. **Rejections are inert.** A rejected order changes nothing: not the book,
    not the id counter.

---

## 6. Test scenarios

Written as behaviour to prove, not as code. Each line is at least one JUnit 5
test. The suite lives in `src/test/java/engine/` and is written by Aika.

### 6.1 Empty book

1. A limit buy into an empty book produces no trades, returns `RESTING`, and
   appears in the snapshot at its own price.
2. A limit sell into an empty book behaves symmetrically.
3. A market buy into an empty book returns `CANCELLED`, no trades, full
   quantity cancelled, and leaves the book empty.
4. A market sell into an empty book behaves symmetrically.

### 6.2 Simple matching

5. Resting sell 100@10; buy limit 100@10 → one trade, 100@10, both sides of
   the book now empty, buyer `FILLED`.
6. Price improvement: resting sell 100@10; buy limit 100@**12** → one trade
   at **10**, not 12. The aggressor keeps the improvement.
7. Price improvement, other direction: resting buy 100@12; sell limit 100@10
   → one trade at **12**.
8. No cross: resting sell 100@11; buy limit 100@10 → no trades, both rest,
   `bestBid == 10`, `bestAsk == 11`.
9. Equal prices cross: resting sell @10, buy @10 → they trade.

### 6.3 Partial fills

10. Resting sell 50@10; buy limit 100@10 → trade of 50; 50 rests as a bid at
    10; result is `PARTIALLY_FILLED` with `restingQuantity == 50`.
11. Resting sell 100@10; buy limit 40@10 → trade of 40; the sell remains in
    the book with quantity 60; buyer `FILLED`, nothing rests for the buyer.
12. An aggressor that fills against several resting orders at the same price
    returns several trades, in time order.

### 6.4 Price priority

13. Asks 100@10 and 100@11; market buy 150 → trade 100@10 then trade 50@11,
    in that order. The 10 level is gone; the 11 level has 50 left.
14. Bids 100@10 and 100@9; market sell 150 → trade 100@10 then 50@9.
15. A limit buy at 10 against asks at 10 and 11 touches only the 10 level and
    rests the remainder at 10.

### 6.5 Time priority

16. Two sells, both 100@10, submitted A then B; buy 100 → A fills entirely,
    B is untouched.
17. Priority survives a partial fill: sells A(100@10) then B(100@10); buy 50
    fills A to 50 remaining; a second buy 50 fills **A's remainder**, not B.
18. A later order at a better price beats an earlier order at a worse price.

### 6.6 Market orders

19. A market buy larger than the whole ask side fills everything available,
    reports the shortfall as `cancelledQuantity`, and leaves the ask side
    empty.
20. A market order never appears in the snapshot, in any circumstance,
    including when partially filled.
21. A market order sweeps multiple levels in correct price order (covered by
    13/14, asserted here on the returned trade list specifically).

### 6.7 Cancel

22. Cancel a resting order → `CANCELLED` with its resting quantity; it
    disappears from the snapshot.
23. Cancel an unknown id → `UNKNOWN_ORDER`, book unchanged, no exception.
24. Cancel a fully filled order → `NOT_RESTING`.
25. Cancel the same order twice → `CANCELLED` then `NOT_RESTING`.
26. Cancel a partially filled resting order → cancels only the remainder;
    the earlier trade is untouched.
27. Cancel a market order's id → `NOT_RESTING`.
28. A cancelled order does not match an order that arrives afterwards.
29. Cancelling the middle order of a three-deep queue leaves the other two in
    their original relative order.
30. Cancelling the last order at a price level removes the level from the
    snapshot.

### 6.8 Validation

31. Quantity 0 → `REJECTED` / `NON_POSITIVE_QUANTITY`, for limit and market.
32. Negative quantity → `REJECTED` / `NON_POSITIVE_QUANTITY`.
33. Quantity above the per-order limit → `REJECTED` / `QUANTITY_ABOVE_LIMIT`.
34. Limit order with price 0 or negative → `REJECTED` / `NON_POSITIVE_PRICE`.
35. A rejected order consumes no order id: the next accepted order gets the
    id the rejected one would have had.
36. `null` request, side, or type → `NullPointerException`.

### 6.9 Book integrity

37. After a scripted sequence of ~50 mixed operations, the book is never
    crossed, at any intermediate step.
38. After the same sequence, per-order quantity conservation holds for every
    id issued.
39. Level aggregates equal the sum of their orders at every step.
40. A `BookSnapshot` taken before further orders is unchanged afterwards.

### 6.10 Determinism

41. The same command sequence replayed on two fresh engines yields equal
    trade lists (ids included) and equal final snapshots.

### 6.11 The concurrency question

The intent asks for a test that proves the race before the protection is
chosen. Concretely:

42. A test that drives `submit` from several threads against one engine and
    asserts a *conservation* invariant afterwards — total filled quantity
    versus total resting quantity. Under a data race this fails or the engine
    corrupts its own structures; single-threaded it always passes.

This test is expected to be **non-deterministic by construction** and must
not sit in the default build. Tag it (`@Tag("race")`) and exclude that tag
from the normal `test` task, with a separate opt-in task to run it. See
§9.12 — this test documents a problem; it does not gate the build.

---

## 7. Project skeleton

```
learning-exchange/
├── settings.gradle.kts
├── build.gradle.kts
├── gradle/
│   ├── libs.versions.toml
│   └── wrapper/
│       ├── gradle-wrapper.jar
│       └── gradle-wrapper.properties
├── gradlew
├── gradlew.bat
├── src/
│   ├── main/java/engine/        ← written by Aika, agents do not touch
│   └── test/java/engine/        ← written by Aika, agents do not touch
├── intent/
│   ├── 01-order-book.md
│   └── 01-order-book.spec.md
└── .github/workflows/ci.yml
```

The Gradle wrapper is committed, including the jar — that is what makes the
build reproducible on a machine with no Gradle installed.

### 7.1 Build configuration (normative, not implementation)

- Gradle **9.1 or newer**. Older 9.x releases do not accept a Java 25
  toolchain. See §9.14.
- Plugin: `java-library`. No application plugin — there is no `main`.
- Java toolchain pinned to **release 25**, so the build compiles against 25
  regardless of the JDK running Gradle.
- `--enable-preview` is **not** used. The engine must compile on a stock
  Java 25 release. **[D-12]**
- Compiler args: `-Xlint:all` and `-Werror`. This is a learning project;
  warnings should not be allowed to accumulate.
- Test framework: JUnit Jupiter 5.11+, via Gradle's JVM Test Suite
  (`testing.suites.test.useJUnitJupiter(...)`). AssertJ is permitted for
  readable assertions; nothing else. **[D-13]**
- The default `test` task excludes the `race` tag. A second task,
  `raceTest`, includes only it and is not part of `check`.
- Dependency versions live in `gradle/libs.versions.toml`, not inline.

### 7.2 CI

One GitHub Actions workflow, `.github/workflows/ci.yml`:

- Triggers: `push` to `main`, and `pull_request` targeting `main`.
- Single job on `ubuntu-latest`.
- Steps: checkout → set up a Temurin JDK 25 → set up Gradle with caching →
  `./gradlew build --no-daemon`.
- The build fails the job on any test failure or any compiler warning.
- The `race` test is **not** run in CI — it is non-deterministic and would
  produce flaky red builds.
- No publishing, no release, no coverage gate in this increment. **[D-14]**

### 7.3 Definition of done

- All scenarios in §6 pass, excluding §6.11.
- Invariants in §5 hold, with at least the crossed-book and conservation
  invariants asserted by an actual test helper rather than by inspection.
- `./gradlew build` is green from a clean clone on a machine with no Gradle
  installed.
- CI is green on `main`.
- No dependency outside JUnit and AssertJ. No `main`. No I/O.

---

## 8. Explicitly deferred

Named here so they are not mistaken for oversights: accounts and balances,
positions and P&L, fees, the journal and replay (increment 02), an order
event stream for bots and the assistant, self-trade prevention, multiple
instruments, order modification (amend/replace), time-in-force flags
(IOC, FOK, GTD), stop and iceberg orders, auctions and opening crosses,
market data feeds, and any form of API.

---

## 9. Areas of concern and ambiguity

Every item here is a place where the intent did not decide, and a decision
was made in order to produce an implementable spec. Each can be reversed;
most are cheap to reverse now and expensive later.

**9.1 Price representation [D-1, D-2].** The intent says "no money", so no
currency type was introduced. `long` ticks is the standard choice and it
keeps the engine deterministic — but it pushes the question of what a tick
*means* onto every future consumer, and the display layer will eventually
need to know. The alternative, `BigDecimal`, is slower, allows `10.0` and
`10.00` to be different keys unless normalised, and invites floating-point
creep. **Decision: `long` ticks. Concern: the tick-to-display mapping is
undefined and will have to be decided before any UI exists.**

**9.2 No tick size or price bands.** Any positive `long` is a valid price, so
a learner can place a bid at 1 or at 10 billion. Realistic exchanges reject
both. This will make bot behaviour and the book display strange until bands
are added. **Deliberately deferred, but it will be felt early.**

**9.3 Quantity ceiling [D-3].** The `1_000_000_000` cap is arbitrary. It
exists only to make `long` overflow of level aggregates impossible. If it is
ever raised, the overflow analysis must be redone.

**9.4 Market orders have no price protection [D-9].** A market buy for a
large quantity into a thin book will sweep every ask level, however absurd
the price. That is genuinely how an unprotected market order behaves, and
given this product exists to make consequences visible, it is arguably the
*right* behaviour to show a learner. But it is also the single most likely
source of "the simulator is broken" complaints. **Flagged as a product
decision, not a technical one. If a slippage bound is wanted, it changes the
API (`marketWithProtection`) and belongs in this increment, not a later
one.**

**9.5 Empty-book market order: cancel, not reject [D-10].** Chosen so the
learner sees a market outcome rather than an input error. A real venue would
more often reject. If the assistant is later expected to explain "your order
was rejected", this choice changes the explanation. **Cheap to reverse now.**

**9.6 Self-trading is possible and unpreventable.** With no accounts, the
engine cannot know that two orders belong to the same participant. Once bots
and a user account exist, a user *will* trade with themselves and it will
look like a bug. **This is a known, accepted consequence of the increment
boundary. It should be resolved in the increment that introduces accounts,
and that increment will need to touch the engine's matching loop — the one
place the intent says agents must not edit.**

**9.7 Order ids are engine-generated [D-4].** This makes the engine the
single source of sequence, which is what §5.12 determinism rests on. The
cost: a future REST layer cannot let a client supply an idempotency key
without a second mapping table. **Worth being aware of before the REST
increment.**

**9.8 Order id doubles as the time-priority sequence [D-5].** Elegant and
deterministic, but it welds two concepts together. If cancel/replace is ever
added with "replace keeps priority" semantics, or if the journal in
increment 02 wants its own sequence, this will need separating. **Consider
exposing an explicit sequence number now — the journal is the very next
increment and this is the obvious place it will pull.**

**9.9 Trades are only returned, not published.** `OrderResult.trades` is the
sole way to observe an execution. Bots and the assistant will both want to
observe trades they did not cause. A listener or event log is the natural
answer and it is out of scope here. **The risk is that adding it later
changes the shape of `submit`. An alternative is to return a sequence of
domain events from `submit` now, rather than a result object.** This is the
largest structural fork in the spec.

**9.10 Status is derived and partly redundant [D-8, §3.3].** A market order
that half-fills reports `PARTIALLY_FILLED` even though nothing rests; only
`restingQuantity == 0` reveals it is terminal. The three quantities are
authoritative and the table in §3.3 must be enforced by a test. **A cleaner
alternative is a sealed result hierarchy (`Resting` / `Terminal`), which
Java 25 supports well. Rejected here for simplicity, but it is a reasonable
thing to change.**

**9.11 Terminal order states are retained forever [D-11].** Needed to tell
`UNKNOWN_ORDER` from `NOT_RESTING`, but it means the engine's memory grows
monotonically with the number of orders ever submitted. With bots running for
hours this is a real leak. **Either accept it as bounded-by-session, or drop
the distinction and return `UNKNOWN_ORDER` for both. Decide before bots
exist.**

**9.12 Concurrency — the intent's own open question [§6.11].** The spec
declares the engine single-threaded and not thread-safe, and asks for a race
test that is excluded from the build. Two honest problems with that:
a race test that passes proves nothing, and one that fails intermittently
teaches the team to ignore red. **It documents the hazard; it does not
protect against it.** The real decision — a single-writer command queue, a
coarse lock around `submit`/`cancel`, or a documented external contract — is
still open, and it should be made before anything concurrent (bots, REST)
calls the engine. Note that a lock inside `submit` is cheap and would make
the whole question go away at the cost of a few nanoseconds.

**9.13 The `.gitignore` conflict.** The repository currently has no
`.gitignore`, by explicit instruction. A Gradle build produces `build/` and
`.gradle/`, and without a `.gitignore` those will show up as untracked noise
in every `git status` and are easy to commit by accident. **A `.gitignore`
is needed before the first build is run. It requires a decision from Aika,
since its absence was deliberate.**

**9.14 Java 25 on Gradle and in CI.** Java 25 is recent enough that toolchain
support is version-sensitive: verify that the pinned Gradle version actually
accepts a release-25 toolchain, and that the CI action can provision a
Temurin 25 JDK, **before** relying on either. If Temurin 25 is unavailable on
the runner, the fallback is to run Gradle on an older JDK with a
foojay-resolved 25 toolchain, or to pin a different vendor. **Verify first;
do not assume.**

**9.15 Ownership boundary.** The intent says package `engine` and its tests
are written by Aika and not created or edited by agents. The build files, CI
workflow, and this spec fall outside that boundary and are assumed to be
fair game for an agent. **Confirm that reading is correct** — in particular
whether an agent may create `src/main/java/engine/` as an empty directory as
part of the skeleton, or whether even that is Aika's to do.

**9.16 Private repository and CI minutes.** The repository is private, so
Actions minutes are consumed from a limited monthly allowance rather than
being free. Low risk for one small job, worth knowing before the matrix
grows.

**9.17 Nothing here is validated against a real venue.** Price-time priority,
resting-price execution, and market-order sweep are the textbook rules and
are internally consistent, but no reference implementation or exchange
specification was consulted. If realism ever becomes a product requirement,
this spec should be checked against an actual matching-engine specification
rather than trusted.
