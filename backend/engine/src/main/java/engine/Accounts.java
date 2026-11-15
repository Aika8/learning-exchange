package engine;

/**
 * Account ids. A person's money lives in their account ({@code acc-aika}); a leveraged position and a savings
 * deposit each get a sub-account ({@code acc-aika~m3}, {@code acc-aika~s1}) so the ledger shows exactly what they
 * hold and the same reservation rules apply. {@code ~} cannot appear in a login name, so sub-accounts never clash.
 */
public final class Accounts {

    public static final char SEPARATOR = '~';

    private Accounts() {
    }

    public static String marginAccount(String owner, long positionId) {
        return owner + SEPARATOR + "m" + positionId;
    }

    public static String savingsAccount(String owner, long depositId) {
        return owner + SEPARATOR + "s" + depositId;
    }

    /** The person behind an account or sub-account. */
    public static String owner(String account) {
        int i = account.indexOf(SEPARATOR);
        return i < 0 ? account : account.substring(0, i);
    }

    public static boolean isSubAccount(String account) {
        return account.indexOf(SEPARATOR) >= 0;
    }
}
