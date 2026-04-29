package com.techcorp.nodes;

import java.util.List;
import java.util.Map;
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

/**
 * Node 2: HeaderCheckNode
 *
 * Implements Node directly (not AbstractDecisionNode or SingleOutcomeNode)
 * with a custom OutcomeProvider for two outcomes: "found" and "missing".
 *
 * Concepts demonstrated:
 * - Reading HTTP headers from ExternalRequestContext
 * - Writing values into shared state (state enrichment pattern)
 * - Custom OutcomeProvider with named outcomes
 * - Action.goTo(outcomeId) for routing
 * - replaceSharedState() to pass data to downstream nodes
 * - Set<String> config attribute (multi-value header list)
 *
 * Interview value: "Header enrichment node — captures client IP, device info,
 * and custom headers from the API gateway into shared state. Downstream nodes
 * (risk scoring, audit) consume this data without needing their own HTTP access."
 */
@Node.Metadata(
    outcomeProvider = HeaderCheckNode.HeaderOutcomeProvider.class,
    configClass = HeaderCheckNode.Config.class,
    tags = {"utilities"},
    i18nFile = "com/techcorp/nodes/HeaderCheckNode"
)
public class HeaderCheckNode implements Node {

    private static final Logger logger = LoggerFactory.getLogger(HeaderCheckNode.class);

    private static final String FOUND = "found";
    private static final String MISSING = "missing";

    /**
     * Config — admin configures which headers to capture and which are required.
     *
     * headersToCapture: set of header names to read (e.g., X-Forwarded-For, User-Agent)
     * requiredHeaders: subset that MUST be present — if any is missing, routes to "missing"
     */
    public interface Config {

        @Attribute(order = 100)
        Set<String> headersToCapture();

        @Attribute(order = 200)
        Set<String> requiredHeaders();
    }

    private final Config config;

    @Inject
    public HeaderCheckNode(@Assisted Config config) {
        this.config = config;
    }

    /**
     * process() — reads configured headers from the HTTP request and stores
     * them in shared state with prefix "header_" (e.g., header_X-Forwarded-For).
     *
     * Key API points:
     * - context.request.headers is a ListMultimap<String, String> (case-sensitive keys)
     * - context.sharedState is a JsonValue (immutable) — we copy, modify, and replaceSharedState()
     * - Action.goTo("found") routes to the named outcome
     */
    @Override
    public Action process(TreeContext context) throws NodeProcessException {
        JsonValue newSharedState = context.sharedState.copy();

        // Always capture client IP from the request context
        String clientIp = context.request.clientIp;
        newSharedState.put("clientIp", clientIp);
        logger.debug("HeaderCheckNode: clientIp={}", clientIp);

        // Read each configured header
        for (String headerName : config.headersToCapture()) {
            List<String> values = context.request.headers.get(headerName);
            if (values != null && !values.isEmpty()) {
                String value = values.get(0);
                newSharedState.put("header_" + headerName, value);
                logger.debug("HeaderCheckNode: {}={}", headerName, value);
            }
        }

        // Check required headers — if any is missing, route to "missing"
        for (String required : config.requiredHeaders()) {
            List<String> values = context.request.headers.get(required);
            if (values == null || values.isEmpty()) {
                logger.warn("HeaderCheckNode: required header '{}' is missing", required);
                return Action.goTo(MISSING).replaceSharedState(newSharedState).build();
            }
        }

        return Action.goTo(FOUND).replaceSharedState(newSharedState).build();
    }

    /**
     * Custom OutcomeProvider — defines the outcomes that appear in the tree designer.
     * AM calls getOutcomes() to render the node's exit connections.
     *
     * Each Outcome has an id (used in Action.goTo) and a displayName (shown in UI).
     */
    public static class HeaderOutcomeProvider implements OutcomeProvider {
        @Override
        public List<Outcome> getOutcomes(PreferredLocales locales, JsonValue nodeAttributes) {
            return List.of(
                new Outcome(FOUND, "Found"),
                new Outcome(MISSING, "Missing")
            );
        }
    }
}
