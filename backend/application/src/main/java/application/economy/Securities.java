package application.economy;

import java.util.List;
import java.util.Optional;

/**
 * Terms of the securities the exchange lists beyond plain pairs: companies (stocks with quarterly reports) and bonds.
 * Reference data, fixed in code like {@link engine.Instrument}; names for people live in the catalogue
 * ({@code docs/lore/catalogue.yaml}, ADR-0012).
 */
public final class Securities {

    private Securities() {
    }

    /**
     * A listed company. Hidden fundamentals drive its reports: revenue per season, net margin, growth per season
     * (all money in SPARK minor units; rates in basis points). {@code issuer} is the account that pays dividends.
     *
     * @param sharesOutstanding shares used for EPS (the company's whole capital, not just the traded float)
     * @param payoutBps         share of net profit paid as dividends (0 = none)
     * @param reportDay         day of the season (0..90) the report comes out
     */
    public record Company(String instrument, String issuer, long sharesOutstanding, long revenue, long netMarginBps,
                          long growthBps, long debt, long payoutBps, int reportDay) {}

    /**
     * A bond: one unit has {@code faceValue} SPARK minor units, pays {@code couponBps} a year in
     * {@code couponsPerYear} coupons, and is repaid after {@code seasons} seasons. {@code rating} is on the real scale
     * (AAA…CCC); {@code spreadBps} is the credit spread the market asks over the policy rate.
     */
    public record Bond(String instrument, String issuer, long faceValue, long couponBps, int couponsPerYear, int seasons,
                       String rating, long spreadBps) {

        public long couponPerUnit() {
            return faceValue * couponBps / 10_000 / couponsPerYear;
        }
    }

    public static final List<Company> COMPANIES = List.of(
            new Company("SILK-SPARK", "issuer-silk", 1_000_000, 900_000_000, 1_100, 150, 1_200_000_000, 4_000, 50),
            new Company("FORGE-SPARK", "issuer-forge", 1_000_000, 2_000_000_000, 1_000, 250, 3_000_000_000L, 0, 62));

    public static final List<Bond> BONDS = List.of(
            new Bond("HBND-SPARK", "issuer-hbnd", 100_000, 1_300, 4, 12, "AAA", 50),
            new Bond("GBND-SPARK", "issuer-gbnd", 100_000, 3_000, 4, 8, "CCC", 1_600));

    public static Optional<Company> company(String instrument) {
        return COMPANIES.stream().filter(c -> c.instrument().equals(instrument)).findFirst();
    }

    public static Optional<Bond> bond(String instrument) {
        return BONDS.stream().filter(b -> b.instrument().equals(instrument)).findFirst();
    }

    /** STOCK, FX or BOND. */
    public static String kind(String instrument) {
        if (company(instrument).isPresent()) {
            return "STOCK";
        }
        if (bond(instrument).isPresent()) {
            return "BOND";
        }
        return "FX";
    }
}
