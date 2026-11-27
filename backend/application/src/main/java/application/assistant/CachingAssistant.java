package application.assistant;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;

/**
 * Remembers answers so the same question about the same numbers does not reach the delegate (the LLM) twice. The key
 * is (account id, question text trimmed and lower-cased, language, persona, SHA-256 of {@link Facts#asData()}). There
 * is no time-based expiry: when the account's numbers change, the facts hash changes and so does the key. The size is
 * bounded; the least recently used entry is dropped first. Guarded answers are cached like any other.
 *
 * <p>Pattern: Decorator — adds caching over the port without the LLM or template adapters knowing about it.
 * See docs/adr/0013-assistant-llm-with-fallback.md.
 */
public final class CachingAssistant implements Assistant {

    public static final int DEFAULT_MAX_ENTRIES = 256;

    private final Assistant delegate;
    private final Map<Key, Answer> cache;

    public CachingAssistant(Assistant delegate) {
        this(delegate, DEFAULT_MAX_ENTRIES);
    }

    public CachingAssistant(Assistant delegate, int maxEntries) {
        if (maxEntries < 1) {
            throw new IllegalArgumentException("maxEntries must be at least 1: " + maxEntries);
        }
        this.delegate = delegate;
        this.cache = new LinkedHashMap<>(16, 0.75f, true) {
            @Override
            protected boolean removeEldestEntry(Map.Entry<Key, Answer> eldest) {
                return size() > maxEntries;
            }
        };
    }

    /** The port call without an account: answers are shared under an empty account id. */
    @Override
    public Answer answer(Question question, Facts facts) {
        return answer("", question, facts);
    }

    /** The same cache, keyed by the account the facts were collected for. */
    public Answer answer(String accountId, Question question, Facts facts) {
        Key key = Key.of(accountId, question, facts);
        synchronized (cache) {
            Answer hit = cache.get(key);
            if (hit != null) {
                return hit;
            }
        }
        Answer a = delegate.answer(question, facts);
        if (a != null) {
            synchronized (cache) {
                cache.put(key, a);
            }
        }
        return a;
    }

    /** A view of this cache bound to one account, usable wherever the port is expected. */
    public Assistant forAccount(String accountId) {
        return (question, facts) -> answer(accountId, question, facts);
    }

    /** Number of cached answers. */
    public int size() {
        synchronized (cache) {
            return cache.size();
        }
    }

    record Key(String accountId, String question, String lang, Persona persona, String factsHash) {
        static Key of(String accountId, Question q, Facts facts) {
            String text = q.text() == null ? "" : q.text().trim().toLowerCase(Locale.ROOT);
            return new Key(accountId == null ? "" : accountId, text, q.lang(), q.persona(), hash(facts));
        }

        static String hash(Facts facts) {
            String data = facts == null ? "" : facts.asData();
            try {
                byte[] d = MessageDigest.getInstance("SHA-256").digest(data.getBytes(StandardCharsets.UTF_8));
                return HexFormat.of().formatHex(d);
            } catch (NoSuchAlgorithmException e) {
                throw new IllegalStateException("SHA-256 is required by every JVM", e);
            }
        }
    }
}
