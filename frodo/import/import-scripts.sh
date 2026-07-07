#!/bin/bash

set -euo pipefail

###############################################################################
# Script Name:
#   import-scripts.sh
#
# Purpose:
#   Import PingAM script artifacts into a target PingAM realm using Frodo.
#
# Designed For:
#   SABB PingAM 7.5 DevOps / Configuration-as-Code process.
#
# Supports:
#   1. Import all script JSON artifacts from exported folder
#   2. Import a single script
#   3. Import multiple scripts using comma-separated names
#   4. Auto-detect changed script artifacts using Git
#   5. Prompt user to import all changed scripts or review one by one
#   6. Dry-run mode
#   7. Non-interactive yes mode for Jenkins
#   8. Continue-on-error mode
#
# Expected Repository Layout:
#
#   /home/mydir/mybank-pingam-config
#      └── scripts/
#          └── decision-node/
#              └── exported/
#                  ├── AuditLoggingFailure.script.json
#                  ├── DspUtils.script.json
#                  └── reauthPolicy.script.json
#
# Usage:
#
#   Show help:
#     ./import-scripts.sh --help
#
#   Import all scripts:
#     ./import-scripts.sh mybank /alpha all
#
#   Import one script:
#     ./import-scripts.sh mybank /alpha AuditLoggingFailure
#
#   Import multiple scripts:
#     ./import-scripts.sh mybank /alpha AuditLoggingFailure,DspUtils
#
#   Detect changed scripts and prompt:
#     ./import-scripts.sh mybank /alpha changed
#
#   Detect changed scripts and import all without prompt:
#     ./import-scripts.sh mybank /alpha changed --yes
#
#   Dry run:
#     ./import-scripts.sh mybank /alpha changed --dry-run
#
#   Continue on error:
#     ./import-scripts.sh mybank /alpha changed --continue-on-error
#
###############################################################################
# Repository Configuration
###############################################################################

REPO_ROOT="/home/mydir/mybank-pingam-config"

SCRIPT_DIR="${REPO_ROOT}/scripts/decision-node/exported"

JS_DIR="${REPO_ROOT}/scripts/decision-node/source/JavaScript"

GROOVY_DIR="${REPO_ROOT}/scripts/decision-node/source/Groovy"

###############################################################################
# Temporary Import Workspace
###############################################################################

SCRIPT_HOME="$(cd "$(dirname "$0")" && pwd)"

TMP_IMPORT_DIR=""
###############################################################################
# Logger Functions
###############################################################################

timestamp() {
  date "+%Y-%m-%d %H:%M:%S"
}

log_info() {
  echo "[INFO]  [$(timestamp)] $*"
}

log_warn() {
  echo "[WARN]  [$(timestamp)] $*"
}

log_error() {
  echo "[ERROR] [$(timestamp)] $*"
}

log_success() {
  echo "[OK]    [$(timestamp)] $*"
}

separator() {
  echo "---------------------------------------------------------------------"
}

###############################################################################
# Usage
###############################################################################

usage() {
cat <<EOF

Usage:

  ./import-scripts.sh <profile> <realm> <all|changed|script-name|script1,script2> [option]

Modes:

  all
      Import all *.script.json files from:
      ${SCRIPT_DIR}

  changed
      Detect changed *.script.json files using Git and prompt for import.

  script-name
      Import one script.
      Example:
        AuditLoggingFailure

  script1,script2,script3
      Import multiple scripts.
      Example:
        AuditLoggingFailure,DspUtils,reauthPolicy

Options:

  --dry-run
      Show what would be imported. No Frodo import is executed.

  --yes
      Non-interactive mode. With "changed", imports all changed files without prompt.
      Recommended for Jenkins.

  --continue-on-error
      Continue importing remaining files even if one import fails.

  --help | -h
      Show this help.

Examples:

  Import all scripts:
    ./import-scripts.sh mybank /alpha all

  Import one script:
    ./import-scripts.sh mybank /alpha AuditLoggingFailure

  Import multiple scripts:
    ./import-scripts.sh mybank /alpha AuditLoggingFailure,DspUtils

  Detect changed scripts and prompt:
    ./import-scripts.sh mybank /alpha changed

  Detect changed scripts and import all automatically:
    ./import-scripts.sh mybank /alpha changed --yes

  Dry run changed scripts:
    ./import-scripts.sh mybank /alpha changed --dry-run

EOF
}

###############################################################################
# Argument Processing
###############################################################################

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

PROFILE="${1:-}"
REALM="${2:-}"
TARGET="${3:-}"
OPTION="${4:-}"

if [[ -z "${PROFILE}" || -z "${REALM}" || -z "${TARGET}" ]]; then
  log_error "Missing required arguments."
  usage
  exit 1
fi

DRY_RUN="false"
YES_MODE="false"
CONTINUE_ON_ERROR="false"

case "${OPTION}" in
  "")
    ;;
  --dry-run)
    DRY_RUN="true"
    ;;
  --yes)
    YES_MODE="true"
    ;;
  --continue-on-error)
    CONTINUE_ON_ERROR="true"
    ;;
  *)
    log_error "Invalid option: ${OPTION}"
    usage
    exit 1
    ;;
esac

###############################################################################
# Pre-Checks
###############################################################################

if ! command -v frodo >/dev/null 2>&1; then
  log_error "frodo command not found. Please install/configure Frodo first."
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  log_error "git command not found."
  exit 1
fi

if [[ ! -d "${REPO_ROOT}" ]]; then
  log_error "Repository root not found: ${REPO_ROOT}"
  exit 1
fi

if [[ ! -d "${SCRIPT_DIR}" ]]; then
  log_error "Script directory not found: ${SCRIPT_DIR}"
  exit 1
fi

cd "${REPO_ROOT}"

###############################################################################
# Runtime Summary
###############################################################################

separator
log_info "PingAM Script Import Started"
separator
log_info "Profile           : ${PROFILE}"
log_info "Realm             : ${REALM}"
log_info "Target            : ${TARGET}"
log_info "Script Directory  : ${SCRIPT_DIR}"
log_info "Dry Run           : ${DRY_RUN}"
log_info "Yes Mode          : ${YES_MODE}"
log_info "Continue On Error : ${CONTINUE_ON_ERROR}"
separator


###############################################################################
# Cleanup on Exit
###############################################################################
cleanup_workspace() {

    echo "DEBUG: cleanup_workspace called"
    echo "DEBUG: TMP_IMPORT_DIR=${TMP_IMPORT_DIR}"

    if [[ -n "${TMP_IMPORT_DIR:-}" ]] && [[ -d "${TMP_IMPORT_DIR}" ]]
    then

        rm -rf "${TMP_IMPORT_DIR}"

        echo "DEBUG: workspace removed"

    fi
}

trap cleanup_workspace EXIT

###############################################################################
# Create Temporary Import Workspace
###############################################################################
create_temp_workspace() {

    TMP_IMPORT_DIR="${SCRIPT_HOME}/frodo-import-$(date +%Y%m%d_%H%M%S)_$$"

    mkdir -p "${TMP_IMPORT_DIR}"

    log_info "Created temporary workspace:"
    log_info "${TMP_IMPORT_DIR}"
}



###############################################################################
# Build Import Package
###############################################################################
build_import_package() {

    local script_name="$1"

    local json_file="${SCRIPT_DIR}/${script_name}.script.json"

    if [[ ! -f "${json_file}" ]]; then

        log_error "Script JSON not found:"
        log_error "${json_file}"

        return 1

    fi

    #
    # Copy Frodo JSON
    #
    cp "${json_file}" "${TMP_IMPORT_DIR}/"

    #
    # JavaScript
    #
    if [[ -f "${JS_DIR}/${script_name}.js" ]]; then

        cp \
          "${JS_DIR}/${script_name}.js" \
          "${TMP_IMPORT_DIR}/${script_name}.script.js"

    fi

    #
    # Groovy
    #
    if [[ -f "${GROOVY_DIR}/${script_name}.groovy" ]]; then

        cp \
          "${GROOVY_DIR}/${script_name}.groovy" \
          "${TMP_IMPORT_DIR}/${script_name}.script.groovy"

    fi

    #
    # Validation
    #
    if grep -q "file://${script_name}.script.js" \
       "${TMP_IMPORT_DIR}/${script_name}.script.json"
    then

        [[ -f "${TMP_IMPORT_DIR}/${script_name}.script.js" ]] || {

            log_error "Referenced JavaScript file missing."

            return 1

        }

    fi

    if grep -q "file://${script_name}.script.groovy" \
       "${TMP_IMPORT_DIR}/${script_name}.script.json"
    then

        [[ -f "${TMP_IMPORT_DIR}/${script_name}.script.groovy" ]] || {

            log_error "Referenced Groovy file missing."

            return 1

        }

    fi

}


###############################################################################
# Helper: Normalize script name
###############################################################################

normalize_script_name() {
  local input="$1"

  input="$(basename "${input}")"
  input="${input%.script.json}"
  input="${input%.script}"
  input="${input%.json}"

  echo "${input}"
}

###############################################################################
# Helper: Import one script
###############################################################################

SUCCESS_COUNT=0
FAILED_COUNT=0
SKIPPED_COUNT=0
###############################################################################
# Import A Single Script
###############################################################################

import_script() {

    local script_name="$1"

    local json_file="${SCRIPT_DIR}/${script_name}.script.json"

    if [[ ! -f "${json_file}" ]]; then

        log_error "Script artifact not found:"
        log_error "${json_file}"

        return 1

    fi

    log_info "Preparing to import script: ${script_name}"
    log_info "JSON Artifact: ${json_file}"

    #
    # Create temporary import workspace
    #
    #create_temp_workspace

    #
    # Copy required files into workspace
    #
    if ! build_import_package "${script_name}"; then

        log_error "Failed to prepare import package for script: ${script_name}"

        return 1

    fi

    #
    # Validate temp artifacts
    #
    local temp_json="${TMP_IMPORT_DIR}/${script_name}.script.json"

    if [[ ! -f "${temp_json}" ]]; then

        log_error "Prepared JSON artifact missing:"
        log_error "${temp_json}"

        return 1

    fi

    log_info "Temporary import workspace ready:"
    log_info "${TMP_IMPORT_DIR}"

    #
    # Dry Run
    #
    if [[ "${DRY_RUN}" == "true" ]]; then

        log_info "[DRY RUN] Frodo command that would be executed:"

        echo ""
        echo "frodo script import \\"
        echo "   -f \"${script_name}.script.json\" \\"
        echo "   -D \"${TMP_IMPORT_DIR}\" \\"
        echo "   \"${PROFILE}\" \\"
        echo "   \"${REALM}\""
        echo ""

        return 0

    fi

    #
    # Execute Frodo Import
    #
    log_info "Running Frodo import..."

    local output=""
    local rc=0

    set +e

    output="$(
        frodo script import \
            -f "${script_name}.script.json" \
            -D "${TMP_IMPORT_DIR}" \
            "${PROFILE}" \
            "${REALM}" 2>&1
    )"

    rc=$?

    set -e

    #
    # Print Frodo output
    #
    echo "${output}"

    #
    # Check exit code
    #
    if [[ "${rc}" -ne 0 ]]; then

        log_error "Frodo import failed."
        log_error "Exit Code: ${rc}"

        return 1

    fi

    #
    # Frodo sometimes prints usage/errors
    # while not always returning proper failure codes.
    #
    if echo "${output}" | grep -qiE \
        "Unrecognized combination of options|Usage: frodo script import|ENOENT|Failed|Exception|Error:"
    then

        log_error "Frodo reported an import error."

        return 1

    fi

    #
    # Success
    #
    log_success "Imported script successfully: ${script_name}"

    return 0

}

###############################################################################
# Helper: Ask Yes/No
###############################################################################

ask_yes_no() {
  local prompt="$1"
  local answer

  while true; do
    read -r -p "${prompt} [y/n]: " answer

    case "${answer}" in
      y|Y|yes|YES)
        return 0
        ;;
      n|N|no|NO)
        return 1
        ;;
      *)
        echo "Please enter y or n."
        ;;
    esac
  done
}

###############################################################################
# Detect Changed Scripts Using Git
###############################################################################

detect_changed_scripts() {
  local changed_files=()

  # Git porcelain status examples:
  # M  scripts/decision-node/exported/A.script.json
  # A  scripts/decision-node/exported/B.script.json
  # D  scripts/decision-node/exported/C.script.json
  # ?? scripts/decision-node/exported/D.script.json

  while IFS= read -r line; do
    status="${line:0:2}"
    file="${line:3}"

    # Only process exported script JSON artifacts
    if [[ "${file}" != scripts/decision-node/exported/*.script.json ]]; then
      continue
    fi

    # Deleted files cannot be imported
    if [[ "${status}" == *"D"* ]]; then
      log_warn "Detected deleted script artifact. Import skipped: ${file}"
      continue
    fi

    if [[ -f "${REPO_ROOT}/${file}" ]]; then
      changed_files+=("${file}")
    fi

  done < <(git status --porcelain scripts/decision-node/exported)

  for f in "${changed_files[@]}"; do
    normalize_script_name "${f}"
  done
}

###############################################################################
# Build Target List
###############################################################################

SCRIPT_LIST=()

if [[ "${TARGET}" == "all" ]]; then

  log_info "Mode selected: ALL scripts"

  while IFS= read -r file; do
    script_name="$(normalize_script_name "${file}")"
    SCRIPT_LIST+=("${script_name}")
  done < <(find "${SCRIPT_DIR}" -maxdepth 1 -type f -name "*.script.json" | sort)

elif [[ "${TARGET}" == "changed" ]]; then

  log_info "Mode selected: CHANGED scripts"

  while IFS= read -r script_name; do
    [[ -n "${script_name}" ]] && SCRIPT_LIST+=("${script_name}")
  done < <(detect_changed_scripts)

else

  log_info "Mode selected: SINGLE / MULTIPLE scripts"

  IFS=',' read -ra INPUT_SCRIPTS <<< "${TARGET}"

  for item in "${INPUT_SCRIPTS[@]}"; do
    script_name="$(echo "${item}" | xargs)"
    script_name="$(normalize_script_name "${script_name}")"
    [[ -n "${script_name}" ]] && SCRIPT_LIST+=("${script_name}")
  done

fi

###############################################################################
# Validate Script List
###############################################################################

if [[ "${#SCRIPT_LIST[@]}" -eq 0 ]]; then
  log_warn "No script artifacts found for import."
  log_warn "If you expected changed scripts, check:"
  echo ""
  echo "  git status --porcelain scripts/decision-node/exported"
  echo ""
  exit 0
fi

separator
log_info "Scripts selected for import:"
separator

index=1
for script in "${SCRIPT_LIST[@]}"; do
  echo "  ${index}. ${script}"
  index=$((index + 1))
done

separator

###############################################################################
# Prompt Logic for Changed Mode
###############################################################################

if [[ "${TARGET}" == "changed" && "${YES_MODE}" != "true" && "${DRY_RUN}" != "true" ]]; then

  if ask_yes_no "Do you want to import ALL changed scripts?"; then
    log_info "User selected: import all changed scripts."
  else
    log_info "User selected: review each changed script one by one."

    REVIEWED_LIST=()

    for script in "${SCRIPT_LIST[@]}"; do
      if ask_yes_no "Import script '${script}'?"; then
        REVIEWED_LIST+=("${script}")
      else
        log_warn "Skipped by user: ${script}"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
      fi
    done

    SCRIPT_LIST=("${REVIEWED_LIST[@]}")

    if [[ "${#SCRIPT_LIST[@]}" -eq 0 ]]; then
      log_warn "No scripts selected for import after review."
      exit 0
    fi
  fi

fi

###############################################################################
# Create Temporary Workspace Once
###############################################################################

if [[ "${DRY_RUN}" != "true" ]]; then

    create_temp_workspace

fi

###############################################################################
# Import Execution
###############################################################################

separator
log_info "Starting import execution"
separator

#
# Bulk import for ALL or CHANGED
#
if [[ "${TARGET}" == "all" || "${TARGET}" == "changed" ]]; then

    create_temp_workspace

    for script in "${SCRIPT_LIST[@]}"
    do

        if ! build_import_package "${script}"
        then

            log_error "Failed preparing package: ${script}"

            FAILED_COUNT=$((FAILED_COUNT + 1))

            if [[ "${CONTINUE_ON_ERROR}" != "true" ]]
            then
                break
            fi

            continue
        fi

    done

    if [[ "${FAILED_COUNT}" -eq 0 ]]
    then

        if [[ "${DRY_RUN}" == "true" ]]
        then

            log_info "[DRY RUN] Would execute:"

            echo ""
            echo "frodo script import \\"
            echo "    -A \\"
            echo "    -D \"${TMP_IMPORT_DIR}\" \\"
            echo "    \"${PROFILE}\" \\"
            echo "    \"${REALM}\""
            echo ""

            SUCCESS_COUNT=${#SCRIPT_LIST[@]}

        else

            if frodo script import \
                -A \
                -D "${TMP_IMPORT_DIR}" \
                "${PROFILE}" \
                "${REALM}"
            then

                SUCCESS_COUNT=${#SCRIPT_LIST[@]}

            else

                FAILED_COUNT=${#SCRIPT_LIST[@]}

            fi

        fi

    fi

#
# Single / Multiple imports
#
else

    create_temp_workspace

    for script in "${SCRIPT_LIST[@]}"
    do

        if import_script "${script}"
        then
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else

            FAILED_COUNT=$((FAILED_COUNT + 1))

            if [[ "${CONTINUE_ON_ERROR}" != "true" ]]
            then
                break
            fi

        fi

    done

fi
###############################################################################
# Summary
###############################################################################

separator
log_info "Import Summary"
separator
log_success "Successful imports : ${SUCCESS_COUNT}"
log_warn    "Skipped imports    : ${SKIPPED_COUNT}"
log_error   "Failed imports     : ${FAILED_COUNT}"
separator

if [[ "${FAILED_COUNT}" -gt 0 ]]; then
  exit 1
fi

exit 0