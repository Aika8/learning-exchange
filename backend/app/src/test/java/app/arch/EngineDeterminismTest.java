package app.arch;

import static com.tngtech.archunit.core.domain.JavaCall.Predicates.target;
import static com.tngtech.archunit.core.domain.properties.HasName.Predicates.nameStartingWith;
import static com.tngtech.archunit.core.domain.properties.HasOwner.Predicates.With.owner;
import static com.tngtech.archunit.core.domain.JavaClass.Predicates.assignableTo;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;

import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Random;

/**
 * CLAUDE.md: the engine is deterministic — the same commands give the same events. So it never reads the wall clock,
 * never draws unseeded randomness, does no I/O and knows no framework. Time reaches the engine only as data
 * (e.g. {@code Event.ClockChanged}).
 */
@AnalyzeClasses(packages = "engine", importOptions = ImportOption.DoNotIncludeTests.class)
class EngineDeterminismTest {

    @ArchTest
    static final ArchRule engineNeverReadsTheWallClock = noClasses().that().resideInAPackage("engine..")
            .should().callMethod(Instant.class, "now")
            .orShould().callMethod(LocalDate.class, "now")
            .orShould().callMethod(LocalDateTime.class, "now")
            .orShould().callMethodWhere(target(owner(assignableTo(Clock.class))).and(target(nameStartingWith("system"))))
            .orShould().callMethod(System.class, "currentTimeMillis")
            .orShould().callMethod(System.class, "nanoTime")
            .because("time must come in as data, or replaying the journal gives different results");

    @ArchTest
    static final ArchRule engineNeverUsesUnseededRandom = noClasses().that().resideInAPackage("engine..")
            .should().callConstructor(Random.class)
            .because("new Random() seeds itself from the clock; use new Random(seed) if randomness is ever needed");

    @ArchTest
    static final ArchRule engineDoesNoIoAndKnowsNoFramework = noClasses().that().resideInAPackage("engine..")
            .should().dependOnClassesThat().resideInAnyPackage(
                    "java.io..", "java.nio.file..", "java.net..", "org.springframework..")
            .because("the engine is pure: adapters do I/O, the engine only computes");
}
