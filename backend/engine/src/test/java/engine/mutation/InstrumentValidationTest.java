package engine.mutation;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import engine.Instrument;
import org.junit.jupiter.api.Test;

/** The edges of what an instrument accepts: assets, fee and leverage (LE-019). */
class InstrumentValidationTest {

    @Test
    void anInstrumentNeedsAnIdAndBothAssets() {
        assertThrows(IllegalArgumentException.class, () -> new Instrument(null, "A", "B", 10));
        assertThrows(IllegalArgumentException.class, () -> new Instrument("A-B", null, "B", 10));
        assertThrows(IllegalArgumentException.class, () -> new Instrument("A-B", "A", null, 10));
    }

    @Test
    void baseAndQuoteMustDiffer() {
        assertThrows(IllegalArgumentException.class, () -> new Instrument("A-A", "A", "A", 10));
    }

    @Test
    void aZeroFeeIsAllowedAndANegativeFeeIsNot() {
        assertEquals(0, new Instrument("A-B", "A", "B", 0).feeBps());
        assertThrows(IllegalArgumentException.class, () -> new Instrument("A-B", "A", "B", -1));
    }

    @Test
    void theFeeStaysBelowOneHundredPercent() {
        assertEquals(9_999, new Instrument("A-B", "A", "B", 9_999).feeBps());
        assertThrows(IllegalArgumentException.class, () -> new Instrument("A-B", "A", "B", 10_000));
    }

    @Test
    void leverageRunsFromCashOnlyToTenTimes() {
        assertEquals(1, new Instrument("A-B", "A", "B", 5, 1).maxLeverage());
        assertEquals(10, new Instrument("A-B", "A", "B", 5, 10).maxLeverage());
        assertThrows(IllegalArgumentException.class, () -> new Instrument("A-B", "A", "B", 5, 0));
        assertThrows(IllegalArgumentException.class, () -> new Instrument("A-B", "A", "B", 5, 11));
    }
}
