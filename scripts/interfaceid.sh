#!/bin/bash

# SMART Protocol Interface ID Calculator
# This script calculates ERC165 interface IDs for all interfaces starting with capital "I"
# Uses Foundry/Forge for compilation and interface ID calculation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/subgraph/src/erc165/utils"
OUTPUT_FILE="$OUTPUT_DIR/interfaceids.ts"
TEMP_CONTRACT="$PROJECT_ROOT/temp_interface_calc.sol"

# Cleanup function
cleanup() {
    echo -e "${YELLOW}🧹 Cleaning up temporary files...${NC}"
    rm -f "$TEMP_CONTRACT" 2>/dev/null || true
    rm -f "$PROJECT_ROOT/temp_single_calc.sol" 2>/dev/null || true
}

# Set trap to cleanup on exit (success or failure)
# trap cleanup EXIT  # Temporarily disabled for debugging

echo -e "${BLUE}🔍 SMART Protocol Interface ID Calculator${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""

# Change to project root
cd "$PROJECT_ROOT"

# Check if forge is available
if ! command -v forge &> /dev/null; then
    echo -e "${RED}❌ Error: Foundry/Forge is not installed or not in PATH${NC}"
    echo "Please install Foundry: https://book.getfoundry.sh/getting-started/installation"
    exit 1
fi

echo -e "${GREEN}✅ Foundry/Forge found${NC}"

# Find all interface files starting with "I"
echo -e "${YELLOW}🔎 Searching for interface files...${NC}"

# Use find to locate all .sol files and grep to filter interfaces starting with "I"
INTERFACE_FILES=$(find contracts -name "I*.sol" -type f | sort)

if [ -z "$INTERFACE_FILES" ]; then
    echo -e "${RED}❌ No interface files starting with 'I' found${NC}"
    exit 1
fi

echo -e "${GREEN}📁 Found interface files:${NC}"
echo "$INTERFACE_FILES" | while read -r file; do
    echo "  - $file"
done
echo ""

# Extract interface names from files
echo -e "${YELLOW}📋 Extracting interface names...${NC}"
INTERFACE_NAMES=()
INTERFACE_IMPORTS=()

while IFS= read -r file; do
    # Extract interface name from file path (remove .sol extension and get basename)
    interface_name=$(basename "$file" .sol)

    # Skip if not starting with I (double check)
    if [[ ! "$interface_name" =~ ^I[A-Z] ]]; then
        continue
    fi

    # Check if the file actually contains an interface declaration
    if grep -q "^interface $interface_name" "$file"; then
        INTERFACE_NAMES+=("$interface_name")
        # Convert file path to import path (keep the full path from contracts/)
        import_path="./$file"
        INTERFACE_IMPORTS+=("import { $interface_name } from \"$import_path\";")
        echo "  ✓ $interface_name"
    fi
done <<< "$INTERFACE_FILES"

if [ ${#INTERFACE_NAMES[@]} -eq 0 ]; then
    echo -e "${RED}❌ No valid interfaces found${NC}"
    exit 1
fi

echo -e "${GREEN}📊 Found ${#INTERFACE_NAMES[@]} interfaces${NC}"
echo ""

# Compile the contracts first
echo -e "${YELLOW}🔨 Compiling contracts...${NC}"
if ! forge build --silent; then
    echo -e "${RED}❌ Compilation failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Compilation successful${NC}"

# Create a dynamic Solidity contract to calculate interface IDs
echo -e "${YELLOW}📝 Creating dynamic interface ID calculator...${NC}"

cat > "$TEMP_CONTRACT" << EOF
// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "forge-std/console.sol";

// Import all discovered interfaces
EOF

# Add all interface imports
for import_line in "${INTERFACE_IMPORTS[@]}"; do
    echo "$import_line" >> "$TEMP_CONTRACT"
done

# Add the contract
cat >> "$TEMP_CONTRACT" << 'EOF'

contract InterfaceIdCalculator is Script {
    function run() external {
        console.log("=== SMART Protocol Interface IDs ===");
        console.log("");

EOF

# Add console.log statements for each interface
for interface_name in "${INTERFACE_NAMES[@]}"; do
    echo "        console.log(\"$interface_name: %s\", vm.toString(bytes4(type($interface_name).interfaceId)));" >> "$TEMP_CONTRACT"
done

# Add TypeScript format section
cat >> "$TEMP_CONTRACT" << 'EOF'

        console.log("");
        console.log("=== TypeScript Format ===");
        console.log("export class InterfaceIds {");
EOF

# Add TypeScript static properties for each interface
for i in "${!INTERFACE_NAMES[@]}"; do
    interface_name="${INTERFACE_NAMES[$i]}"
    if [ $i -eq $((${#INTERFACE_NAMES[@]} - 1)) ]; then
        # Last item, no comma
        echo "        console.log('  static $interface_name: Bytes = Bytes.fromHexString(\"%s\");', vm.toString(bytes4(type($interface_name).interfaceId)));" >> "$TEMP_CONTRACT"
    else
        echo "        console.log('  static $interface_name: Bytes = Bytes.fromHexString(\"%s\");', vm.toString(bytes4(type($interface_name).interfaceId)));" >> "$TEMP_CONTRACT"
    fi
done

cat >> "$TEMP_CONTRACT" << 'EOF'
        console.log("}");
    }
}
EOF

echo -e "${GREEN}✅ Dynamic interface ID calculator created${NC}"

# Run the script to calculate interface IDs
echo -e "${YELLOW}⚡ Calculating interface IDs...${NC}"
echo ""

# Run the forge script and capture output
SCRIPT_OUTPUT=$(forge script "$TEMP_CONTRACT:InterfaceIdCalculator" 2>&1 || echo "")

if [ -z "$SCRIPT_OUTPUT" ]; then
    echo -e "${RED}❌ Failed to calculate interface IDs${NC}"
    exit 1
fi

# Display the interface IDs (truncated to 4 bytes)
echo "$SCRIPT_OUTPUT" | grep -A 1000 "=== SMART Protocol Interface IDs ===" | grep -B 1000 "=== TypeScript Format ===" | sed 's/0x\([0-9a-fA-F]\{8\}\)[0-9a-fA-F]*/0x\1/g'

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Extract and save TypeScript
TS_START_LINE=$(echo "$SCRIPT_OUTPUT" | grep -n "=== TypeScript Format ===" | cut -d: -f1)
if [ -n "$TS_START_LINE" ]; then
    # Extract everything after "=== TypeScript Format ===" and before any other section, truncate to 4 bytes
    TS_CONTENT=$(echo "$SCRIPT_OUTPUT" | tail -n +$((TS_START_LINE + 1)) | sed '/^$/,$d' | sed 's/0x\([0-9a-fA-F]\{8\}\)[0-9a-fA-F]*/0x\1/g')

        # Add header comment to TypeScript file
    cat > "$OUTPUT_FILE" << EOF
/**
 * ERC165 Interface IDs for SMART Protocol
 * 
 * This file is auto-generated by scripts/interfaceid.sh
 * Do not edit manually - run 'npm run compile:forge' to regenerate
 * 
 * Generated on: $(date)
 */

import { Bytes } from "@graphprotocol/graph-ts";

EOF

    echo "$TS_CONTENT" >> "$OUTPUT_FILE"

    echo ""
    echo -e "${GREEN}✅ Interface IDs saved to: $OUTPUT_FILE${NC}"
    echo ""
    echo -e "${BLUE}📄 TypeScript Output:${NC}"
    echo "$TS_CONTENT"
fi

echo -e "${GREEN}✅ Interface ID calculation completed successfully!${NC}"
echo ""
echo -e "${BLUE}📋 Summary:${NC}"
echo "  - Found and processed ${#INTERFACE_NAMES[@]} interfaces starting with 'I'"
echo "  - Calculated ERC165 interface IDs using Foundry/Forge"
echo "  - Results saved to: $OUTPUT_FILE"
echo ""
echo -e "${YELLOW}💡 Usage:${NC}"
echo "  - Import the InterfaceIds class in your TypeScript code"
echo "  - Use InterfaceIds.INTERFACE_NAME to get the interface ID"
echo "  - Example: InterfaceIds.ISMART"
