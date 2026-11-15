package application.economy;

/**
 * Bond price, yield to maturity and duration. Prices are money (SPARK minor units, {@code long}); yields and
 * durations are ratios, so they are computed in {@code double} and returned as basis points / hundredths — never used
 * to move money (DECISIONS.md, M2b).
 *
 * <p>Model: coupons every period, the last one with the face value; {@code periodsLeft} whole periods, priced on a
 * coupon date (no accrued interest).
 */
public final class BondMath {

    private BondMath() {
    }

    /** Present value of the remaining cash flows at an annual yield {@code yieldBps}, compounded per period. */
    public static long price(long face, long couponPerPeriod, int periodsPerYear, int periodsLeft, long yieldBps) {
        if (periodsLeft <= 0) {
            return face;
        }
        double y = yieldBps / 10_000.0 / periodsPerYear;
        double pv = 0;
        for (int t = 1; t <= periodsLeft; t++) {
            double cf = couponPerPeriod + (t == periodsLeft ? face : 0);
            pv += cf / Math.pow(1 + y, t);
        }
        return Math.round(pv);
    }

    /** The annual yield (bps) at which {@link #price} equals {@code price}; bisection between −50% and 500%. */
    public static long yieldToMaturity(long price, long face, long couponPerPeriod, int periodsPerYear, int periodsLeft) {
        if (periodsLeft <= 0 || price <= 0) {
            return 0;
        }
        long lo = -5_000;
        long hi = 50_000;
        for (int i = 0; i < 60 && hi - lo > 1; i++) {
            long mid = (lo + hi) / 2;
            if (price(face, couponPerPeriod, periodsPerYear, periodsLeft, mid) > price) {
                lo = mid;
            } else {
                hi = mid;
            }
        }
        return hi;
    }

    /**
     * Modified duration in hundredths of a year: how many percent the price moves for a 1 percentage point change in
     * yield (Macaulay duration / (1 + y/m)).
     */
    public static long modifiedDurationX100(long face, long couponPerPeriod, int periodsPerYear, int periodsLeft,
                                            long yieldBps) {
        if (periodsLeft <= 0) {
            return 0;
        }
        double y = yieldBps / 10_000.0 / periodsPerYear;
        double pv = 0;
        double weighted = 0;
        for (int t = 1; t <= periodsLeft; t++) {
            double cf = couponPerPeriod + (t == periodsLeft ? face : 0);
            double d = cf / Math.pow(1 + y, t);
            pv += d;
            weighted += d * t / periodsPerYear;
        }
        double macaulay = weighted / pv;
        return Math.round(macaulay / (1 + y) * 100);
    }
}
