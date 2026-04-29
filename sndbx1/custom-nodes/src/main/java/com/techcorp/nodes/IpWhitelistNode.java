package com.techcorp.nodes;
import java.util.Set;
import jakarta.inject.Inject;
import org.forgerock.openam.annotations.sm.Attribute;
import org.forgerock.openam.auth.node.api.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import com.google.inject.assistedinject.Assisted;

@Node.Metadata(
      outcomeProvider = AbstractDecisionNode.OutcomeProvider.class,
      configClass = IpWhitelistNode.Config.class,
      tags = {"risk"},
      i18nFile = "com/techcorp/nodes/IpWhitelistNode"
)
public class IpWhitelistNode extends AbstractDecisionNode {
    
    public interface Config {
        @Attribute(order = 100)
        Set<String> allowedIps();

        @Attribute(order = 200)
        default boolean checkXForwardedFor() { return true; }
    }   

    private final Config config;
    private static final Logger logger = LoggerFactory.getLogger(IpWhitelistNode.class);

    @Inject
    public IpWhitelistNode(@Assisted Config config) {
          this.config = config;
      }

    @Override
    public Action process(TreeContext context) throws NodeProcessException {
          String clientIp = context.request.clientIp;

        if (config.checkXForwardedFor()) {
            var xff = context.request.headers.get("X-Forwarded-For");
            if (xff != null && !xff.isEmpty()) {
                clientIp = xff.get(0).split(",")[0].trim();
            }
        }

        boolean allowed = config.allowedIps().contains(clientIp);
        logger.debug("IpWhitelistNode: ip={} allowed={}", clientIp, allowed);
        return goTo(allowed).build();
    }

}
