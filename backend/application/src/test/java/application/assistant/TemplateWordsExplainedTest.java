package application.assistant;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

/** LE-089: the template answers say what "spread" and the summary's result mean, in ru and en, without advice. */
class TemplateWordsExplainedTest {

    static final Facts FACTS = Facts.builder()
            .add("statement.fees", 78, Facts.Kind.MONEY)
            .add("statement.spreadPaid", 75, Facts.Kind.MONEY)
            .add("statement.tax", 0, Facts.Kind.MONEY)
            .add("review.orders", 3, Facts.Kind.COUNT)
            .add("review.wins", 1, Facts.Kind.COUNT)
            .add("review.result", -84, Facts.Kind.MONEY)
            .build();

    final TemplateAssistant template = new TemplateAssistant();

    private Assistant.Answer ask(String text, String lang) {
        return template.answer(new Assistant.Question(text, lang, null), FACTS);
    }

    @Test
    void costsAnswerExplainsSpreadInRussian() {
        String t = ask("Что такое спред и почему я теряю деньги сразу после покупки?", "ru").text();
        assertTrue(t.contains("0.78 SPARK комиссий и около 0.75 SPARK спреда; налог с прибыли — 0.00 SPARK."), t);
        assertTrue(t.contains("Спред — разница между лучшей ценой покупки и продажи; "
                + "здесь — сколько вы отдали против середины между ними."), t);
        assertFalse(new AdviceGuard().isAdvice(t), t);
    }

    @Test
    void costsAnswerExplainsSpreadInEnglish() {
        String t = ask("What is the spread?", "en").text();
        assertTrue(t.contains("0.78 SPARK in fees and about 0.75 SPARK in spread"), t);
        assertTrue(t.contains("The spread is the gap between the best buy and sell prices; "
                + "here, how much you gave up against the middle between them."), t);
        assertFalse(new AdviceGuard().isAdvice(t), t);
    }

    @Test
    void summarySaysWhatTheResultIsMeasuredAgainstInRussian() {
        String t = ask("Как прошла сессия?", "ru").text();
        assertTrue(t.contains("3 заявок, 1 в плюсе; результат, если бы всё закрыть по последней цене, −0.84 SPARK."), t);
        assertTrue(t.contains("Спред — разница"), t);
        assertFalse(new AdviceGuard().isAdvice(t), t);
    }

    @Test
    void summarySaysWhatTheResultIsMeasuredAgainstInEnglish() {
        String t = ask("How did the session go?", "en").text();
        assertTrue(t.contains("3 orders, 1 in profit; the result if everything were closed at the last price is −0.84 SPARK."), t);
        assertTrue(t.contains("The spread is the gap"), t);
        assertFalse(new AdviceGuard().isAdvice(t), t);
    }
}
