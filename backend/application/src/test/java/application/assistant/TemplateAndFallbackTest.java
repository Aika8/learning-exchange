package application.assistant;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import org.junit.jupiter.api.Test;

class TemplateAndFallbackTest {

    static final Facts FACTS = Facts.builder()
            .add("statement.fees", 120, Facts.Kind.MONEY)
            .add("statement.spreadPaid", 450, Facts.Kind.MONEY)
            .add("statement.tax", 0, Facts.Kind.MONEY)
            .add("review.orders", 3, Facts.Kind.COUNT)
            .add("review.wins", 1, Facts.Kind.COUNT)
            .add("review.result", -2_500, Facts.Kind.MONEY)
            .add("review.expectancyRx100", -140, Facts.Kind.RX100)
            .code("review.worstMood", "FOMO")
            .add("rate.last.actualBps", 900, Facts.Kind.BPS)
            .add("rate.last.consensusBps", 850, Facts.Kind.BPS)
            .add("report.FORGE-SPARK.surpriseBps", -1_200, Facts.Kind.BPS)
            .build();

    final TemplateAssistant template = new TemplateAssistant();

    @Test
    void expectationsQuestionTellsTheSurprisesInRussianAndEnglish() {
        var ru = template.answer(new Assistant.Question("Что изменилось против ожиданий?", "ru", null), FACTS);
        assertTrue(ru.text().contains("ставку 9.00% при консенсусе 8.50%: сюрприз +0.50%"), ru.text());
        assertTrue(ru.text().contains("FORGE-SPARK: отчёт ниже консенсуса на 12.00%"), ru.text());
        assertEquals(Assistant.Source.TEMPLATE, ru.source());
        assertTrue(ru.disclaimer().contains("не инвестиционный совет"));
        var en = template.answer(new Assistant.Question("What changed against expectations?", "en", null), FACTS);
        assertTrue(en.text().contains("a surprise of +0.50%"), en.text());
        assertTrue(en.disclaimer().contains("not investment advice"));
    }

    @Test
    void summaryUsesTheReviewAndNeverAdvises() {
        var a = template.answer(new Assistant.Question("Как прошла сессия?", "ru", null), FACTS);
        assertTrue(a.text().contains("3 заявок, 1 в плюсе"), a.text());
        assertTrue(a.text().contains("−25.00 SPARK"), a.text());
        assertTrue(a.text().contains("−1.40 R"), a.text());
        assertFalse(new AdviceGuard().isAdvice(a.text()), a.text());
    }

    @Test
    void chroniclerTellsTheGameDay() {
        Facts game = Facts.builder().add("game.voyages", 2, Facts.Kind.COUNT).add("game.wins", 1, Facts.Kind.COUNT)
                .add("game.result", 1_500, Facts.Kind.MONEY).add("game.fees", 30, Facts.Kind.MONEY)
                .add("game.spreadPaid", 70, Facts.Kind.MONEY).build();
        var a = template.answer(new Assistant.Question("Расскажи о дне", "ru", Assistant.Persona.CHRONICLER), game);
        assertTrue(a.text().startsWith("Летопись дня: рейсов 2"), a.text());
        assertTrue(a.text().contains("Гавань взяла 1.00 SPARK"), a.text());
    }

    private static Assistant fixed(String text) {
        return (q, f) -> new Assistant.Answer(text, Assistant.Source.CLAUDE, "m", Assistant.disclaimer(q.lang()), false, List.of());
    }

    @Test
    void fallbackKeepsAGoodModelAnswer() {
        var a = new FallbackAssistant(fixed("You paid 1.20 SPARK in fees."), template, new AdviceGuard())
                .answer(new Assistant.Question("fees?", "en", null), FACTS);
        assertEquals(Assistant.Source.CLAUDE, a.source());
        assertFalse(a.guarded());
    }

    @Test
    void fallbackDropsAdviceFromTheModel() {
        var a = new FallbackAssistant(fixed("You should buy SILK now."), template, new AdviceGuard())
                .answer(new Assistant.Question("fees?", "en", null), FACTS);
        assertEquals(Assistant.Source.TEMPLATE, a.source());
        assertTrue(a.guarded());
    }

    @Test
    void fallbackAnswersWhenTheModelFailsOrIsAbsent() {
        Assistant broken = (q, f) -> { throw new IllegalStateException("503"); };
        assertEquals(Assistant.Source.TEMPLATE, new FallbackAssistant(broken, template, new AdviceGuard())
                .answer(new Assistant.Question("итог?", "ru", null), FACTS).source());
        assertEquals(Assistant.Source.TEMPLATE, new FallbackAssistant(null, template, new AdviceGuard())
                .answer(new Assistant.Question("итог?", "ru", null), FACTS).source());
    }

    @Test
    void anAdviceQuestionNeverReachesTheModel() {
        Assistant model = (q, f) -> { throw new AssertionError("model must not be called"); };
        var a = new FallbackAssistant(model, template, new AdviceGuard())
                .answer(new Assistant.Question("Что мне купить?", "ru", null), FACTS);
        assertTrue(a.guarded());
        assertTrue(a.text().startsWith("Я не говорю, что покупать или продавать"), a.text());
    }
}
