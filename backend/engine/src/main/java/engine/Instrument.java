package engine;

/**
 * A tradable pair: {@code base} is what is bought and sold (whole units), {@code quote} is what it is paid with
 * (integer minor units). A price is the number of quote minor units for one base unit.
 *
 * @param id       stable id used in the API and journal, e.g. {@code SILK-SPARK}
 * @param feeBps      fee charged to both sides of every trade, in basis points of the notional (1 bp = 0.01%)
 * @param maxLeverage 1 = cash only; above 1 the instrument can be traded with margin (M2a: FX ×4)
 */
public record Instrument(String id, String base, String quote, long feeBps, int maxLeverage) {

    public Instrument {
        if (id == null || base == null || quote == null || base.equals(quote)) {
            throw new IllegalArgumentException("instrument needs an id and two different assets");
        }
        if (feeBps < 0 || feeBps >= 10_000) {
            throw new IllegalArgumentException("feeBps out of range: " + feeBps);
        }
        if (maxLeverage < 1 || maxLeverage > 10) {
            throw new IllegalArgumentException("maxLeverage out of range: " + maxLeverage);
        }
    }

    /** A cash-only instrument. */
    public Instrument(String id, String base, String quote, long feeBps) {
        this(id, base, quote, feeBps, 1);
    }

    /** The single M1 instrument. SPARK has 2 decimals on screen; prices and amounts stay integer minor units. */
    public static final Instrument SILK_SPARK = new Instrument("SILK-SPARK", "SILK", "SPARK", 10);

    /**
     * The FX pair (M2a): AMBER is a foreign currency in whole units, priced in SPARK minor units, like USD/KZT.
     * Lower fee than the stock, leverage up to ×4 with stop-out at 50% (vault: finance/fx-market-kz.md, TOM/SPOT).
     */
    public static final Instrument AMBER_SPARK = new Instrument("AMBER-SPARK", "AMBER", "SPARK", 5, 4);

    /** Both instruments of M2a, in catalogue order. */
    public static final java.util.List<Instrument> ALL = java.util.List.of(SILK_SPARK, AMBER_SPARK);

    /**
     * Fee on a notional, rounded down. Rounding down means the sum of fees on the parts of an order never
     * exceeds the fee on the whole order, so a reservation made for the whole order always covers the parts.
     */
    public long fee(long notional) {
        return Math.multiplyExact(notional, feeBps) / 10_000;
    }
}
