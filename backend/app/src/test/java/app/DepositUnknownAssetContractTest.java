package app;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import tools.jackson.databind.JsonNode;

/**
 * A deposit of an asset no instrument trades (a real currency a newcomer knows, say USD) is refused with
 * {@code UNKNOWN_INSTRUMENT} instead of leaving a balance nothing can buy or sell. Assets the market trades still go in.
 * Its own context (another economy seed): the inherited tests, run once more in the shared context, would spend its
 * dealer's money.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = {"exchange.journal=memory", "exchange.bots-enabled=false", "exchange.economy-seed=9"})
class DepositUnknownAssetContractTest extends ContractTest {

    @Test
    void depositOfAnUntradedAssetIsRefusedAndLeavesNoBalance() throws Exception {
        String token = call("POST", "/auth/dev-login", null, "{\"name\":\"usd newcomer\"}", 200, "LoginResponse").get("token").asString();

        JsonNode problem = call("POST", "/me/deposits", token, "{\"asset\":\"USD\",\"amount\":100}", 404, "Problem");
        assertEquals("UNKNOWN_INSTRUMENT", problem.get("code").asString());

        JsonNode me = call("GET", "/me", token, null, 200, "AccountDetails");
        for (JsonNode b : me.get("balances")) {
            assertFalse("USD".equals(b.get("asset").asString()), me.toString());
        }
    }

    @Test
    void depositsOfTradedAssetsStillGoIn() throws Exception {
        String token = call("POST", "/auth/dev-login", null, "{\"name\":\"known assets\"}", 200, "LoginResponse").get("token").asString();
        for (String asset : new String[] {"SPARK", "SILK", "FORGE", "HBND"}) {
            JsonNode me = call("POST", "/me/deposits", token, "{\"asset\":\"" + asset + "\",\"amount\":100}", 200, "AccountDetails");
            boolean found = false;
            for (JsonNode b : me.get("balances")) {
                found |= asset.equals(b.get("asset").asString());
            }
            assertTrue(found, asset + " missing in " + me);
        }
    }
}
