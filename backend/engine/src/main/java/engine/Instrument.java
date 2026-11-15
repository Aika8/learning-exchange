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

    /** M2b: a second company stock (a workshop of the Forge), with quarterly reports and dividends. */
    public static final Instrument FORGE_SPARK = new Instrument("FORGE-SPARK", "FORGE", "SPARK", 10);

    /**
     * M2b bonds: one unit = one bond with a face value of 1 000.00 SPARK; the price is per bond in SPARK minor units.
     * HBND is the harbour treasury's (AAA), GBND a weak guild's (CCC, high coupon, may default). Terms live in the
     * application's securities catalogue; the engine only moves coupons and redemptions (ADR-0021).
     */
    public static final Instrument HBND_SPARK = new Instrument("HBND-SPARK", "HBND", "SPARK", 5);
    public static final Instrument GBND_SPARK = new Instrument("GBND-SPARK", "GBND", "SPARK", 5);

    /**
     * M2c funds: one unit is a share of a fund's basket (index: both companies by capitalisation; active: the manager's
     * picks). The fund's custody holds the basket; its terms and TER live in the application (ADR-0022).
     */
    public static final Instrument IDX_SPARK = new Instrument("IDX-SPARK", "IDX", "SPARK", 5);
    public static final Instrument ACT_SPARK = new Instrument("ACT-SPARK", "ACT", "SPARK", 5);

    /** Every instrument, in catalogue order. */
    public static final java.util.List<Instrument> ALL = java.util.List.of(SILK_SPARK, AMBER_SPARK, FORGE_SPARK,
            HBND_SPARK, GBND_SPARK, IDX_SPARK, ACT_SPARK);

    /**
     * Fee on a notional, rounded down. Rounding down means the sum of fees on the parts of an order never
     * exceeds the fee on the whole order, so a reservation made for the whole order always covers the parts.
     */
    public long fee(long notional) {
        return Math.multiplyExact(notional, feeBps) / 10_000;
    }
}
