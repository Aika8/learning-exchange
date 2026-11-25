package engine.model;

import engine.Order;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Random;

/**
 * Random but valid order-book actions from a seed. Plain {@link Random}, so a failing seed can be
 * replayed by hand: {@code ActionGen.generate(seed, length)}.
 */
public final class ActionGen {

    /** Limit prices are drawn from {@code MIN_PRICE..MAX_PRICE}: a narrow band, so orders cross often. */
    public static final long MIN_PRICE = 95;
    public static final long MAX_PRICE = 105;
    public static final long MIN_QTY = 1;
    public static final long MAX_QTY = 20;
    /** Upper bound (exclusive) of a {@link Action.Cancel#pickIndex()}; it is taken modulo the resting count. */
    public static final int MAX_PICK = 1_000;

    private ActionGen() {}

    /** {@code length} actions: about 45 % limit, 20 % market, 35 % cancel. Same seed, same list. */
    public static List<Action> generate(long seed, int length) {
        if (length < 0) {
            throw new IllegalArgumentException("length must not be negative: " + length);
        }
        Random random = new Random(seed);
        List<Action> actions = new ArrayList<>(length);
        for (int i = 0; i < length; i++) {
            int roll = random.nextInt(100);
            if (roll < 45) {
                actions.add(new Action.SubmitLimit(side(random), price(random), qty(random)));
            } else if (roll < 65) {
                actions.add(new Action.SubmitMarket(side(random), qty(random)));
            } else {
                actions.add(new Action.Cancel(random.nextInt(MAX_PICK)));
            }
        }
        return Collections.unmodifiableList(actions);
    }

    private static Order.Side side(Random random) {
        return random.nextBoolean() ? Order.Side.BUY : Order.Side.SELL;
    }

    private static long price(Random random) {
        return MIN_PRICE + random.nextInt((int) (MAX_PRICE - MIN_PRICE + 1));
    }

    private static long qty(Random random) {
        return MIN_QTY + random.nextInt((int) (MAX_QTY - MIN_QTY + 1));
    }
}
