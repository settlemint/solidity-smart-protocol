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

# Validation checks
echo "Performing validation checks..."

# Check if deployed_addresses.json exists and is readable
DEPLOYED_ADDRESSES_FILE="./ignition/deployments/smart-protocol-local/deployed_addresses.json"
if [ ! -f "$DEPLOYED_ADDRESSES_FILE" ]; then
    echo "Error: deployed_addresses.json not found at $DEPLOYED_ADDRESSES_FILE"
    echo "Please ensure the contracts have been deployed first."
    exit 1
fi

if [ ! -r "$DEPLOYED_ADDRESSES_FILE" ]; then
    echo "Error: deployed_addresses.json at $DEPLOYED_ADDRESSES_FILE is not readable"
    echo "Please check file permissions."
    exit 1
fi

# Check if jq command is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq command not found"
    echo "Please install jq to parse JSON files. Visit: https://jqlang.github.io/jq/download/"
    exit 1
fi

# Check if yq command is available
if ! command -v yq &> /dev/null; then
    echo "Error: yq command not found"
    echo "Please install yq to parse YAML files. Visit: https://github.com/mikefarah/yq#install"
    exit 1
fi

echo "All validation checks passed."
echo "---"

# Function to restore original addresses
restore_addresses() {
    SYSTEM_FACTORY_ADDRESS="0x5e771e1417100000000000000000000000020088"
    yq -i "(.dataSources[] | select(.name == \"SystemFactory\").source.address) = \"$SYSTEM_FACTORY_ADDRESS\"" ./subgraph/subgraph.yaml
    echo "Original addresses restored."
}

trap restore_addresses EXIT

# Read the new addresses from deployed_addresses.json
SYSTEM_FACTORY_ADDRESS=$(jq -r '."SystemFactoryModule#SMARTSystemFactory"' "$DEPLOYED_ADDRESSES_FILE")

# Validate that the address was successfully extracted
if [ -z "$SYSTEM_FACTORY_ADDRESS" ] || [ "$SYSTEM_FACTORY_ADDRESS" == "null" ]; then
    echo "Error: Could not extract SystemFactoryModule#SMARTSystemFactory address from $DEPLOYED_ADDRESSES_FILE"
    echo "Please verify that the deployment was successful and the address exists in the file."
    exit 1
fi

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
npx graph deploy --version-label "v1.0.$(date +%s)" --node http://localhost:8020 --ipfs https://ipfs.console.settlemint.com smart ./subgraph/subgraph.yaml
elif [ "$DEPLOY_ENV" == "remote" ]; then
npx settlemint scs subgraph deploy
fi