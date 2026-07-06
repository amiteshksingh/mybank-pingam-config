#!/bin/bash

set -e

###############################################################################
# Script Name : export-script.sh
# Purpose     : Export all PingAM scripts using Frodo and extract source files
#               into JavaScript / Groovy folders for Git-based code management.
#
# Usage:
#   ./frodo/export/export-script.sh <frodo-profile> [realm]
#
# Example:
#   ./frodo/export/export-script.sh dev /
#   ./frodo/export/export-script.sh dev customers
#
###############################################################################

PROFILE="${1:?Profile required}"
REALM="${2:-/}"

BASE_DIR="/home/mydir/mybank-pingam-config/scripts/decision-node"

EXPORT_DIR="${BASE_DIR}/exported"
JS_DIR="${BASE_DIR}/source/JavaScript"
GROOVY_DIR="${BASE_DIR}/source/Groovy"

mkdir -p "${EXPORT_DIR}"
mkdir -p "${JS_DIR}"
mkdir -p "${GROOVY_DIR}"

echo "======================================"
echo "Exporting all PingAM scripts"
echo "======================================"

# Clean previous exports
rm -f "${EXPORT_DIR}"/*
rm -f "${JS_DIR}"/*
rm -f "${GROOVY_DIR}"/*

# Export ALL scripts with source extraction
frodo script export \
    -A \
    -x \
    -D "${EXPORT_DIR}" \
    "${PROFILE}" \
    "${REALM}"

echo ""
echo "Moving extracted source files..."
echo ""

#
# JavaScript Files
#
for FILE in "${EXPORT_DIR}"/*.script.js
do

    [ -f "$FILE" ] || continue

    BASENAME=$(basename "$FILE" .script.js)

    mv "$FILE" "${JS_DIR}/${BASENAME}.js"

    echo "JS --> ${BASENAME}.js"

done

#
# Groovy Files
#
for FILE in "${EXPORT_DIR}"/*.script.groovy
do

    [ -f "$FILE" ] || continue

    BASENAME=$(basename "$FILE" .script.groovy)

    mv "$FILE" "${GROOVY_DIR}/${BASENAME}.groovy"

    echo "Groovy --> ${BASENAME}.groovy"

done

echo ""
echo "======================================"
echo "Completed"
echo "======================================"

echo ""
echo "Exported JSON:"
echo "    ${EXPORT_DIR}"

echo ""
echo "JavaScript Source:"
echo "    ${JS_DIR}"

echo ""
echo "Groovy Source:"
echo "    ${GROOVY_DIR}"