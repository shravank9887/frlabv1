#!/bin/bash
# Deploy custom nodes JAR to PingAM container
# Usage: ./deploy.sh
#
# What this does:
# 1. Copies the built JAR into pingam's WEB-INF/lib/
# 2. You then need to restart pingam for AM to pick up the new nodes
#
# After restart, nodes appear in AM Console > Authentication > Trees > Components panel

set -e

JAR_NAME="techcorp-custom-nodes-1.0.0.jar"
JAR_PATH="target/${JAR_NAME}"
DEPLOY_PATH="/usr/local/tomcat/webapps/am/WEB-INF/lib/"

if [ ! -f "$JAR_PATH" ]; then
    echo "ERROR: $JAR_PATH not found. Run 'mvn clean package' first."
    exit 1
fi

echo "Deploying ${JAR_NAME} to pingam container..."
MSYS_NO_PATHCONV=1 docker.exe cp "$JAR_PATH" "pingam:${DEPLOY_PATH}"

echo ""
echo "JAR deployed successfully."
echo ""
echo "Next steps:"
echo "  1. Restart PingAM:  docker.exe restart pingam"
echo "  2. Wait for AM to start (~30-60s)"
echo "  3. Open AM Console: http://localhost:8081/am/console"
echo "  4. Go to: Authentication > Trees > select a tree"
echo "  5. Look for BusinessHoursNode, HeaderCheckNode, RiskLevelRouterNode in Components"
