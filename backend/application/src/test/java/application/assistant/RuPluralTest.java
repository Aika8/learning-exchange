package application.assistant;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

class RuPluralTest {

    @ParameterizedTest
    @CsvSource({
            "0, заявок", "1, заявка", "2, заявки", "4, заявки", "5, заявок", "11, заявок", "12, заявок",
            "14, заявок", "21, заявка", "22, заявки", "25, заявок", "101, заявка", "111, заявок"})
    void picksTheForm(long n, String expected) {
        assertEquals(expected, RuPlural.of(n, "заявка", "заявки", "заявок"));
    }

    @ParameterizedTest
    @CsvSource({"1, 1 заявка", "3, 3 заявки", "5, 5 заявок", "21, 21 заявка"})
    void summaryCountsOrdersInRussian(long orders, String expected) {
        Facts facts = Facts.builder().add("review.orders", orders, Facts.Kind.COUNT)
                .add("review.wins", 0, Facts.Kind.COUNT).add("review.result", 0, Facts.Kind.MONEY).build();
        var a = new TemplateAssistant().answer(new Assistant.Question("Как прошла сессия?", "ru", null), facts);
        assertTrue(a.text().contains(expected + ","), a.text());
    }

    @ParameterizedTest
    @CsvSource({"3", "5"})
    void englishIsUnchanged(long orders) {
        Facts facts = Facts.builder().add("review.orders", orders, Facts.Kind.COUNT)
                .add("review.wins", 0, Facts.Kind.COUNT).add("review.result", 0, Facts.Kind.MONEY).build();
        var a = new TemplateAssistant().answer(new Assistant.Question("How did the session go?", "en", null), facts);
        assertTrue(a.text().contains(orders + " orders, "), a.text());
    }
}
