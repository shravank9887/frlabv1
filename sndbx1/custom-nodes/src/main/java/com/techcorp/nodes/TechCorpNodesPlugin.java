package com.techcorp.nodes;

import java.util.Collections;
import java.util.List;
import java.util.Map;

import org.forgerock.openam.auth.node.api.AbstractNodeAmPlugin;
import org.forgerock.openam.auth.node.api.Node;

/**
 * Plugin class — registers custom nodes with AM's plugin framework.
 *
 * How it works:
 * 1. AM scans META-INF/services/org.forgerock.openam.plugins.AmPlugin at startup
 * 2. Finds this class listed in that file
 * 3. Calls getNodesByVersion() to register all node classes
 * 4. Nodes appear in the Components panel of the tree designer
 *
 * getNodesByVersion() maps version strings to node classes.
 * When you add new nodes in a future version, add a new entry like:
 *   "1.1.0" -> List.of(NewNode.class)
 * AM will call upgrade() for existing installs.
 */
public class TechCorpNodesPlugin extends AbstractNodeAmPlugin {

    private static final String CURRENT_VERSION = "1.4.0";

    @Override
    protected Map<String, Iterable<? extends Class<? extends Node>>> getNodesByVersion() {
        return Map.of(
            "1.0.0", List.of(
                BusinessHoursNode.class,
                HeaderCheckNode.class,
                RiskLevelRouterNode.class
            ),
            "1.1.0", List.of(
                IpWhitelistNode.class
            ),
            "1.2.0", List.of(
                AuditLogNode.class
            ),
            "1.3.0", List.of(
                GeoRouterNode.class
            ),
            "1.4.0", List.of(
                SecurityQuestionNode.class
            )
        );
    }

    @Override
    public String getPluginVersion() {
        return CURRENT_VERSION;
    }
}
