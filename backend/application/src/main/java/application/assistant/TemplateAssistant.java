package application.assistant;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * The assistant without a key: picks a topic by keywords and fills fixed ru/en sentences with the computed facts.
 * Always available, deterministic, used in tests and in the demo.
 *
 * <p>Pattern: Template-based adapter of the {@link Assistant} port and the fallback of {@link FallbackAssistant}.
 * See docs/adr/0013-assistant-llm-with-fallback.md.
 */
public final class TemplateAssistant implements Assistant {

    enum Topic { EXPECTATIONS, COSTS, GAME, SUMMARY }

    @Override
    public Answer answer(Question q, Facts f) {
        boolean en = q.english();
        List<String> parts = new ArrayList<>();
        if (new AdviceGuard().asksForAdvice(q.text())) {
            parts.add(en ? "I don't say what to buy or sell. Here is what your own numbers show."
                    : "Я не говорю, что покупать или продавать. Вот что показывают ваши собственные цифры.");
        }
        switch (topic(q, f)) {
            case EXPECTATIONS -> expectations(f, en, parts);
            case COSTS -> costs(f, en, parts);
            case GAME -> game(f, en, parts);
            case SUMMARY -> summary(f, en, parts);
        }
        return new Answer(String.join(" ", parts), Source.TEMPLATE, null, Assistant.disclaimer(q.lang()), false, f.facts());
    }

    static Topic topic(Question q, Facts f) {
        String t = q.text() == null ? "" : q.text().toLowerCase(Locale.ROOT);
        if (t.matches("(?s).*(ожидан|прогноз|консенсус|сюрприз|неожидан|expect|consensus|surprise|forecast).*")) {
            return Topic.EXPECTATIONS;
        }
        if (t.matches("(?s).*(комисс|спред|издерж|налог|fee|spread|cost|tax).*")) {
            return Topic.COSTS;
        }
        if (q.persona() == Persona.CHRONICLER && !f.startingWith("game.").isEmpty()) {
            return Topic.GAME;
        }
        return Topic.SUMMARY;
    }

    private static void expectations(Facts f, boolean en, List<String> out) {
        int start = out.size();
        f.number("rate.last.actualBps").ifPresent(actual -> {
            long consensus = f.number("rate.last.consensusBps").orElse(actual);
            long diff = actual - consensus;
            out.add(en
                    ? "The central bank set the rate at " + pct(actual) + " against a consensus of " + pct(consensus)
                    + (diff == 0 ? ": no surprise." : ": a surprise of " + signedBps(diff) + ".")
                    : "ЦБ установил ставку " + pct(actual) + " при консенсусе " + pct(consensus)
                    + (diff == 0 ? ": без сюрприза." : ": сюрприз " + signedBps(diff) + "."));
        });
        for (Facts.Fact r : f.startingWith("report.")) {
            String instrument = r.key().substring("report.".length(), r.key().lastIndexOf('.'));
            long s = Long.parseLong(r.value());
            out.add(en
                    ? instrument + " reported " + (s >= 0 ? "above" : "below") + " the consensus by " + pct(Math.abs(s)) + "."
                    : instrument + ": отчёт " + (s >= 0 ? "выше" : "ниже") + " консенсуса на " + pct(Math.abs(s)) + ".");
        }
        if (out.size() == start) {
            out.add(en ? "No rate decision or company report with a consensus yet."
                    : "Пока не было решения по ставке или отчёта компании с консенсусом.");
        }
        out.add(en ? "Prices move on the difference between the news and what was expected, not on the news alone."
                : "Цены двигает разница между новостью и ожиданием, а не сама новость.");
    }

    private static void costs(Facts f, boolean en, List<String> out) {
        long fees = f.number("statement.fees").orElse(0L);
        long spread = f.number("statement.spreadPaid").orElse(0L);
        long tax = f.number("statement.tax").orElse(0L);
        out.add(en
                ? "In this period you paid " + money(fees) + " SPARK in fees and about " + money(spread)
                + " SPARK in spread; tax due on the profit is " + money(tax) + " SPARK."
                : "За период вы заплатили " + money(fees) + " SPARK комиссий и около " + money(spread)
                + " SPARK спреда; налог с прибыли — " + money(tax) + " SPARK.");
        out.add(en
                ? "The spread is the gap between the best buy and sell prices; here, how much you gave up against the middle between them."
                : "Спред — разница между лучшей ценой покупки и продажи; здесь — сколько вы отдали против середины между ними.");
    }

    private static void summary(Facts f, boolean en, List<String> out) {
        long orders = f.number("review.orders").orElse(0L);
        if (orders == 0) {
            out.add(en ? "You have no orders in this period yet." : "В этом периоде у вас ещё нет заявок.");
        } else {
            long wins = f.number("review.wins").orElse(0L);
            long result = f.number("review.result").orElse(0L);
            out.add(en
                    ? orders + " orders, " + wins + " in profit; the result if everything were closed at the last price is " + signedMoney(result) + " SPARK."
                    : orders + " заявок, " + wins + " в плюсе; результат, если бы всё закрыть по последней цене, " + signedMoney(result) + " SPARK.");
            f.number("review.expectancyRx100").ifPresent(r -> out.add(en
                    ? "Average result per planned risk: " + rx(r) + " R."
                    : "Средний результат на запланированный риск: " + rx(r) + " R."));
            f.get("review.worstMood").ifPresent(m -> out.add(en
                    ? "Your weakest mood group: " + m.value() + "."
                    : "Слабее всего ваши сделки с настроением " + m.value() + "."));
        }
        costs(f, en, out);
    }

    private static void game(Facts f, boolean en, List<String> out) {
        long voyages = f.number("game.voyages").orElse(0L);
        long wins = f.number("game.wins").orElse(0L);
        long result = f.number("game.result").orElse(0L);
        out.add(en
                ? "The chronicle of the day: " + voyages + " voyages, " + wins + " came home with profit, " + signedMoney(result) + " SPARK in all."
                : "Летопись дня: рейсов " + voyages + ", с прибылью вернулись " + wins + ", итог " + signedMoney(result) + " SPARK.");
        f.number("game.expectancyRx100").ifPresent(r -> out.add(en
                ? "On average a voyage brought " + rx(r) + " R."
                : "В среднем рейс принёс " + rx(r) + " R."));
        long fees = f.number("game.fees").orElse(0L) + f.number("game.spreadPaid").orElse(0L);
        out.add(en ? "The harbour took " + money(fees) + " SPARK in fees and spread."
                : "Гавань взяла " + money(fees) + " SPARK пошлин и спреда.");
        f.number("game.dayReturnBps").ifPresent(d -> f.number("game.basketReturnBps").ifPresent(b -> out.add(en
                ? "Your day: " + signedBps(d) + "; Grandma Vetla's basket: " + signedBps(b) + "."
                : "Ваш день: " + signedBps(d) + "; корзина Бабушки Ветлы: " + signedBps(b) + ".")));
        f.number("game.gapsThroughStop").filter(g -> g > 0).ifPresent(g -> out.add(en
                ? "Gaps through the Anchor: " + g + " — a stop is a price to try, not a promise."
                : "Гэпов сквозь Якорь: " + g + " — стоп обещает попытку, а не цену."));
    }

    static String money(long minor) {
        long abs = Math.abs(minor);
        return (minor < 0 ? "−" : "") + abs / 100 + "." + String.format("%02d", abs % 100);
    }

    static String signedMoney(long minor) {
        return (minor > 0 ? "+" : "") + money(minor);
    }

    static String pct(long bps) {
        return bps / 100 + "." + String.format("%02d", Math.abs(bps % 100)) + "%";
    }

    static String signedBps(long bps) {
        return (bps > 0 ? "+" : bps < 0 ? "−" : "") + pct(Math.abs(bps));
    }

    static String rx(long rx100) {
        return (rx100 < 0 ? "−" : "") + Math.abs(rx100) / 100 + "." + String.format("%02d", Math.abs(rx100) % 100);
    }
}
