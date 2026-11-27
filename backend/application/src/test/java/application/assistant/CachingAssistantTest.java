package application.assistant;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import org.junit.jupiter.api.Test;

class CachingAssistantTest {

    static final class CountingAssistant implements Assistant {
        int calls;
        boolean guarded;

        @Override
        public Answer answer(Question question, Facts facts) {
            calls++;
            return new Answer("answer " + calls, Source.TEMPLATE, null, Assistant.disclaimer(question.lang()), guarded,
                    List.of());
        }
    }

    static Facts fees(long fees) {
        return Facts.builder().add("statement.fees", fees, Facts.Kind.MONEY).build();
    }

    static Assistant.Question q(String text) {
        return new Assistant.Question(text, "ru", null);
    }

    @Test
    void secondIdenticalQuestionDoesNotReachTheDelegate() {
        var delegate = new CountingAssistant();
        var cache = new CachingAssistant(delegate);
        var first = cache.answer("acc-1", q("Сколько я заплатил комиссий?"), fees(120));
        var second = cache.answer("acc-1", q("  сколько я заплатил КОМИССИЙ?  "), fees(120));
        assertEquals(1, delegate.calls);
        assertSame(first, second);
    }

    @Test
    void differentFactsReachTheDelegateAgain() {
        var delegate = new CountingAssistant();
        var cache = new CachingAssistant(delegate);
        cache.answer("acc-1", q("fees?"), fees(120));
        var changed = cache.answer("acc-1", q("fees?"), fees(121));
        assertEquals(2, delegate.calls);
        assertEquals("answer 2", changed.text());
    }

    @Test
    void accountLanguageAndPersonaArePartOfTheKey() {
        var delegate = new CountingAssistant();
        var cache = new CachingAssistant(delegate);
        cache.answer("acc-1", q("fees?"), fees(120));
        cache.answer("acc-2", q("fees?"), fees(120));
        cache.answer("acc-1", new Assistant.Question("fees?", "en", null), fees(120));
        cache.answer("acc-1", new Assistant.Question("fees?", "ru", Assistant.Persona.CHRONICLER), fees(120));
        assertEquals(4, delegate.calls);
        cache.forAccount("acc-2").answer(q("fees?"), fees(120));
        assertEquals(4, delegate.calls);
    }

    @Test
    void leastRecentlyUsedEntryIsEvictedAfterTheBound() {
        var delegate = new CountingAssistant();
        var cache = new CachingAssistant(delegate, 2);
        cache.answer("acc", q("a"), fees(1));
        cache.answer("acc", q("b"), fees(1));
        cache.answer("acc", q("a"), fees(1)); // hit: "a" becomes most recent
        cache.answer("acc", q("c"), fees(1)); // evicts "b"
        assertEquals(3, delegate.calls);
        assertEquals(2, cache.size());
        cache.answer("acc", q("a"), fees(1));
        assertEquals(3, delegate.calls);
        cache.answer("acc", q("b"), fees(1));
        assertEquals(4, delegate.calls);
    }

    @Test
    void guardedAnswersAreCachedToo() {
        var delegate = new CountingAssistant();
        delegate.guarded = true;
        var cache = new CachingAssistant(delegate);
        var first = cache.answer("acc", q("что купить?"), fees(1));
        var second = cache.answer("acc", q("что купить?"), fees(1));
        assertTrue(first.guarded());
        assertSame(first, second);
        assertEquals(1, delegate.calls);
    }
}
