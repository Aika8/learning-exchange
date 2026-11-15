package application;

import java.util.List;

/**
 * Average True Range (Wilder, 1978): how much the price swings per bank day, gaps included. It says nothing about
 * direction; the position-size helper uses it to put the stop k × ATR away, so normal noise does not hit it.
 * Integer arithmetic in minor units, rounded half up.
 */
public final class Atr {

    private Atr() {
    }

    public record Result(int period, int candles, Long atr) {

        public boolean ready() {
            return atr != null;
        }
    }

    /** {@code candles} oldest first; needs {@code period + 1} of them (the first only gives a previous close). */
    public static Result wilder(List<CandleProjection.Candle> candles, int period) {
        if (period < 2) {
            throw new IllegalArgumentException("period must be at least 2");
        }
        if (candles.size() < period + 1) {
            return new Result(period, candles.size(), null);
        }
        long sum = 0;
        long atr = 0;
        for (int i = 1; i < candles.size(); i++) {
            long tr = trueRange(candles.get(i), candles.get(i - 1).close());
            if (i <= period) {
                sum += tr;
                if (i == period) {
                    atr = divRound(sum, period);
                }
            } else {
                atr = divRound(atr * (period - 1) + tr, period);
            }
        }
        return new Result(period, candles.size(), atr);
    }

    /** max(high − low, |high − previous close|, |low − previous close|). */
    static long trueRange(CandleProjection.Candle c, long previousClose) {
        return Math.max(c.high() - c.low(), Math.max(Math.abs(c.high() - previousClose), Math.abs(c.low() - previousClose)));
    }

    private static long divRound(long a, long b) {
        return (a + b / 2) / b;
    }
}
