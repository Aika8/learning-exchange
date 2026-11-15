package engine;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** Savings deposits: daily compound interest on simulation time, paid by the bank account. */
class SavingsTest {

    private static final long DAY = 1_000;
    private Exchange ex;

    @BeforeEach
    void setUp() {
        ex = new Exchange(Instrument.ALL);
        ex.execute(new Command.Deposit(Ledger.BANK_ACCOUNT, "SPARK", 1_000_000_000), 0);
        ex.execute(new Command.OpenAccount("aika", "aika"), 0);
        ex.execute(new Command.Deposit("aika", "SPARK", 10_000_000), 0);
    }

    @Test
    void interestCompoundsDaily() {
        long id = ex.execute(new Command.OpenSavings("aika", "SPARK", 1_000_000, 1_400, DAY), 0).orderId();

        ex.execute(new Command.AccrueInterest(), DAY - 1);
        assertEquals(1_000_000, ex.deposit(id).orElseThrow().balance(), "no whole day yet");

        ex.execute(new Command.AccrueInterest(), 2 * DAY + 10);
        // day 1: 1 000 000 × 14% / 365 = 383.56 → 383; day 2: 1 000 383 × 14% / 365 = 383.70 → 383 (interest on interest)
        assertEquals(1_000_766, ex.deposit(id).orElseThrow().balance());
    }

    @Test
    void aYearAt14PercentNearlyFollowsTheCompoundFormula() {
        long id = ex.execute(new Command.OpenSavings("aika", "SPARK", 1_000_000, 1_400, DAY), 0).orderId();

        ex.execute(new Command.AccrueInterest(), 365 * DAY);

        long balance = ex.deposit(id).orElseThrow().balance();
        // (1 + 0.14/365)^365 = 1.15024…; daily rounding down costs at most 1 minor unit a day.
        assertTrue(balance <= 1_150_236 && balance >= 1_150_236 - 365, "balance " + balance);
    }

    @Test
    void accruingDayByDayOrAllAtOnceGivesTheSameMoney() {
        Exchange other = new Exchange(Instrument.ALL);
        other.execute(new Command.Deposit(Ledger.BANK_ACCOUNT, "SPARK", 1_000_000_000), 0);
        other.execute(new Command.OpenAccount("aika", "aika"), 0);
        other.execute(new Command.Deposit("aika", "SPARK", 10_000_000), 0);
        long a = ex.execute(new Command.OpenSavings("aika", "SPARK", 1_234_567, 1_400, DAY), 0).orderId();
        long b = other.execute(new Command.OpenSavings("aika", "SPARK", 1_234_567, 1_400, DAY), 0).orderId();

        for (long t = 1; t <= 30; t++) {
            ex.execute(new Command.AccrueInterest(), t * DAY + 7);
        }
        other.execute(new Command.AccrueInterest(), 30 * DAY + 7);

        assertEquals(other.deposit(b).orElseThrow().balance(), ex.deposit(a).orElseThrow().balance());
    }

    @Test
    void closingPaysPrincipalAndInterestBackAndMoneyIsConserved() {
        long total = ex.ledger().totalOf("SPARK");
        long id = ex.execute(new Command.OpenSavings("aika", "SPARK", 1_000_000, 1_400, DAY), 0).orderId();
        ex.execute(new Command.AccrueInterest(), 10 * DAY);

        Outcome o = ex.execute(new Command.CloseSavings("aika", id), 10 * DAY);

        long payout = ((Event.SavingsClosed) o.events().getFirst()).payout();
        assertTrue(payout > 1_000_000);
        assertEquals(10_000_000 - 1_000_000 + payout, ex.ledger().available("aika", "SPARK"));
        assertEquals(total, ex.ledger().totalOf("SPARK"), "interest moved from the bank, nothing created");
    }

    @Test
    void cannotDepositMoreThanAvailable() {
        assertEquals(Rejection.INSUFFICIENT_FUNDS,
                ex.execute(new Command.OpenSavings("aika", "SPARK", 10_000_001, 1_400, DAY), 0).rejection());
        assertEquals(List.of(), ex.savingsOf("aika"));
    }
}
