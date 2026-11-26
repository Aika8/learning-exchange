package application.assistant;

/**
 * Picks the Russian plural form for a count: «1 заявка», «3 заявки», «5 заявок», «21 заявка».
 * Rules: n%10 == 1 and n%100 != 11 → one; n%10 in 2..4 and n%100 not in 12..14 → few; else many.
 */
public final class RuPlural {

    private RuPlural() {
    }

    public static String of(long n, String one, String few, String many) {
        long abs = Math.abs(n);
        long mod10 = abs % 10;
        long mod100 = abs % 100;
        if (mod10 == 1 && mod100 != 11) {
            return one;
        }
        if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
            return few;
        }
        return many;
    }
}
