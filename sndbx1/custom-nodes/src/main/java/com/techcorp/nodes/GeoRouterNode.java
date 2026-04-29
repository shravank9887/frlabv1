package com.techcorp.nodes;

import java.util.List;
import java.util.Set;

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

// outcomeProvider points to OUR OWN GeoOutcomeProvider — not a built-in one.
// This is the key difference from AbstractDecisionNode and SingleOutcomeNode.
@Node.Metadata(
    outcomeProvider = GeoRouterNode.GeoOutcomeProvider.class,
    configClass = GeoRouterNode.Config.class,
    tags = {"risk"},
    i18nFile = "com/techcorp/nodes/GeoRouterNode"
)
// implements Node directly — no AbstractDecisionNode, no SingleOutcomeNode.
// No goTo(boolean) or goToNext(). We use Action.goTo("outcomeId") for everything.
public class GeoRouterNode implements Node {

    private static final Logger logger = LoggerFactory.getLogger(GeoRouterNode.class);

    // Outcome IDs — these MUST match exactly what GeoOutcomeProvider returns.
    // "Domestic" won't match "domestic" — case sensitive.
    private static final String DOMESTIC = "domestic";
    private static final String INTERNATIONAL = "international";
    private static final String BLOCKED = "blocked";
    private static final String UNKNOWN = "unknown";

    public interface Config {
        // Which shared state key holds the country code?
        // Upstream node (Scripted Decision, HeaderCheckNode) must set this.
        @Attribute(order = 100)
        default String countryCodeKey() { return "countryCode"; }

        // Country codes considered "home" — go straight through
        @Attribute(order = 200)
        Set<String> domesticCountries();

        // Country codes to block entirely
        @Attribute(order = 300)
        Set<String> blockedCountries();
    }

    private final Config config;

    @Inject
    public GeoRouterNode(@Assisted Config config) {
        this.config = config;
    }

    @Override
    public Action process(TreeContext context) throws NodeProcessException {
        String key = config.countryCodeKey();
        JsonValue countryValue = context.sharedState.get(key);

        // If countryCode not in shared state → unknown
        if (countryValue == null || countryValue.isNull()) {
            logger.warn("GeoRouterNode: '{}' not found in shared state", key);
            return Action.goTo(UNKNOWN).build();
        }

        String country = countryValue.asString().toUpperCase();

        // Check blocked first — deny takes priority over allow
        if (config.blockedCountries().contains(country)) {
            logger.info("GeoRouterNode: country={} → BLOCKED", country);
            return Action.goTo(BLOCKED).build();
        }

        // Check domestic
        if (config.domesticCountries().contains(country)) {
            logger.debug("GeoRouterNode: country={} → domestic", country);
            return Action.goTo(DOMESTIC).build();
        }

        // Everything else is international
        logger.debug("GeoRouterNode: country={} → international", country);
        return Action.goTo(INTERNATIONAL).build();
    }

    /**
     * Custom OutcomeProvider — defines the 4 exit connections in the tree designer.
     * AM calls getOutcomes() to render the node's connectors.
     * Each Outcome id must match what Action.goTo() uses above.
     */
    public static class GeoOutcomeProvider implements OutcomeProvider {
        @Override
        public List<Outcome> getOutcomes(PreferredLocales locales, JsonValue nodeAttributes) {
            return List.of(
                new Outcome(DOMESTIC, "Domestic"),
                new Outcome(INTERNATIONAL, "International"),
                new Outcome(BLOCKED, "Blocked"),
                new Outcome(UNKNOWN, "Unknown")
            );
        }
    }
}
