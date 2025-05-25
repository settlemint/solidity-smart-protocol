#!/bin/bash

set -e

# Validate arguments
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 --local|--remote"
    exit 1
fi

DEPLOY_ENV=""
if [ "$1" == "--local" ]; then
    DEPLOY_ENV="local"
elif [ "$1" == "--remote" ]; then
    DEPLOY_ENV="remote"
else
    echo "Error: Invalid argument. Use --local or --remote."
    echo "Usage: $0 --local|--remote"
    exit 1
fi

echo
echo "---"
echo "Deployment environment: $DEPLOY_ENV"

# Function to restore original addresses
restore_addresses() {
    SYSTEM_FACTORY_ADDRESS="0x5e771e1417100000000000000000000000020088"
    yq -i "(.dataSources[] | select(.name == \"SystemFactory\").source.address) = \"$SYSTEM_FACTORY_ADDRESS\"" ./subgraph/subgraph.yaml
    echo "Original addresses restored."
}

trap restore_addresses EXIT

# Read the new addresses from deployed_addresses.json
SYSTEM_FACTORY_ADDRESS=$(jq -r '."SystemFactoryModule#SMARTSystemFactory"' ./ignition/deployments/smart-protocol-local/deployed_addresses.json)

# Update the addresses in ./subgraph/subgraph.yaml
yq -i "(.dataSources[] | select(.name == \"SystemFactory\").source.address) = \"$SYSTEM_FACTORY_ADDRESS\"" ./subgraph/subgraph.yaml

# Print addresses for debugging
echo "---"
echo "Addresses being used:"
echo "  SMARTSystemFactory: $SYSTEM_FACTORY_ADDRESS"
echo "---"
echo

if [ "$DEPLOY_ENV" == "local" ]; then
npx graph create --node http://localhost:8020 smart
npx graph deploy --version-label v1.0.$(date +%s) --node http://localhost:8020 --ipfs https://ipfs.console.settlemint.com smart ./subgraph/subgraph.yaml
elif [ "$DEPLOY_ENV" == "remote" ]; then
npx settlemint scs subgraph deploy
fi