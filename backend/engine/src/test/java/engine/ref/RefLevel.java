package engine.ref;

/** One price level of the reference book: total remaining quantity and number of resting orders. */
public record RefLevel(long price, long qty, int orders) {}
