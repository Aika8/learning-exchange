package app.bff;

import java.io.IOException;
import java.io.Reader;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.yaml.snakeyaml.LoaderOptions;
import org.yaml.snakeyaml.Yaml;
import org.yaml.snakeyaml.constructor.SafeConstructor;

/**
 * Reference data for the BFFs (ADR-0012): instrument names ({@code docs/lore/catalogue.yaml}) and the concept glossary
 * ({@code docs/lore/glossary.yaml}), each with real and lore names in ru and en. Loaded once at start.
 */
public final class Catalogue {

    public record Name(String ru, String en) {}

    public record Item(String instrument, String kind, Name real, Name lore) {}

    public record Term(String id, Name real, Name lore, Name definition) {}

    private final List<Item> items = new ArrayList<>();
    private final List<Term> terms = new ArrayList<>();

    public Catalogue(Path catalogue, Path glossary) {
        for (Map<String, Object> m : list(load(catalogue), "instruments")) {
            items.add(new Item((String) m.get("id"), (String) m.get("kind"), name(m, "real"), name(m, "lore")));
        }
        for (Map<String, Object> m : list(load(glossary), "terms")) {
            terms.add(new Term((String) m.get("id"), name(m, "real"), name(m, "lore"), name(m, "definition")));
        }
    }

    public List<Item> items() {
        return List.copyOf(items);
    }

    public List<Term> terms() {
        return List.copyOf(terms);
    }

    public java.util.Optional<Item> item(String instrument) {
        return items.stream().filter(i -> i.instrument().equals(instrument)).findFirst();
    }

    private static Map<String, Object> load(Path file) {
        try (Reader r = Files.newBufferedReader(file, StandardCharsets.UTF_8)) {
            return new Yaml(new SafeConstructor(new LoaderOptions())).load(r);
        } catch (IOException e) {
            throw new UncheckedIOException("cannot read " + file, e);
        }
    }

    @SuppressWarnings("unchecked")
    private static List<Map<String, Object>> list(Map<String, Object> root, String key) {
        return (List<Map<String, Object>>) root.get(key);
    }

    @SuppressWarnings("unchecked")
    private static Name name(Map<String, Object> m, String key) {
        Map<String, Object> n = (Map<String, Object>) m.get(key);
        return n == null ? null : new Name((String) n.get("ru"), (String) n.get("en"));
    }
}
