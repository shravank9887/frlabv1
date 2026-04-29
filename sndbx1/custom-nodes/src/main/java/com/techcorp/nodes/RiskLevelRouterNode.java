package com.techcorp.nodes;

import java.util.List;

import jakarta.inject.Inject;

import org.forgerock.json.JsonValue;
import org.forgerock.openam.annotations.sm.Attribute;
import org.forgerock.openam.auth.node.api.Action;
import org.forgerock.openam.auth.node.api.Node;
import org.forgerock.openam.auth.node.api.NodeProcessException;
import org.forgerock.openam.auth.node.api.OutcomeProvider;
import org.forgerock.openam.auth.node.api.TreeContext;
import org.forgerock.util.i18n.PreferredLocales;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.assistedinject.Assisted;

/**
 * Node 3: RiskLevelRouterNode
 *
 * Implements Node directly with a 4-outcome OutcomeProvider: low, medium, high, error.
 * This is the most complex node pattern — multi-outcome routing with configurable
 * thresholds and session property writing.
 *
 * Concepts demonstrated:
 * - Custom multi-outcome OutcomeProvider (4 outcomes)
 * - Reading from shared state (riskScore set by upstream Scripted Decision)
 * - Configurable thresholds (admin tunes without code changes)
 * - putSessionProperty() — writes data into the AM session for policy evaluation
 * - Action.goTo(outcomeId) — dynamic routing based on data
 * - Error handling outcome (riskScore not found)
 *
 * Interview value: "Risk router with 4 outcomes integrated with our risk engine.
 * Low risk went straight through, medium required TOTP, high was blocked.
 * Security team tuned thresholds in the tree designer — no code changes needed."
 */
@Node.Metadata(
    outcomeProvider = RiskLevelRouterNode.RiskOutcomeProvider.class,
    configClass = RiskLevelRouterNode.Config.class,
    tags = {"risk"},
    i18nFile = "com/techcorp/nodes/RiskLevelRouterNode"
)
public class RiskLevelRouterNode implements Node {

    private static final Logger logger = LoggerFactory.getLogger(RiskLevelRouterNode.class);

    private static final String LOW = "low";
    private static final String MEDIUM = "medium";
    private static final String HIGH = "high";
    private static final String ERROR = "error";

    /**
     * Config — thresholds and the shared state key to read.
     *
     * riskScoreKey: the shared state key where upstream nodes store the score (default: "riskScore")
     * mediumThreshold: scores >= this value are "medium" (default: 30)
     * highThreshold: scores >= this value are "high" (default: 70)
     *
     * So: 0-29 = low, 30-69 = medium, 70-100 = high
     */
    public interface Config {

        @Attribute(order = 100)
        default String riskScoreKey() {
            return "riskScore";
        }

        @Attribute(order = 200)
        default int mediumThreshold() {
            return 30;
        }

        @Attribute(order = 300)
        default int highThreshold() {
            return 70;
        }
    }

    private final Config config;

    @Inject
    public RiskLevelRouterNode(@Assisted Config config) {
        this.config = config;
    }

    /**
     * process() — reads riskScore from shared state, routes to the appropriate outcome.
     *
     * Key API points:
     * - context.sharedState.get(key) returns JsonValue (may be null/undefined)
     * - JsonValue.isNull() checks if the value exists
     * - putSessionProperty(key, value) writes to the AM session — available to policies
     *   and downstream applications via session validation/introspection
     */
    @Override
    public Action process(TreeContext context) throws NodeProcessException {
        String key = config.riskScoreKey();
        JsonValue scoreValue = context.sharedState.get(key);

        // If riskScore not in shared state, route to error outcome
        if (scoreValue == null || scoreValue.isNull()) {
            logger.warn("RiskLevelRouterNode: '{}' not found in shared state", key);
            return Action.goTo(ERROR).build();
        }

        int score;
        try {
            score = scoreValue.asInteger();
        } catch (Exception e) {
            logger.warn("RiskLevelRouterNode: '{}' is not a valid integer: {}", key, scoreValue);
            return Action.goTo(ERROR).build();
        }

        // Determine risk level based on configurable thresholds
        String riskLevel;
        if (score >= config.highThreshold()) {
            riskLevel = HIGH;
        } else if (score >= config.mediumThreshold()) {
            riskLevel = MEDIUM;
        } else {
            riskLevel = LOW;
        }

        logger.debug("RiskLevelRouterNode: score={} mediumThreshold={} highThreshold={} result={}",
                score, config.mediumThreshold(), config.highThreshold(), riskLevel);

        // putSessionProperty writes into the AM session — downstream policies can read it
        return Action.goTo(riskLevel)
                .putSessionProperty("riskLevel", riskLevel)
                .putSessionProperty("riskScore", String.valueOf(score))
                .build();
    }

    /**
     * 4-outcome provider — AM renders 4 exit connections in the tree designer.
     * Each outcome gets a colored connector the admin can wire to different nodes.
     */
    public static class RiskOutcomeProvider implements OutcomeProvider {
        @Override
        public List<Outcome> getOutcomes(PreferredLocales locales, JsonValue nodeAttributes) {
            return List.of(
                new Outcome(LOW, "Low Risk"),
                new Outcome(MEDIUM, "Medium Risk"),
                new Outcome(HIGH, "High Risk"),
                new Outcome(ERROR, "Error")
            );
        }
    }
}
