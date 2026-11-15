package application.economy;

import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Terms of the funds the exchange lists (M2c, ADR-0022). A fund's custody account holds its basket (shares and some
 * cash); a unit of the fund trades on the exchange like a share, and a dealer quotes it around NAV per unit. The TER is
 * charged every bank day by the simulation clock: cash moves from custody to the manager, so NAV falls by the fee.
 */
public final class Funds {

    private Funds() {
    }

    public enum Kind { INDEX, ACTIVE }

    /**
     * @param holdings base asset → units in custody at the start (the index fund holds both companies in equal share
     *                 counts, which is their capitalisation weight because both have 1 000 000 shares)
     * @param cash     starting cash in custody, SPARK minor units; the fee is paid from it
     * @param terBps   total expense ratio a year
     */
    public record Fund(String instrument, String unit, Kind kind, String custody, String manager, long terBps,
                       Map<String, Long> holdings, long cash) {}

    public static final List<Fund> FUNDS = List.of(
            new Fund("IDX-SPARK", "IDX", Kind.INDEX, "fund-idx", "manager-idx", 20,
                    Map.of("SILK", 2_000L, "FORGE", 2_000L), 3_500_000L),
            new Fund("ACT-SPARK", "ACT", Kind.ACTIVE, "fund-act", "manager-act", 200,
                    Map.of("SILK", 600L, "FORGE", 1_600L), 3_000_000L));

    /** Base asset → instrument it trades on. */
    public static final Map<String, String> MARKET_OF = Map.of("SILK", "SILK-SPARK", "FORGE", "FORGE-SPARK");

    public static Optional<Fund> fund(String instrument) {
        return FUNDS.stream().filter(f -> f.instrument().equals(instrument)).findFirst();
    }

    /** 1 − (1 − TER)^years in basis points: what the fee takes over {@code years} at zero growth. */
    public static long costOverYearsBps(long terBps, int years) {
        return Math.round((1 - Math.pow(1 - terBps / 10_000.0, years)) * 10_000);
    }
}
