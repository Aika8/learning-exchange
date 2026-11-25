package engine.ref;

import engine.Order.Side;

/** A trade of the reference book; {@code aggressor} is the side of the incoming order. */
public record RefTrade(long buyId, long sellId, long price, long qty, Side aggressor) {}
