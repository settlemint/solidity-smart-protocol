#!/bin/bash

# Define file paths (adjust version if needed)
ONCHAINID_DIR="dependencies/@onchainid-v2.2.1"
AUTH_FILE="${ONCHAINID_DIR}/contracts/proxy/ImplementationAuthority.sol"
IDENTITY_FILE="${ONCHAINID_DIR}/contracts/Identity.sol"
OS_TYPE=$(uname)
# TEMP_IDENTITY_FILE="tmp_identity.sol" # No longer needed for sed approach

echo "Patching @onchainid contracts..."

# --- Update Pragmas for all .sol files in the @onchainid dependency directory ---
echo "Ensuring pragmas are updated for all sol files in ${ONCHAINID_DIR}..."
if [[ -d "$ONCHAINID_DIR" ]]; then
  if [[ "$OS_TYPE" == "Darwin" ]]; then
    find "$ONCHAINID_DIR" -name '*.sol' -type f -exec sed -i '' 's/pragma solidity 0\.8/pragma solidity ^0\.8/g' {} +
  else
    find "$ONCHAINID_DIR" -name '*.sol' -type f -exec sed -i 's/pragma solidity 0\.8/pragma solidity ^0\.8/g' {} +
  fi
  echo "Pragma update complete for ${ONCHAINID_DIR}."
else
  echo "Warning: Directory ${ONCHAINID_DIR} not found. Skipping pragma update."
fi

# 1. Patch ImplementationAuthority.sol: Add Ownable(msg.sender)
#    This assumes the constructor does not already have Ownable(msg.sender)
echo "Checking ImplementationAuthority constructor..."
if [[ -f "$AUTH_FILE" ]]; then
  if ! grep -q "constructor(address implementation) Ownable(msg.sender)" "$AUTH_FILE"; then
    echo "Patching ImplementationAuthority constructor..."
    if [[ "$OS_TYPE" == "Darwin" ]]; then
      sed -i '' 's/constructor(address implementation) {/constructor(address implementation) Ownable(msg.sender) {/' "$AUTH_FILE"
    else
      sed -i 's/constructor(address implementation) {/constructor(address implementation) Ownable(msg.sender) {/' "$AUTH_FILE"
    fi
    echo "Patched ImplementationAuthority constructor."
  else
    echo "ImplementationAuthority constructor already correct."
  fi
else
  echo "Warning: File ${AUTH_FILE} not found. Skipping patch."
fi

# 2. Patch Identity.sol: Move the require statement inside the if (!_isLibrary) block using simple sed
echo "Checking Identity.sol constructor..."
if [[ -f "$IDENTITY_FILE" ]]; then
  # Find the line number of the *first* standalone require statement (if it exists)
  STANDALONE_REQUIRE_LINE_NUM=$(grep -n -E '^\s*require\(initialManagementKey != address\(0\),.*\);' "$IDENTITY_FILE" | cut -d: -f1 | head -n 1)

  # Assume patch is not needed initially
  NEEDS_PATCH="no"
  REQUIRE_LINE_CONTENT=""
  INSERT_TEXT=""

  if [[ -n "$STANDALONE_REQUIRE_LINE_NUM" ]]; then
    # Check the line *before* the found require statement
    PREV_LINE_NUM=$((STANDALONE_REQUIRE_LINE_NUM - 1))
    PREV_LINE_CONTENT=$(sed -n "${PREV_LINE_NUM}p" "$IDENTITY_FILE")

    # If the previous line is NOT the start of the `if (!_isLibrary) {` block, then we need to patch
    if ! echo "$PREV_LINE_CONTENT" | grep -q -E '^\s*if \(!_isLibrary\) \{'; then
      NEEDS_PATCH="yes"
      # Get the exact content of the require line to re-insert
      REQUIRE_LINE_CONTENT=$(sed -n "${STANDALONE_REQUIRE_LINE_NUM}p" "$IDENTITY_FILE")
      # Trim leading whitespace and add desired indentation for insertion
      CORE_REQUIRE=$(echo "$REQUIRE_LINE_CONTENT" | sed 's/^[ \t]*//')
      INSERT_TEXT="    ${CORE_REQUIRE}" # Add 4 spaces indentation
    fi
  fi

  if [[ "$NEEDS_PATCH" == "no" ]]; then
    echo "Identity.sol constructor already correct or standalone require not found."
  else
    echo "Patching Identity.sol constructor..."

    # 1. Delete the standalone require line by its number
    if [[ "$OS_TYPE" == "Darwin" ]]; then
      sed -i '' "${STANDALONE_REQUIRE_LINE_NUM}d" "$IDENTITY_FILE"
    else
      sed -i "${STANDALONE_REQUIRE_LINE_NUM}d" "$IDENTITY_FILE"
    fi
    echo "Deleted standalone require line (former line ${STANDALONE_REQUIRE_LINE_NUM})."

    # 2. Insert the require line after the 'if (!_isLibrary) {' line
    #    Find the line number of the 'if' statement *after* deletion
    IF_LINE_NUM=$(grep -n -E '^\s*if \(!_isLibrary\) \{' "$IDENTITY_FILE" | cut -d: -f1)

    if [[ -n "$IF_LINE_NUM" ]]; then
      if [[ "$OS_TYPE" == "Darwin" ]]; then
        # macOS sed 'a' command needs newline escaped and uses line number
        # The weird $ EOL syntax is needed for sed -i on mac to interpret newline
        sed -i '' "${IF_LINE_NUM}"' a\
'"${INSERT_TEXT}" "$IDENTITY_FILE"
      else
        # Linux sed 'a' command uses line number
        sed -i "${IF_LINE_NUM}a ${INSERT_TEXT}" "$IDENTITY_FILE"
      fi
      echo "Inserted require line after line ${IF_LINE_NUM}."
      echo "Patched Identity.sol constructor."
    else
      echo "Error: Could not find 'if (!_isLibrary) {' line to insert after. Patch is incomplete."
      # Consider adding logic here to revert the deletion if needed, or exit with error
    fi
  fi
else
  echo "Warning: File ${IDENTITY_FILE} not found. Skipping patch."
fi

echo "Patching complete."
