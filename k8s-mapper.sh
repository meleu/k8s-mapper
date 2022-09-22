#!/usr/bin/env bash
# k8s-mapper.sh
###########################################################################
# Create markdown files with diagrams showing all k8s objects present
# in all namespaces, in all k8s clusters of a given GCP project.
#
# Main piece of software here: https://github.com/mkimuram/k8sviz
#
# Dependencies:
# - k8sviz  - https://github.com/mkimuram/k8sviz
# - docker  - the k8sviz.sh script calls a container (check k8sviz's README)
# - gcloud  - to get the list of clusters
# - kubectl - to get the list of namespaces
#
###########################################################################
# shellcheck disable=2155

# fail fast
set -Eeuo pipefail

readonly USAGE="USAGE:
${0##*/} [-h|--help] gcpProject1 [gcpProject2 gcpProjectN]"

# ANSI escape color codes
readonly ansiGreen='\e[1;32m'
readonly ansiRed='\e[1;31m'
readonly ansiNoColor='\e[0m'
readonly ansiYellow='\e[1;33m'

logError() {
  echo -e "${ansiRed}[ERROR] $*${ansiNoColor}" >&2
}

logWarn() {
  echo -e "${ansiYellow}[WARNING] $*${ansiNoColor}" >&2
}

logSuccess() {
  echo -e "${ansiGreen}[SUCCESS] $*${ansiNoColor}" >&2
}

log() {
  echo -e "[INFO] $*" >&2
}

checkDependencies() {
  local cmd
  local returnValue=0
  local missingDependencies=()
  declare -A dependenciesDocs=(
    ['k8sviz.sh']='https://github.com/mkimuram/k8sviz#installation'
    ['docker']='https://docs.docker.com/engine/install/'
    ['gcloud']='https://cloud.google.com/sdk/docs/install'
    ['kubectl']='https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/'
  )

  for cmd in "${!dependenciesDocs[@]}"; do
    if ! command -v "${cmd}" > /dev/null; then
      returnValue=1
      missingDependencies+=("${cmd}: ${dependenciesDocs[${cmd}]}")
    fi
  done

  [[ "${returnValue}" -eq 0 ]] && return 0

  logError \
    "missing dependencies:" \
    "${missingDependencies[@]/#/\\n- }"
  return 1
}

createDiagrams() {
  local gcpProjects=("$@")
  local project
  local clustersAndZones=()
  local namespaces=()
  local clusterAndZone
  local cluster
  local zone
  local namespace
  local outputDir='./k8s-maps'
  local imageDir
  local outputFile
  local mdFile
  local jsonFile="$(mktemp /tmp/k8s-mapper.XXXXXX)"

  for project in "${gcpProjects[@]}"; do
    log "Checking GCP project '${project}'..."
    # get the json file with the required data
    gcloud container clusters list \
      --project "${project}" \
      --format=json \
      --verbosity=none > "${jsonFile}" \
      || {
        logWarn "Unable to find a GCP project named '${project}'. Ignoring..."
        continue
      }

    # get the list of clusters and their respective zones (separated by ':')
    # why mapfile? because I want each line of the output to be an element
    # see: https://www.shellcheck.net/wiki/SC2207
    mapfile -t clustersAndZones < <(
      jq --raw-output '.[] | "\(.name):\(.zone)"' "${jsonFile}"
    ) || {
      logWarn \
        "Unable to get list of clusters in GCP project '${project}'. Ignoring..."
      continue
    }

    # iterate through clusters in this $project
    for clusterAndZone in "${clustersAndZones[@]}"; do
      cluster="$(cut -d: -f1 <<< "${clusterAndZone}")"
      zone="$(cut -d: -f2 <<< "${clusterAndZone}")"

      log "Checking cluster '${cluster}'..."
      gcloud container clusters get-credentials \
        "${cluster}" \
        --zone "${zone}" \
        --project "${project}" > /dev/null 2>&1 || {
        logWarn \
          "Unable to authenticate in cluster '${cluster}' (project '${project}'). Ignoring..."
        continue
      }

      # creating the markdown file for this cluster
      mkdir -p "${outputDir}/${project}"
      mdFile="${outputDir}/${project}_-_${cluster}.md"
      echo "# ${project}/${cluster}" > "${mdFile}"
      echo -e "\n\n [TOC]\n\n---" >> "${mdFile}"

      # get the list of namespaces
      # why read? because I want each word separated by spaces to be an element
      # see: https://www.shellcheck.net/wiki/SC2207
      IFS=' ' read -r -a namespaces <<< "$(
        kubectl get namespaces -o jsonpath='{.items[*].metadata.name}'
      )" \
        || {
          logWarn \
            "Unable to list namespaces in cluster '${cluster}' (project '${project}'). Ignoring..."
          continue
        }

      # iterate through namespaces in this $cluster
      for namespace in "${namespaces[@]}"; do
        imageDir="${outputDir}/${project}/${cluster}"
        mkdir -p "${imageDir}"
        outputFile="${outputDir}/${project}/${cluster}/${namespace}.png"

        # XXX: chmod needed because of issues with k8sviz container permissions
        chmod a+rwx "${imageDir}"

        log "generating '${outputFile}'..."
        k8sviz.sh \
          -t png \
          -n "${namespace}" \
          -o "${outputFile}" \
          || {
            logWarn "Unable to generate '${outputFile}'. Ignoring..."
            continue
          }

        { # grouping echoes and sending their output to ${mdFile}
          echo -e "\n\n## ${namespace}"
          echo -e "\n- generated at **$(date --iso-8601=minutes --utc)**"
          echo -e "\n![${namespace}](/${outputFile})"
        } >> "${mdFile}"
      done
    done
  done

  rm -f "${jsonFile}"
}

main() {
  checkDependencies

  if [[ -z "$*" || $1 =~ ^(-h|--help)$ ]]; then
    echo "${USAGE}"
    return
  fi

  createDiagrams "$@"
}

main "$@"
