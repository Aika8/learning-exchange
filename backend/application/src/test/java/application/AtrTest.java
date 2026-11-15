package application;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

class AtrTest {

    private static CandleProjection.Candle c(long high, long low, long close) {
        return new CandleProjection.Candle(0, close, high, low, close, 1);
    }

    @Test
    void trueRangeCountsTheGapFromThePreviousClose() {
        assertEquals(30, Atr.trueRange(c(130, 120, 125), 100)); // gap up: high − previous close
        assertEquals(10, Atr.trueRange(c(110, 100, 105), 104));
    }

    @Test
    void firstAtrIsTheMeanThenWilderSmoothing() {
        List<CandleProjection.Candle> cs = new ArrayList<>();
        cs.add(c(100, 100, 100));
        for (int i = 0; i < 3; i++) {
            cs.add(c(110, 100, 100)); // TR 10
        }
        assertFalse(Atr.wilder(cs.subList(0, 3), 3).ready());
        assertEquals(10, Atr.wilder(cs, 3).atr());
        cs.add(c(140, 100, 100)); // TR 40 → (10 × 2 + 40) / 3 = 20
        assertEquals(20, Atr.wilder(cs, 3).atr());
    }
}
