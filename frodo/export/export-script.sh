#!/bin/bash

set -euo pipefail

###############################################################################
# Script Name  : export-script.sh
# Purpose      : Export PingAM scripts using Frodo for Git-based configuration
#                management.
#
# Supports     :
#   1. Export all scripts
#   2. Export single script
#   3. Mandatory cleanup for all-script export
#   4. Optional cleanup for single-script export
#   5. Separation of Frodo importable JSON artifacts and reviewable source code
#
# Repository Layout:
#
#   /home/mydir/mybank-pingam-config/scripts/decision-node
#      ├── exported
#      │     ├── ScriptName.script.json
#      │
#      └── source
#            ├── JavaScript
#            │     ├── ScriptName.js
#            │
#            └── Groovy
#                  ├── ScriptName.groovy
#
# Usage:
#
#   Show help:
#     ./export-script.sh --help
#
#   Export all scripts:
#     ./export-script.sh mybank /alpha all
#
#   Export all scripts with explicit cleanup flag:
#     ./export-script.sh mybank /alpha all --cleanup
#
#   Export single script:
#     ./export-script.sh mybank /alpha AuditLoggingFailure
#
#   Export single script with cleanup:
#     ./export-script.sh mybank /alpha AuditLoggingFailure --cleanup
#
# Notes:
#   - For "all" exports, cleanup is always performed automatically.
#   - For single script export, cleanup is performed only when --cleanup is used.
#   - Git does not track timestamps. It tracks content, file name, and file mode.
#   - Re-exporting identical content will not create Git changes.
###############################################################################

###############################################################################
# Configuration
###############################################################################

BASE_DIR="/home/mydir/mybank-pingam-config/scripts/decision-node"

EXPORT_DIR="${BASE_DIR}/exported"
SOURCE_DIR="${BASE_DIR}/source"
JS_DIR="${SOURCE_DIR}/JavaScript"
GROOVY_DIR="${SOURCE_DIR}/Groovy"

###############################################################################
# Logger Functions
###############################################################################

log_info() {
  echo "[INFO]  $1"
}

log_warn() {
  echo "[WARN]  $1"
}

log_error() {
  echo "[ERROR] $1"
}

log_success() {
  echo "[OK]    $1"
}

print_separator() {
  echo "---------------------------------------------------------------------"
}

###############################################################################
# Usage
###############################################################################

print_usage() {
  cat <<EOF

Usage:

  ./export-script.sh <profile> <realm> <all|script-name> [--cleanup]

Examples:

  Export all scripts:
    ./export-script.sh mybank /alpha all

  Export all scripts with explicit cleanup flag:
    ./export-script.sh mybank /alpha all --cleanup

  Export one script:
    ./export-script.sh mybank /alpha AuditLoggingFailure

  Export one script with cleanup:
    ./export-script.sh mybank /alpha AuditLoggingFailure --cleanup

Arguments:

  profile
    Frodo connection profile name.
    Example: mybank

  realm
    PingAM realm.
    Example: /alpha
    Example: /

  all|script-name
    Use "all" to export all scripts.
    Use script name to export only one script.

  --cleanup
    Optional for single script export.
    Mandatory and automatic for all-script export.

Output:

  Frodo importable JSON files:
    ${EXPORT_DIR}

  JavaScript source files:
    ${JS_DIR}

  Groovy source files:
    ${GROOVY_DIR}

EOF
}

###############################################################################
# Initial Usage Guidance
###############################################################################

print_usage

###############################################################################
# Argument Parsing
###############################################################################

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  exit 0
fi

PROFILE="${1:-}"
REALM="${2:-}"
TARGET="${3:-}"
CLEANUP_FLAG="${4:-}"

if [[ -z "${PROFILE}" || -z "${REALM}" || -z "${TARGET}" ]]; then
  log_error "Missing required arguments."
  print_usage
  exit 1
fi

if [[ -n "${CLEANUP_FLAG}" && "${CLEANUP_FLAG}" != "--cleanup" ]]; then
  log_error "Invalid optional argument: ${CLEANUP_FLAG}"
  print_usage
  exit 1
fi

if [[ "${TARGET}" == "all" ]]; then
  MODE="ALL"
  CLEANUP="true"
else
  MODE="SINGLE"
  SCRIPT_NAME="${TARGET}"

  if [[ "${CLEANUP_FLAG}" == "--cleanup" ]]; then
    CLEANUP="true"
  else
    CLEANUP="false"
  fi
fi

###############################################################################
# Pre-Checks
###############################################################################

if ! command -v frodo >/dev/null 2>&1; then
  log_error "frodo command not found. Please install/configure Frodo first."
  exit 1
fi

mkdir -p "${EXPORT_DIR}"
mkdir -p "${JS_DIR}"
mkdir -p "${GROOVY_DIR}"

###############################################################################
# Runtime Summary
###############################################################################

print_separator
log_info "PingAM Script Export Started"
print_separator
log_info "Profile        : ${PROFILE}"
log_info "Realm          : ${REALM}"
log_info "Mode           : ${MODE}"

if [[ "${MODE}" == "SINGLE" ]]; then
  log_info "Script Name    : ${SCRIPT_NAME}"
fi

log_info "Cleanup        : ${CLEANUP}"
log_info "Exported JSON  : ${EXPORT_DIR}"
log_info "JavaScript Src : ${JS_DIR}"
log_info "Groovy Src     : ${GROOVY_DIR}"
print_separator

###############################################################################
# Cleanup Functions
###############################################################################

cleanup_all_scripts() {
  log_warn "Cleaning up all previously exported scripts and source files."

  find "${EXPORT_DIR}" -type f \
    \( -name "*.script.json" -o -name "*.script.js" -o -name "*.script.groovy" \) \
    -delete

  find "${JS_DIR}" -type f -name "*.js" -delete
  find "${GROOVY_DIR}" -type f -name "*.groovy" -delete

  log_success "All script artifacts cleaned."
}

cleanup_single_script() {
  local script_name="$1"

  log_warn "Cleaning up artifacts for single script: ${script_name}"

  rm -f "${EXPORT_DIR}/${script_name}.script.json"
  rm -f "${EXPORT_DIR}/${script_name}.script.js"
  rm -f "${EXPORT_DIR}/${script_name}.script.groovy"

  rm -f "${JS_DIR}/${script_name}.js"
  rm -f "${GROOVY_DIR}/${script_name}.groovy"

  log_success "Single script artifacts cleaned: ${script_name}"
}

###############################################################################
# Cleanup Execution
###############################################################################

if [[ "${MODE}" == "ALL" ]]; then
  log_info "All-script export selected. Cleanup is mandatory."
  cleanup_all_scripts
else
  if [[ "${CLEANUP}" == "true" ]]; then
    cleanup_single_script "${SCRIPT_NAME}"
  else
    log_info "Single-script export selected without cleanup."
  fi
fi

###############################################################################
# Export Functions
###############################################################################

export_all_scripts() {
  log_info "Exporting all scripts from PingAM using Frodo."

  frodo script export \
    -A \
    -x \
    -D "${EXPORT_DIR}" \
    "${PROFILE}" \
    "${REALM}"

  log_success "All scripts exported successfully."
}

export_single_script() {
  local script_name="$1"

  log_info "Exporting single script using Frodo: ${script_name}"

  frodo script export \
    -n "${script_name}" \
    -x \
    -D "${EXPORT_DIR}" \
    "${PROFILE}" \
    "${REALM}"

  log_success "Single script exported successfully: ${script_name}"
}

###############################################################################
# Move Extracted Source Files
###############################################################################

move_javascript_sources() {
  log_info "Moving JavaScript source files."

  local count=0

  while IFS= read -r file; do
    local base_name
    local target_file

    base_name="$(basename "${file}" .script.js)"
    target_file="${JS_DIR}/${base_name}.js"

    mv "${file}" "${target_file}"

    log_success "JavaScript source created: ${target_file}"
    count=$((count + 1))
  done < <(find "${EXPORT_DIR}" -maxdepth 1 -type f -name "*.script.js" | sort)

  if [[ "${count}" -eq 0 ]]; then
    log_info "No JavaScript source files found to move."
  fi
}

move_groovy_sources() {
  log_info "Moving Groovy source files."

  local count=0

  while IFS= read -r file; do
    local base_name
    local target_file

    base_name="$(basename "${file}" .script.groovy)"
    target_file="${GROOVY_DIR}/${base_name}.groovy"

    mv "${file}" "${target_file}"

    log_success "Groovy source created: ${target_file}"
    count=$((count + 1))
  done < <(find "${EXPORT_DIR}" -maxdepth 1 -type f -name "*.script.groovy" | sort)

  if [[ "${count}" -eq 0 ]]; then
    log_info "No Groovy source files found to move."
  fi
}

###############################################################################
# Export Execution
###############################################################################

if [[ "${MODE}" == "ALL" ]]; then
  export_all_scripts
else
  export_single_script "${SCRIPT_NAME}"
fi

###############################################################################
# Move Sources
###############################################################################

move_javascript_sources
move_groovy_sources

###############################################################################
# Summary
###############################################################################

JSON_COUNT="$(find "${EXPORT_DIR}" -maxdepth 1 -type f -name "*.script.json" | wc -l)"
JS_COUNT="$(find "${JS_DIR}" -maxdepth 1 -type f -name "*.js" | wc -l)"
GROOVY_COUNT="$(find "${GROOVY_DIR}" -maxdepth 1 -type f -name "*.groovy" | wc -l)"

print_separator
log_success "PingAM Script Export Completed"
print_separator
log_info "JSON artifacts count      : ${JSON_COUNT}"
log_info "JavaScript source count   : ${JS_COUNT}"
log_info "Groovy source count       : ${GROOVY_COUNT}"
print_separator

log_info "Next Git commands:"
echo ""
echo "  cd /home/mydir/mybank-pingam-config"
echo "  git status"
echo "  git add scripts/decision-node"
echo "  git commit -m \"export PingAM scripts using Frodo\""
echo "  git push"
echo ""

exit 0