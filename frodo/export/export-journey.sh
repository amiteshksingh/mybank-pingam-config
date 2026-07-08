#!/bin/bash

set -euo pipefail

###############################################################################
# Script Name:
#   export-journey.sh
#
# Purpose:
#   Export PingAM Journeys (Trees) using Frodo and organize them into a
#   Git-friendly repository structure for Configuration-as-Code.
#
# Repository Structure:
#
#   journeys/
#   ├── CustomerLogin/
#   │   ├── journey.json
#   │   ├── README.md
#   │   └── test-cases.md
#   │
#   ├── Registration/
#   │   ├── journey.json
#   │   ├── README.md
#   │   └── test-cases.md
#   │
#   └── PasswordReset/
#       ├── journey.json
#       ├── README.md
#       └── test-cases.md
#
# Features:
#
#   ✓ Export all journeys
#   ✓ Export single journey
#   ✓ Mandatory cleanup for ALL exports
#   ✓ Optional cleanup for single journey
#   ✓ Git-friendly structure
#   ✓ JSON validation
#   ✓ Auto-create README.md
#   ✓ Auto-create test-cases.md
#   ✓ Detailed logging
#
# Usage:
#
#   Export all journeys:
#
#     ./export-journey.sh mybank /sabi all
#
#   Export single journey:
#
#     ./export-journey.sh mybank /sabi CustomerLogin
#
#   Export single journey with cleanup:
#
#     ./export-journey.sh mybank /sabi CustomerLogin --cleanup
#
###############################################################################

###############################################################################
# Repository Configuration
###############################################################################

REPO_ROOT="/home/mydir/mybank-pingam-config"

JOURNEY_ROOT="${REPO_ROOT}/journeys"

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

cat << EOF

Usage:

  export-journey.sh <profile> <realm> <all|journey-name|journey1,journey2> [--cleanup]

Examples:

  Export all journeys:

    export-journey.sh mybank /sabi all

  Export single journey:

    export-journey.sh mybank /sabi CustomerLogin

  Export single journey with cleanup:

    export-journey.sh mybank /sabi CustomerLogin --cleanup

Arguments:

  profile
      Frodo connection profile.

  realm
      PingAM realm.
      Example:
          /
          /sabi

  all|journey-name|journey1,journey2

      all
          Export all journeys.

      CustomerLogin,Registration,PasswordReset
          Export multiple journeys.
      
      CustomerLogin
          Export one journey.

Options:

  --cleanup

      Used only for single and multiple journey export. ALL export automatically performs cleanup.

# Cleanup all exported journeys only
./export-journey.sh --cleanup

EOF

}

###############################################################################
# Cleanup ALL Function
###############################################################################

cleanup_all_journeys() {

    log_warn "Cleaning all exported journeys."

    if [[ ! -d "${JOURNEY_ROOT}" ]]
    then
        log_warn "Journey root directory does not exist."
        return
    fi

    find "${JOURNEY_ROOT}" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -exec rm -rf {} +

    log_success "All exported journeys removed."

}

###############################################################################
# Argument Processing
###############################################################################

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]
then
    usage
    exit 0
fi

if [[ "${1:-}" == "--cleanup" ]]
then
    #
    # Cleanup Only Execution
    #

    separator
    log_warn "Cleanup-only mode selected."
    separator

    cleanup_all_journeys

    separator
    log_success "Journey cleanup completed."
    separator

    exit 0


fi

PROFILE="${1:-}"
REALM="${2:-}"
TARGET="${3:-}"
OPTION="${4:-}"

if [[ -z "${PROFILE}" || -z "${REALM}" || -z "${TARGET}" ]]
then
    log_error "Missing mandatory arguments."
    usage
    exit 1
fi

if [[ "${TARGET}" == "all" ]]
then
    MODE="ALL"
    CLEANUP="true"
else
    JOURNEY_NAME="${TARGET}"
    if [[ "${TARGET}" == *","* ]]
        then
            MODE="MULTIPLE"
        else
            MODE="SINGLE"
        fi


    if [[ "${OPTION}" == "--cleanup" ]]
    then
        CLEANUP="true"
    else
        CLEANUP="false"
    fi
fi



###############################################################################
# Build Journey List
###############################################################################

JOURNEY_LIST=()

if [[ "${MODE}" == "SINGLE" ]]
then

    JOURNEY_LIST+=("${TARGET}")

elif [[ "${MODE}" == "MULTIPLE" ]]
then

    IFS=',' read -ra INPUT_JOURNEYS <<< "${TARGET}"

    for item in "${INPUT_JOURNEYS[@]}"
    do
        journey="$(echo "${item}" | xargs)"
        [[ -n "${journey}" ]] && JOURNEY_LIST+=("${journey}")
    done

fi

###############################################################################
# Validation
###############################################################################

if ! command -v frodo >/dev/null 2>&1
then
    log_error "frodo command not found."
    exit 1
fi

mkdir -p "${JOURNEY_ROOT}"

###############################################################################
# Runtime Summary
###############################################################################

separator
log_info "PingAM Journey Export Started"
separator

log_info "Profile      : ${PROFILE}"
log_info "Realm        : ${REALM}"
log_info "Mode         : ${MODE}"
log_info "Journey Root : ${JOURNEY_ROOT}"

if [[ "${MODE}" == "SINGLE" ]]
then
    log_info "Journey Name : ${JOURNEY_NAME}"
fi

separator

###############################################################################
# Other Cleanup Functions
###############################################################################

cleanup_single_journey() {

    local journey_name="$1"

    local target_dir="${JOURNEY_ROOT}/${journey_name}"

    if [[ -d "${target_dir}" ]]
    then
        rm -rf "${target_dir}"
    fi

    log_success "Journey cleaned: ${journey_name}"
}

###############################################################################
# Execute Cleanup
###############################################################################

#
# ALL export always performs cleanup
#
if [[ "${MODE}" == "ALL" ]]
then

    log_info "ALL export selected. Cleanup is mandatory."

    cleanup_all_journeys

#
# SINGLE + MULTIPLE cleanup
#
elif [[ "${CLEANUP}" == "true" ]]
then

    if [[ "${MODE}" == "SINGLE" ]]
    then

        cleanup_single_journey "${JOURNEY_NAME}"

    elif [[ "${MODE}" == "MULTIPLE" ]]
    then

        for journey in "${JOURNEY_LIST[@]}"
        do

            cleanup_single_journey "${journey}"

        done

    fi

else

    log_info "Cleanup not requested."

fi


###############################################################################
# Extract Script Dependencies From Journey JSON
#
# No jq dependency.
###############################################################################

extract_script_dependencies() {

    local journey_json="$1"

    if [[ ! -f "${journey_json}" ]]
    then
        return
    fi

    grep -oE '"name"[[:space:]]*:[[:space:]]*"[^"]+"' "${journey_json}" |
    sed -E 's/.*"name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' |
    grep -vE '^Scripted Decision$|^Inner Tree Evaluator$|^Page Node$|^Inner Tree$|^Success$|^Failure$|^Start$' |
    sort -u
}

###############################################################################
# Extract Library Dependencies
#
# Example:
#   require('DspUtils')
#   require("CommonUtils")
#
###############################################################################

extract_library_dependencies() {

    local script_name="$1"

    local js_file

    js_file="$(find "${REPO_ROOT}/scripts" \
        -type f \
        -name "${script_name}.js" \
        | head -1)"

    [[ -z "${js_file}" ]] && return

    grep -oE "require\(['\"][^'\"]+['\"]\)" "${js_file}" |
    tr -d '"' |
    tr -d "'" |
    sed 's/require(//g' |
    sed 's/)//g' |
    sort -u
}

extract_all_library_dependencies() {

    local journey_json="$1"

    while IFS= read -r script_name
    do

        [[ -z "${script_name}" ]] && continue

        extract_library_dependencies "${script_name}"

    done < <(
        extract_script_dependencies "${journey_json}"
    )

}

###############################################################################
# README Generator
###############################################################################

create_readme() {

    local journey_dir="$1"
    local journey_name="$2"

    local journey_json="${journey_dir}/journey.json"
    local readme_file="${journey_dir}/README.md"

    {

        echo "# ${journey_name}"
        echo ""

        echo "## Purpose"
        echo ""
        echo "Document the purpose of this journey."
        echo ""

        echo "## Dependencies"
        echo ""

        echo "### Scripts"
        echo ""
        local scripts_found="false"
        while IFS= read -r script
        do

            [[ -z "${script}" ]] && continue

            echo "- ${script} (scripts/decision-node/source/JavaScript/${script}.js)"
            scripts_found="true"
            while IFS= read -r lib
            do
                [[ -z "${lib}" ]] && continue
                echo "  Uses:"
                echo "  - ${lib} (scripts/decision-node/source/JavaScript/${lib}.js)"
            done < <(
                extract_library_dependencies "${script}"
            )

            echo ""

        done < <(
            extract_script_dependencies "${journey_json}"
        )

        if [[ "${scripts_found}" == "false" ]]
        then
            echo "- None detected"
        fi

        echo ""
        

        #######################################################################
        # Other Dependencies
        #######################################################################

        echo "### Email Templates"
        echo ""
        echo "- None detected"
        echo ""

        echo "### OAuth Clients"
        echo ""
        echo "- None detected"
        echo ""

        echo "### Themes"
        echo ""
        echo "- None detected"
        echo ""

        #######################################################################
        # Metadata
        #######################################################################

        echo "## Source"
        echo ""
        echo "Generated automatically by export-journey.sh"
        echo ""

    } > "${readme_file}"

}

###############################################################################
# Generate PlantUML Diagram
###############################################################################

generate_puml() {

    local journey_json="$1"
    local puml_file="$2"

    log_info "Generating PlantUML diagram..."
    log_info "Journey JSON : ${journey_json}"
    log_info "Output PUML  : ${puml_file}"

    [[ ! -f "${journey_json}" ]] && {
        log_error "Journey JSON not found: ${journey_json}"
        return 1
    }

    python3 <<PYTHON

import json
import re
from pathlib import Path

journey_json = r"${journey_json}"
puml_file    = r"${puml_file}"
repo_root    = r"${REPO_ROOT}"

with open(journey_json, "r", encoding="utf-8") as f:
    data = json.load(f)

journey_name = next(iter(data["trees"]))
journey      = data["trees"][journey_name]

tree_nodes   = journey["tree"]["nodes"]
raw_nodes    = journey["nodes"]
scripts      = journey["scripts"]

##############################################################################
# Build Script UUID -> Script Name Map
##############################################################################

script_name_map = {}

for script_uuid, script_obj in scripts.items():
    script_name_map[script_uuid] = script_obj.get(
        "name",
        script_uuid
    )

##############################################################################
# Build Node Metadata
##############################################################################

node_display_map = {}
node_script_map = {}
state_alias_map = {}

##############################################################################
# Outcome Display Name Map
#
# Node ID
#    -> outcome id
#           -> display name
##############################################################################

outcome_display_map = {}

for node_id, node in raw_nodes.items():

    outcome_display_map[node_id] = {}

    for outcome in node.get("_outcomes", []):

        outcome_id = outcome.get("id")

        outcome_display = outcome.get(
            "displayName",
            outcome_id
        )

        outcome_display_map[node_id][outcome_id] = (
            outcome_display
        )

for node_id, tree_node in tree_nodes.items():

    display_name = tree_node.get(
        "displayName",
        node_id
    )

    node_display_map[node_id] = display_name

    #
    # Short alias
    #
    alias = "NODE_" + node_id.split("-")[0]

    state_alias_map[node_id] = alias

    #
    # Script UUID
    #
    if node_id in raw_nodes:

        script_uuid = raw_nodes[node_id].get(
            "script"
        )

        if script_uuid:
            node_script_map[node_id] = script_uuid

##############################################################################
# Script -> Library Mapping
##############################################################################

script_library_map = {}

for node_id, script_uuid in node_script_map.items():

    script_name = script_name_map.get(
        script_uuid
    )

    if not script_name:
        continue

    libraries = []

    script_file = next(
        Path(repo_root).glob(
            f"scripts/**/{script_name}.js"
        ),
        None
    )

    if script_file and script_file.exists():

        try:

            content = script_file.read_text(
                encoding="utf-8",
                errors="ignore"
            )

            #
            # require('DspUtils')
            # require("DspUtils")
            #

            libraries = sorted(
                set(
                    re.findall(
                        r"require\s*\(\s*[^'\"]+['\"]\s*\)",
                        content
                    )
                )
            )

        except Exception as ex:

            print(
                f"WARNING parsing {script_file}: {ex}"
            )

    script_library_map[script_name] = libraries

##############################################################################
# Generate PUML
##############################################################################

lines = []

lines.append("@startuml")
lines.append("")
lines.append("left to right direction")
lines.append("skinparam linetype ortho")
lines.append("skinparam shadowing false")
lines.append("skinparam state {")
lines.append("  BackgroundColor White")
lines.append("  BorderColor Black")
lines.append("}")
lines.append("")

##############################################################################
# State Declarations
##############################################################################

for node_id, display_name in node_display_map.items():

    alias = state_alias_map[node_id]

    lines.append(
        f'state "{display_name}" as {alias}'
    )

##############################################################################
# Entry node
##############################################################################

entry_node = journey["tree"]["entryNodeId"]

lines.append(
    f'[*] --> {state_alias_map[entry_node]}'
)

lines.append("")

##############################################################################
# Connections
##############################################################################

static_nodes = set(
    journey["tree"]
    .get("staticNodes", {})
    .keys()
)

for node_id, node in tree_nodes.items():

    source_alias = state_alias_map[node_id]

    connections = node.get(
        "connections",
        {}
    )

    for outcome_id, target_node in connections.items():

        #
        # Business-friendly label
        #
        outcome_label = (
            outcome_display_map
                .get(node_id, {})
                .get(outcome_id, outcome_id)
        )

        #
        # Skip start node
        #
        if target_node == "startNode":
            continue

        #
        # Static success/failure
        #
        if target_node in static_nodes:

            node_name = node_display_map \
                .get(node_id, "") \
                .lower()

            if "success" in node_name:

                lines.append(
                    f'{source_alias} --> [*] : Success'
                )

            elif "failure" in node_name:

                lines.append(
                    f'{source_alias} --> [*] : Failure'
                )

            else:

                lines.append(
                    f'{source_alias} --> [*] : {outcome_label}'
                )

            continue

        target_alias = state_alias_map.get(
            target_node
        )

        if not target_alias:
            continue

        lines.append(
            f'{source_alias} --> {target_alias} : {outcome_label}'
        )

##############################################################################
# Notes
##############################################################################

for node_id, script_uuid in node_script_map.items():

    alias = state_alias_map[node_id]

    script_name = script_name_map.get(
        script_uuid,
        script_uuid
    )

    lines.append(
        f'note right of {alias}'
    )

    lines.append(
        f'Script: {script_name}'
    )

    libs = script_library_map.get(
        script_name,
        []
    )

    if libs:

        lines.append("")
        lines.append("Libraries:")

        for lib in libs:
            lines.append(
                f'- {lib}'
            )

    lines.append(
        "end note"
    )

    lines.append("")

##############################################################################
# End
##############################################################################

lines.append("@enduml")

with open(
    puml_file,
    "w",
    encoding="utf-8"
) as f:

    f.write("\\n".join(lines))

print("Generated:", puml_file)

PYTHON

    if [[ -f "${puml_file}" ]]
    then
        log_success "PlantUML generated successfully"
        log_success "${puml_file}"
    else
        log_error "PlantUML generation failed"
        return 1
    fi

}

###############################################################################
# Test Case Template
###############################################################################

create_test_cases_template() {

    local journey_dir="$1"

    local file="${journey_dir}/test-cases.md"

    if [[ ! -f "${file}" ]]
    then

cat > "${file}" << EOF
# Test Cases

## Happy Path

| Test ID | Description | Result |
|----------|-------------|---------|
| TC-001 | Successful authentication | TBD |

## Negative Tests

| Test ID | Description | Result |
|----------|-------------|---------|
| TC-101 | Invalid credentials | TBD |

EOF

    fi
}

###############################################################################
# JSON Validation
###############################################################################

validate_json() {

    local file="$1"

    python3 -m json.tool "${file}" >/dev/null 2>&1
}

###############################################################################
# Export Single Journey
###############################################################################

export_single_journey() {

    local journey_name="$1"

    local journey_dir="${JOURNEY_ROOT}/${journey_name}"

    mkdir -p "${journey_dir}"

    log_info "Exporting journey: ${journey_name}"

    frodo journey export \
        -i "${journey_name}" \
        -D "${journey_dir}" \
        --no-coords \
        --no-metadata \
        "${PROFILE}" \
        "${REALM}"

    local json_file

    json_file="$(find "${journey_dir}" -type f -name "*.json" | head -1)"

    if [[ -z "${json_file}" ]]
    then
        log_error "Journey export produced no JSON output."
        exit 1
    fi

    mv "${json_file}" "${journey_dir}/journey.json"

    validate_json "${journey_dir}/journey.json"
    generate_puml \
        "${journey_dir}/journey.json" \
       "${journey_dir}/journey.puml"

    create_readme "${journey_dir}" "${journey_name}"
    create_test_cases_template "${journey_dir}"

    log_success "Journey exported: ${journey_name}"
}

###############################################################################
# Export All Journeys
###############################################################################

export_all_journeys() {

    local tmp_dir

    tmp_dir="$(mktemp -d)"

    log_info "Exporting all journeys."

    frodo journey export \
        -A \
        -D "${tmp_dir}" \
        --no-coords \
        --no-metadata \
        "${PROFILE}" \
        "${REALM}"

    while IFS= read -r file
    do

        journey_name="$(basename "${file}" .json)"

        target_dir="${JOURNEY_ROOT}/${journey_name}"

        mkdir -p "${target_dir}"

        mv "${file}" "${target_dir}/journey.json"

        validate_json "${target_dir}/journey.json"

        generate_puml \
            "${target_dir}/journey.json" \
            "${target_dir}/journey.puml"

        create_readme "${target_dir}" "${journey_name}"
        create_test_cases_template "${target_dir}"

        log_success "Exported journey: ${journey_name}"

    done < <(
        find "${tmp_dir}" \
            -type f \
            -name "*.json" \
            | sort
    )

    rm -rf "${tmp_dir}"

    log_success "All journeys exported."
}

###############################################################################
# Export Execution
###############################################################################

if [[ "${MODE}" == "ALL" ]]
then

    export_all_journeys

else

    for journey in "${JOURNEY_LIST[@]}"
    do

        log_info "Processing journey: ${journey}"

        export_single_journey "${journey}"

    done

fi

###############################################################################
# Summary
###############################################################################

JOURNEY_COUNT="$(
find "${JOURNEY_ROOT}" \
    -type f \
    -name "journey.json" \
    | wc -l
)"

separator
log_success "Journey Export Completed"
separator

log_info "Journey Count : ${JOURNEY_COUNT}"

separator
echo "Exported Journeys:"
find "${JOURNEY_ROOT}" \
    -mindepth 1 \
    -maxdepth 1 \
    -type d \
    | sort \
    | sed 's|.*/||'
separator
echo "Next Steps:"
echo "  1. Review the exported journeys in ${JOURNEY_ROOT}"
echo "  2. Commit the changes to your Git repository"
echo ""
exit 0