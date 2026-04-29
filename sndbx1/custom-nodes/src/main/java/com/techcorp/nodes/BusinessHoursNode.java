package com.techcorp.nodes;

import java.time.LocalTime;
import java.time.ZoneId;

import jakarta.inject.Inject;

import org.forgerock.openam.annotations.sm.Attribute;
import org.forgerock.openam.auth.node.api.AbstractDecisionNode;
import org.forgerock.openam.auth.node.api.Action;
import org.forgerock.openam.auth.node.api.Node;
import org.forgerock.openam.auth.node.api.NodeProcessException;
import org.forgerock.openam.auth.node.api.TreeContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.assistedinject.Assisted;

/**
 * Node 1: BusinessHoursNode
 *
 * Extends AbstractDecisionNode — the simplest multi-outcome node type.
 * AbstractDecisionNode provides two outcomes: "true" and "false".
 * The goTo(boolean) helper method routes to the matching outcome.
 *
 * Concepts demonstrated:
 * - @Node.Metadata annotation (registers the node with AM)
 * - Config interface with @Attribute (admin-configurable properties)
 * - Enum config attribute (timezone picker in the tree designer UI)
 * - @Inject + @Assisted constructor (Guice dependency injection)
 * - goTo(true/false) routing
 */
@Node.Metadata(
    outcomeProvider = AbstractDecisionNode.OutcomeProvider.class,
    configClass = BusinessHoursNode.Config.class,
    tags = {"risk"},
    i18nFile = "com/techcorp/nodes/BusinessHoursNode"
)
public class BusinessHoursNode extends AbstractDecisionNode {

    private static final Logger logger = LoggerFactory.getLogger(BusinessHoursNode.class);

    /**
     * Config interface — each method becomes a configurable property in the
     * tree designer. AM reads @Attribute(order) to determine UI display order.
     * Methods with "default" return values are optional; without default they're required.
     */
    public interface Config {

        @Attribute(order = 100)
        default int startHour() {
            return 9;
        }

        @Attribute(order = 200)
        default int endHour() {
            return 18;
        }

        @Attribute(order = 300)
        default Timezone timezone() {
            return Timezone.IST;
        }
    }

    /**
     * Enum for timezone selection — AM renders this as a dropdown in the UI.
     * Each enum constant maps to a Java ZoneId.
     */
    public enum Timezone {
        IST("Asia/Kolkata"),
        UTC("UTC"),
        EST("America/New_York"),
        PST("America/Los_Angeles");

        private final String zoneId;

        Timezone(String zoneId) {
            this.zoneId = zoneId;
        }

        public ZoneId toZoneId() {
            return ZoneId.of(zoneId);
        }
    }

    private final Config config;

    /**
     * Constructor — Guice injects the Config.
     * @Assisted tells Guice this is a per-instance config (each node in a tree
     * can have different config values).
     */
    @Inject
    public BusinessHoursNode(@Assisted Config config) {
        this.config = config;
    }

    /**
     * process() — called each time a user hits this node during authentication.
     *
     * @param context TreeContext gives access to:
     *   - context.sharedState   (JsonValue — non-sensitive data shared between nodes)
     *   - context.transientState (JsonValue — sensitive data, cleared after tree)
     *   - context.request        (ExternalRequestContext — HTTP headers, cookies, IP)
     *   - context.getCallback()  (user interaction callbacks)
     *
     * @return Action — controls where the tree goes next.
     *   goTo(true)  → routes to the "true" outcome
     *   goTo(false) → routes to the "false" outcome
     */
    @Override
    public Action process(TreeContext context) throws NodeProcessException {
        ZoneId zone = config.timezone().toZoneId();
        LocalTime now = LocalTime.now(zone);
        int currentHour = now.getHour();

        boolean withinBusinessHours = currentHour >= config.startHour()
                                   && currentHour < config.endHour();

        logger.debug("BusinessHoursNode: time={} zone={} start={} end={} result={}",
                now, zone, config.startHour(), config.endHour(), withinBusinessHours);

        return goTo(withinBusinessHours).build();
    }
}
