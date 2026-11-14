package bots;

import application.TradingService;
import java.io.InputStream;
import java.io.Reader;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.yaml.snakeyaml.LoaderOptions;
import org.yaml.snakeyaml.Yaml;
import org.yaml.snakeyaml.constructor.SafeConstructor;

/**
 * Builds bots from {@code bots.yaml}: reads the file, picks the strategy class by name, logs each bot in like a person
 * and gives a new bot its starting capital as a deposit.
 *
 * <p>Pattern: Factory — the rest of the code never says {@code new MarketMaker(...)}; config decides.
 * See docs/adr/0007-bots-are-api-clients.md.
 */
public final class BotFactory {

    private BotFactory() {
    }

    public static BotConfig parse(Reader yaml) {
        Map<String, Object> root = new Yaml(new SafeConstructor(new LoaderOptions())).load(yaml);
        Map<String, Object> fv = map(root.get("fairValue"));
        List<BotConfig.BotSpec> specs = new ArrayList<>();
        for (Object o : (List<?>) root.get("bots")) {
            Map<String, Object> b = map(o);
            Map<String, Long> capital = new java.util.LinkedHashMap<>();
            map(b.getOrDefault("capital", Map.of())).forEach((k, v) -> capital.put(k, ((Number) v).longValue()));
            specs.add(new BotConfig.BotSpec((String) b.get("name"), (String) b.get("strategy"),
                    ((Number) b.getOrDefault("count", 1)).intValue(), capital, map(b.getOrDefault("params", Map.of()))));
        }
        return new BotConfig(num(root, "seed", 42), (String) root.getOrDefault("instrument", "SILK-SPARK"),
                num(root, "tickMillis", 500),
                new BotConfig.FairValueConfig(num(fv, "start", 10_000), ((Number) fv.getOrDefault("volatilityBps", 5)).doubleValue(),
                        num(fv, "floor", 100)),
                specs);
    }

    public static BotConfig parse(InputStream in) {
        return parse(new java.io.InputStreamReader(in, java.nio.charset.StandardCharsets.UTF_8));
    }

    public static List<TradingBot> create(BotConfig config, TradingService market) {
        List<TradingBot> out = new ArrayList<>();
        long n = 0;
        for (BotConfig.BotSpec spec : config.bots()) {
            for (int i = 1; i <= spec.count(); i++) {
                String name = spec.count() == 1 ? spec.name() : spec.name() + "-" + i;
                TradingService.Account account = market.login(name);
                boolean fresh = market.orders(account.accountId(), false, 1).isEmpty();
                if (fresh) {
                    spec.capital().forEach((asset, amount) -> market.deposit(account.accountId(), asset, amount));
                }
                long seed = config.seed() * 1_000_003 + (++n);
                out.add(new TradingBot(name, account.accountId(), config.instrument(), strategy(spec), seed, market));
            }
        }
        return out;
    }

    static Strategy strategy(BotConfig.BotSpec spec) {
        Map<String, Object> p = spec.params();
        return switch (spec.strategy()) {
            case "market-maker" -> new MarketMaker(num(p, "halfSpread", 10), num(p, "step", 5),
                    (int) num(p, "levels", 5), num(p, "qty", 10), num(p, "targetBase", 0), dbl(p, "skewPerUnit", 0.01));
            case "noise" -> new Noise(dbl(p, "activity", 0.5), num(p, "maxQty", 5), dbl(p, "marketShare", 0.5));
            default -> throw new IllegalArgumentException("unknown strategy in bots.yaml: " + spec.strategy());
        };
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> map(Object o) {
        return o == null ? Map.of() : (Map<String, Object>) o;
    }

    private static long num(Map<String, Object> m, String key, long dflt) {
        Object v = m.get(key);
        return v == null ? dflt : ((Number) v).longValue();
    }

    private static double dbl(Map<String, Object> m, String key, double dflt) {
        Object v = m.get(key);
        return v == null ? dflt : ((Number) v).doubleValue();
    }
}
