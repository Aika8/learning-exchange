# Decisions — increment 1 (order book)

Choices the brief left open. Each one is the simplest behaviour; revisit any of them deliberately.

- Engine ownership: the intent says `engine` and its tests are written by Aika; for this increment Aika chose to have the agent write them.
- Java version: the brief said 17, the intent said 25; Aika chose 25 (Gradle toolchain).
- Obsolete spec: `intent/01-order-book.spec.md` was already deleted in commit 38363bd; nothing to delete.
- Price and quantity are `long` integer ticks/units; no decimals, no tick size.
- Zero or negative quantity: rejected with `IllegalArgumentException` when the `Order` is constructed.
- Zero or negative limit price: rejected with `IllegalArgumentException`.
- Market order price: must be 0 and is never used for matching.
- No price bands or collars: a market order walks the whole opposite side.
- Self-trade: orders have no owner, so self-trade cannot be detected; any two crossing orders match.
- Time priority is arrival order into the level's deque; the `timestamp` field is informational and not compared.
- Order ids are supplied by the caller; submitting an id that is currently resting throws `IllegalArgumentException`.
- An id that was fully filled or cancelled is forgotten, so it can be reused (not checked).
- Submitting an `Order` object that has already been partially filled throws `IllegalArgumentException`.
- The unfilled market remainder is not reported separately: the caller reads `order.remaining()` after `submit`.
- `Order` is mutable in one field (`filled`); `remaining = qty − filled`.
- `Trade` records buy order id, sell order id, price and qty; it does not say which side was the aggressor.
- `cancel` returns false for unknown, already filled, or already cancelled ids.
- `cancel` removes from the level's deque in O(n) of that level; acceptable at learning scale.
- Read-only `bids(depth)` / `asks(depth)` returning aggregated `Level(price, qty, orders)` were added so the REPL can print the top 5 levels.
- Repl lives in package `repl`, outside `engine`.
- Repl assigns ids and timestamps from one counter starting at 1; a rejected order still consumes an id.
- Repl: `book` prints only the book; unknown or malformed commands print an error and the book is not reprinted; end of input acts like `quit`.
- Repl prints asks highest-first above the spread and bids highest-first below it.
