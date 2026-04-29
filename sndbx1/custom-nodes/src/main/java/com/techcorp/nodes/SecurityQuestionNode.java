package com.techcorp.nodes;

import jakarta.inject.Inject;

// IMPORTANT: Callbacks use javax.security.auth.callback — NOT jakarta.
// This is the old JAAS API which never migrated to Jakarta EE.
// This is the ONE place where javax is correct in PingAM 8.
import javax.security.auth.callback.NameCallback;
import javax.security.auth.callback.TextOutputCallback;

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
 * SecurityQuestionNode — demonstrates the CALLBACK pattern.
 *
 * HOW CALLBACKS WORK:
 * ==================
 * Unlike previous nodes where process() runs once and makes a decision,
 * a callback node's process() runs TWICE:
 *
 *   PASS 1 (no callbacks):
 *     → Node sends callbacks (question + input field) to the user's browser
 *     → AM serializes callbacks into JSON and returns them in the REST response
 *     → User sees the question, types an answer, submits
 *
 *   PASS 2 (has callbacks):
 *     → AM calls process() again with the user's response attached
 *     → Node reads the answer from the callback
 *     → Makes a decision and routes to true/false
 *
 * You detect which pass with: context.hasCallbacks()
 *   false → PASS 1, send the question
 *   true  → PASS 2, read the answer
 *
 * CALLBACK TYPES AVAILABLE:
 * ========================
 * - NameCallback        → text input field (user types text)
 * - PasswordCallback    → password input field (masked characters)
 * - TextOutputCallback  → display-only text (information, warning, error)
 * - ChoiceCallback      → multiple choice selection
 * - ConfirmationCallback → yes/no/cancel buttons
 * - HiddenValueCallback → hidden field (pass data without showing user)
 *
 * All from javax.security.auth.callback (JAAS API).
 */
@Node.Metadata(
    outcomeProvider = AbstractDecisionNode.OutcomeProvider.class,
    configClass = SecurityQuestionNode.Config.class,
    tags = {"utilities"},
    i18nFile = "com/techcorp/nodes/SecurityQuestionNode"
)
public class SecurityQuestionNode extends AbstractDecisionNode {

    private static final Logger logger = LoggerFactory.getLogger(SecurityQuestionNode.class);

    /**
     * Config:
     * - question: The text displayed to the user (the security question)
     * - expectedAnswerKey: Which shared state key holds the correct answer.
     *   An upstream node (Scripted Decision, Profile Lookup) must set this
     *   in shared state before this node runs.
     */
    public interface Config {

        @Attribute(order = 100)
        default String question() {
            return "What is your mother's maiden name?";
        }

        @Attribute(order = 200)
        default String expectedAnswerKey() {
            return "securityAnswer";
        }
    }

    private final Config config;

    @Inject
    public SecurityQuestionNode(@Assisted Config config) {
        this.config = config;
    }

    @Override
    public Action process(TreeContext context) throws NodeProcessException {

        // ============================================================
        // PASS 2: User has submitted their answer
        // ============================================================
        // context.hasCallbacks() returns true when the user has responded
        // to the callbacks we sent in Pass 1.
        if (context.hasCallbacks()) {

            // context.getCallback(Type.class) returns Optional<Type>
            // .get() unwraps the Optional (safe here — we know we sent a NameCallback)
            // .getName() returns the text the user typed
            String userAnswer = context.getCallback(NameCallback.class)
                    .get()
                    .getName();

            // Read the expected answer from shared state
            // An upstream node must have set this key (e.g., a Scripted Decision
            // that looked up the user's security answer from their profile)
            String expected = context.sharedState.get(config.expectedAnswerKey()).asString();

            // Case-insensitive comparison — "Smith" matches "smith"
            boolean correct = userAnswer != null
                    && expected != null
                    && userAnswer.equalsIgnoreCase(expected);

            logger.debug("SecurityQuestionNode: userAnswer={} expected={} correct={}",
                    userAnswer, expected, correct);

            // goTo(true) → "true" outcome (correct answer)
            // goTo(false) → "false" outcome (wrong answer)
            return goTo(correct).build();
        }

        // ============================================================
        // PASS 1: No callbacks yet — send the question to the user
        // ============================================================

        // TextOutputCallback — displays read-only text to the user.
        // First arg is the message type:
        //   TextOutputCallback.INFORMATION = 0 (normal text)
        //   TextOutputCallback.WARNING = 1 (warning text)
        //   TextOutputCallback.ERROR = 2 (error text)
        // Second arg is the message text (our configurable question).
        TextOutputCallback prompt = new TextOutputCallback(
                TextOutputCallback.INFORMATION,
                config.question()
        );

        // NameCallback — creates a text input field.
        // The constructor arg ("Answer") is the prompt/label for the input field.
        // After the user types and submits, getName() returns what they typed.
        NameCallback answerCallback = new NameCallback("Answer");

        // Action.send(callbacks...) pauses the tree and sends callbacks to the user.
        // AM serializes these into JSON in the REST response.
        // The user's browser renders them as a form.
        // When the user submits, AM calls process() again (Pass 2).
        return Action.send(prompt, answerCallback).build();
    }
}
