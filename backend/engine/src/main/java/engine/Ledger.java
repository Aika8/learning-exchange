package engine;

import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

/**
 * Accounts and balances with funds reservation. Every movement keeps the total of each asset constant except
 * {@link #deposit}: money is moved, never created or destroyed (intent 02, invariant 1).
 *
 * <p>An order first {@link #reserve reserves} what it may spend; a fill {@link #settleFromReserved spends from the
 * reservation}; whatever is left when the order ends is {@link #release released}. So the risk check happens
 * once, before the order reaches the book. See docs/adr/0006-single-writer-and-sim-clock.md.
 *
 * <p>Not thread-safe: owned by the single writer, like {@link OrderBook}.
 */
public final class Ledger {

    /** The account that collects trading fees. */
    public static final String FEES_ACCOUNT = "exchange-fees";

    private final Map<String, Map<String, long[]>> accounts = new LinkedHashMap<>();

    public boolean exists(String account) {
        return accounts.containsKey(account);
    }

    public void open(String account) {
        if (accounts.putIfAbsent(account, new TreeMap<>()) != null) {
            throw new IllegalStateException("account exists: " + account);
        }
    }

    public void deposit(String account, String asset, long amount) {
        requirePositive(amount);
        slot(account, asset)[0] += amount;
    }

    public long available(String account, String asset) {
        long[] s = find(account, asset);
        return s == null ? 0 : s[0];
    }

    public long reserved(String account, String asset) {
        long[] s = find(account, asset);
        return s == null ? 0 : s[1];
    }

    /** Moves {@code amount} from available to reserved. Returns false (and changes nothing) if not enough. */
    public boolean reserve(String account, String asset, long amount) {
        requirePositive(amount);
        long[] s = slot(account, asset);
        if (s[0] < amount) {
            return false;
        }
        s[0] -= amount;
        s[1] += amount;
        return true;
    }

    /** Moves {@code amount} back from reserved to available. */
    public void release(String account, String asset, long amount) {
        if (amount == 0) {
            return;
        }
        requirePositive(amount);
        long[] s = slot(account, asset);
        if (s[1] < amount) {
            throw new IllegalStateException("release more than reserved: " + account + " " + asset);
        }
        s[1] -= amount;
        s[0] += amount;
    }

    /** Spends {@code amount} of {@code from}'s reservation and credits it to {@code to}'s available balance. */
    public void settleFromReserved(String from, String to, String asset, long amount) {
        if (amount == 0) {
            return;
        }
        requirePositive(amount);
        long[] src = slot(from, asset);
        if (src[1] < amount) {
            throw new IllegalStateException("settle more than reserved: " + from + " " + asset);
        }
        src[1] -= amount;
        slot(to, asset)[0] += amount;
    }

    /** Moves from {@code from}'s available balance to {@code to}'s available balance. */
    public void transferAvailable(String from, String to, String asset, long amount) {
        if (amount == 0) {
            return;
        }
        requirePositive(amount);
        long[] src = slot(from, asset);
        if (src[0] < amount) {
            throw new IllegalStateException("transfer more than available: " + from + " " + asset);
        }
        src[0] -= amount;
        slot(to, asset)[0] += amount;
    }

    public List<Balance> balances(String account) {
        Map<String, long[]> assets = accounts.get(account);
        if (assets == null) {
            return List.of();
        }
        List<Balance> out = new ArrayList<>();
        assets.forEach((asset, s) -> out.add(new Balance(asset, s[0], s[1])));
        return Collections.unmodifiableList(out);
    }

    /** Sum of available + reserved of one asset over all accounts. */
    public long totalOf(String asset) {
        long sum = 0;
        for (Map<String, long[]> assets : accounts.values()) {
            long[] s = assets.get(asset);
            if (s != null) {
                sum = Math.addExact(sum, s[0] + s[1]);
            }
        }
        return sum;
    }

    public List<String> accountIds() {
        return List.copyOf(accounts.keySet());
    }

    private long[] find(String account, String asset) {
        Map<String, long[]> assets = accounts.get(account);
        return assets == null ? null : assets.get(asset);
    }

    private long[] slot(String account, String asset) {
        Map<String, long[]> assets = accounts.get(account);
        if (assets == null) {
            throw new IllegalStateException("unknown account: " + account);
        }
        return assets.computeIfAbsent(asset, a -> new long[2]);
    }

    private static void requirePositive(long amount) {
        if (amount <= 0) {
            throw new IllegalArgumentException("amount must be positive: " + amount);
        }
    }
}
