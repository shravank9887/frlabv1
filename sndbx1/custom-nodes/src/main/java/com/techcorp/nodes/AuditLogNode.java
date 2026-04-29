
  package com.techcorp.nodes;

  import java.time.Instant;
  import jakarta.inject.Inject;
  import org.forgerock.json.JsonValue;
  import org.forgerock.openam.annotations.sm.Attribute;
  import org.forgerock.openam.auth.node.api.*;
  import org.slf4j.Logger;
  import org.slf4j.LoggerFactory;
  import com.google.inject.assistedinject.Assisted;
  //Imports — same as IpWhitelistNode but swap AbstractDecisionNode for SingleOutcomeNode:

  //@Node.Metadata note the outcomeProvider changes to SingleOutcomeNode.OutcomeProvider.class:
  @Node.Metadata(
      outcomeProvider = SingleOutcomeNode.OutcomeProvider.class,
      configClass = AuditLogNode.Config.class,
      tags = {"utilities"},
      i18nFile = "com/techcorp/nodes/AuditLogNode"
  )
  //Class — extends SingleOutcomeNode instead of AbstractDecisionNode:
  public class AuditLogNode extends SingleOutcomeNode {

//   Config interface — two properties:
//   - logPrefix — a configurable string label (e.g., "TechCorpLogin", "AdminPortal") so you can identify which tree this log came from
//   - includeHeaders — boolean toggle to include HTTP headers in the audit log

      public interface Config {
          @Attribute(order = 100)
          default String logPrefix() { return "AUDIT"; }

          @Attribute(order = 200)
          default boolean includeHeaders() { return false; }
      }

//   Constructor — same pattern as before with @Inject and @Assisted.

//   process() method — this is where it differs from AbstractDecisionNode:
//   - Read username from shared state: context.sharedState.get("username")
//   - Read client IP from context.request.clientIp
//   - Optionally read User-Agent header
//   - Log everything with logger.info()
//   - Write an auditTimestamp into shared state for downstream nodes
//   - Return goToNext().build() — not goTo(boolean), since SingleOutcomeNode has only one exit

  private final Config config;
  private static final Logger logger = LoggerFactory.getLogger(AuditLogNode.class);                                                                                                                                                                             
  
   @Inject
   public AuditLogNode(@Assisted Config config) {
      this.config = config;                                                                                                                                                                                                                                  
  }


@Override
      public Action process(TreeContext context) throws NodeProcessException {
          String username = context.sharedState.get("username").asString();
          String clientIp = context.request.clientIp;
          String timestamp = Instant.now().toString();

          StringBuilder logMsg = new StringBuilder();
          logMsg.append(config.logPrefix())
                .append(" | user=").append(username)
                .append(" | ip=").append(clientIp)
                .append(" | time=").append(timestamp);

          if (config.includeHeaders()) {
              var userAgent = context.request.headers.get("User-Agent");
              if (userAgent != null && !userAgent.isEmpty()) {
                  logMsg.append(" | ua=").append(userAgent.get(0));
              }
          }

          logger.info(logMsg.toString());

          // Enrich shared state with audit timestamp
          JsonValue newState = context.sharedState.copy();
          newState.put("auditTimestamp", timestamp);
          return goToNext().replaceSharedState(newState).build();
      }

//   Key difference from IpWhitelistNode:
//   - goToNext() instead of goTo(boolean) — only one exit path
//   - We still use replaceSharedState() to pass the timestamp downstream
    }