package app.arch;

import static com.tngtech.archunit.base.DescribedPredicate.describe;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noFields;

import com.tngtech.archunit.core.domain.JavaField;
import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;
import java.math.BigDecimal;
import java.util.Map;

/**
 * CLAUDE.md: money and prices are integer minor units ({@code long}), never {@code double}. A field (a record
 * component is one too) whose name says it holds money must not be a floating-point or decimal type in the engine
 * or the application layer. Local variables in a ratio computation (e.g. {@code BondMath}) are not fields and are
 * not checked.
 */
@AnalyzeClasses(packages = {"engine", "application"}, importOptions = ImportOption.DoNotIncludeTests.class)
class MoneyTypesTest {

    /** Money-sounding names, case-insensitive. */
    private static final String MONEY_NAME = "(?i).*(price|amount|balance|fee|cash|qty|money).*";

    /**
     * Fields that hold a ratio, not money, though their name matches: "Owner.fullName" → one-line reason.
     * Empty: no such field exists today (see DECISIONS.md, LE-014).
     */
    private static final Map<String, String> RATIO_ALLOW_LIST = Map.of();

    @ArchTest
    static final ArchRule moneyIsNeverFloatingPoint = noFields()
            .that().areDeclaredInClassesThat().resideInAnyPackage("engine..", "application..")
            .and().haveNameMatching(MONEY_NAME)
            .and(describe("are not on the ratio allow-list",
                    (JavaField f) -> !RATIO_ALLOW_LIST.containsKey(f.getOwner().getName() + "." + f.getName())))
            .should().haveRawType(double.class)
            .orShould().haveRawType(float.class)
            .orShould().haveRawType(Double.class)
            .orShould().haveRawType(Float.class)
            .orShould().haveRawType(BigDecimal.class)
            .because("money and prices are integer minor units (long): a double rounds, and rounding loses money");
}
