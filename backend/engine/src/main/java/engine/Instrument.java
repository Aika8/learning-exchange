package engine;

/**
 * A tradable pair: {@code base} is what is bought and sold (whole units), {@code quote} is what it is paid with
 * (integer minor units). A price is the number of quote minor units for one base unit.
 *
 * @param id       stable id used in the API and journal, e.g. {@code SILK-SPARK}
 * @param feeBps   fee charged to both sides of every trade, in basis points of the notional (1 bp = 0.01%)
 */
public record Instrument(String id, String base, String quote, long feeBps) {

    public Instrument {
        if (id == null || base == null || quote == null || base.equals(quote)) {
            throw new IllegalArgumentException("instrument needs an id and two different assets");
        }
        if (feeBps < 0 || feeBps >= 10_000) {
            throw new IllegalArgumentException("feeBps out of range: " + feeBps);
        }
    }

    /** The single M1 instrument. SPARK has 2 decimals on screen; prices and amounts stay integer minor units. */
    public static final Instrument SILK_SPARK = new Instrument("SILK-SPARK", "SILK", "SPARK", 10);

    /**
     * Fee on a notional, rounded down. Rounding down means the sum of fees on the parts of an order never
     * exceeds the fee on the whole order, so a reservation made for the whole order always covers the parts.
     */
    public long fee(long notional) {
        return Math.multiplyExact(notional, feeBps) / 10_000;
    }
}
