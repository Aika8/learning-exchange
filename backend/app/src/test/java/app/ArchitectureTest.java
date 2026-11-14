package app;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;

import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;

/** Dependencies point inward only (ADR-0002): engine ← application ← bots/app. */
@AnalyzeClasses(packages = {"engine", "application", "bots", "app"}, importOptions = ImportOption.DoNotIncludeTests.class)
class ArchitectureTest {

    @ArchTest
    static final ArchRule engineIsFrameworkFreeAndPure = noClasses().that().resideInAPackage("engine..")
            .should().dependOnClassesThat().resideOutsideOfPackages("engine..", "java.lang..", "java.util..");

    @ArchTest
    static final ArchRule engineNeverReadsTheClock = noClasses().that().resideInAPackage("engine..")
            .should().callMethod(java.time.Instant.class, "now")
            .orShould().callMethod(System.class, "currentTimeMillis")
            .orShould().callMethod(System.class, "nanoTime");

    @ArchTest
    static final ArchRule coreKnowsNoAdapters = noClasses().that().resideInAnyPackage("engine..", "application..", "bots..")
            .should().dependOnClassesThat().resideInAnyPackage("app..", "org.springframework..", "tools.jackson..", "com.fasterxml..");

    @ArchTest
    static final ArchRule botsUseOnlyThePort = noClasses().that().resideInAPackage("bots..")
            .should().dependOnClassesThat().haveFullyQualifiedName("engine.Exchange")
            .orShould().dependOnClassesThat().haveFullyQualifiedName("engine.OrderBook")
            .orShould().dependOnClassesThat().haveFullyQualifiedName("application.ExchangeService");
}
