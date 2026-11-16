package application.assistant;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

/** The guard that keeps buy/sell advice out of the assistant's answers (ADR-0013). */
class AdviceGuardTest {

    private final AdviceGuard guard = new AdviceGuard();

    @ParameterizedTest
    @ValueSource(strings = {
            "Купите SILK, пока дёшево.",
            "Продай FORGE до отчёта.",
            "Вам стоит купить облигации.",
            "Я рекомендую продать позицию.",
            "Советую вложить в фонд.",
            "You should buy SILK now.",
            "I recommend selling FORGE.",
            "Consider buying the index fund.",
            "Sell now before the report.",
            "Buy SILK. It is cheap.",
            "That is a strong buy signal."})
    void rejectsAdvice(String text) {
        assertTrue(guard.isAdvice(text), text);
    }

    @ParameterizedTest
    @ValueSource(strings = {
            "Вы купили 10 SILK и заплатили 1.20 SPARK комиссии.",
            "Покупки FOMO дали в среднем −1.40 R.",
            "You bought 10 SILK and paid 1.20 SPARK in fees.",
            "Your sell orders filled at 101.00 on average.",
            "The buyer pays the spread.",
            "ЦБ установил ставку 9.00% при консенсусе 8.50%: сюрприз +0.50%."})
    void letsFactsThrough(String text) {
        assertFalse(guard.isAdvice(text), text);
    }

    @ParameterizedTest
    @ValueSource(strings = {"Что мне купить?", "Стоит ли продавать FORGE?", "Should I buy SILK?", "what to sell today"})
    void recognisesQuestionsAskingForAdvice(String q) {
        assertTrue(guard.asksForAdvice(q), q);
    }

    @ParameterizedTest
    @ValueSource(strings = {"Что изменилось против ожиданий?", "How much did I pay in fees?", "Почему я купил FORGE в минус?"})
    void ordinaryQuestionsAreNotAdviceRequests(String q) {
        assertFalse(guard.asksForAdvice(q), q);
    }
}
