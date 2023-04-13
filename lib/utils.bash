#!/usr/bin/env bash

set -euo pipefail

TOOL_OWNER="google"
TOOL_REPO="flatbuffers"
GH_API_URL="https://api.github.com/repos/${TOOL_OWNER}/${TOOL_REPO}"
GH_REPO_URL="https://github.com/${TOOL_OWNER}/${TOOL_REPO}"
GH_RELEASES_URL="${GH_REPO_URL}/releases"
TOOL_NAME="flatbuffers"
TOOL_TEST="flatc --version"

CACHE_DIR="${TMPDIR:-/tmp}"
CACHE_DIR="${CACHE_DIR%/}/asdf-${TOOL_NAME}.cache"
CACHE_FILE="${CACHE_DIR}/releases.json"

DEBUG=${DEBUG-}

if [[ ! -d "${CACHE_DIR}" ]]; then
  mkdir -p "${CACHE_DIR}"
fi

curl_opts=(-fsSL)

# https://github.com/asdf-vm/asdf/blob/master/docs/plugins/create.md#api-rate-limiting
if [ -n "${GITHUB_API_TOKEN:-}" ]; then
  curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

log() { echo -e "asdf-$TOOL_NAME: $*" >&2; }
debug() {
  if [[ $DEBUG ]]; then log DEBUG "$@"; fi
}
fail() {
  log "$@"
  exit 1
}

check_type() {
  local -r install_type="$1"

  if ! [[ "$install_type" == "version" ]]; then
    fail "asdf-$TOOL_NAME supports release installs only"
  fi
}

check_unzip() {
  test -x "$(command -v unzip)" || fail "Install 'unzip' to continue."
}

check_jq() {
  test -x "$(command -v jq)" || fail "Install 'jq' to continue (the asdf-jq plugin is available)."
}

refresh_release_data() {
  local -r release_data_file="${1:-"${CACHE_DIR}/releases.original.json"}"
  local -r url="$GH_API_URL/releases"

  check_jq

  debug "Refreshing releases data... (${url})"

  curl "${curl_opts[@]}" -o "${release_data_file}" "$url" \
    || fail "Could not refresh $url"

  # Simplify to array of: {
  #   tag_name: <tag>,
  #   release_url: <url>
  #   win: <file>,
  #   mac: <file>,
  #   clang: <file>,
  #   gcc: <file>
  # }
  # omitting keys of missing download files
  jq 'map(
    # Only nob-interim releases
    select( .name | contains("interim") | not )
    # Create an object where key is platform or linux-compiler, and value is asset name
    | (.assets
        | map(
            select( .content_type | contains("zip") )
            | .name
            | . as $name
            | ascii_downcase
            | if (contains("windows")) then { win: $name }
              # Ignore non-universal mac binaries (only 2.0.0 has an x86_64 bin named "Mac",
              # which will run under Rosetta, other "Mac" are universal and MacIntel is x86_64)
              elif (contains("mac") and (contains("intel") | not))   then { mac: $name }
              elif (contains("clang")) then { clang: $name }
              elif (contains("g++"))   then { gcc: $name }
              else                     empty
              end
          )
        | add
      ) as $assets
    | select($assets | length > 0)
    | {
        tag_name,
        release_url: .html_url
      } + $assets
  )' <"${release_data_file}" >"${CACHE_FILE}"
}

check_release_data() {
  local -r release_file="${CACHE_DIR}/releases.original.json"
  local STAT STAT_OPTS

  check_jq

  case "${OSTYPE}" in
    darwin*)
      STAT="/usr/bin/stat"
      STAT_OPTS=('-f' '%c')
      ;;
    linux*)
      STAT="stat"
      STAT_OPTS=('-c' '%Z')
      ;;
    *)
      # TODO: windows?
      fail "Unknown operating system: ${OSTYPE}"
      ;;
  esac

  # shellcheck disable=SC2046
  if [[ ! -r "${release_file}" ]] || (($($STAT "${STAT_OPTS[@]}" "${release_file}") <= $(date +%s) - 3600)); then
    refresh_release_data "${release_file}"
  else
    debug "Using cached release data: ${release_file}"
  fi
}

# Variant for this system, using both platform and C++ compiler (Linux only) as discriminators.
#
# Don't assign when initializing a local variable: https://unix.stackexchange.com/a/172629
#
# If not specified, gcc is the default compiler on linux. MacOs and Windows
# have no compiler variant. To date, flatbuffers has only released binaries
# from one version of a compiler at a time, so the version (e.g. clang++-9
# vs clang++-10) is implicit, based on release version.
get_variant() {
  local -r version="$1"
  local -r kernel="$(uname -s)"
  local variant

  # Catching the kernel variants of windows before linux
  if [[ ${OSTYPE} == "msys" || ${kernel} == "CYGWIN"* || ${kernel} == "MINGW"* ]]; then
    echo "win"
  elif [[ ${OSTYPE} == "darwin"* ]]; then
    # Always install the universal binary when available
    echo "mac"
  elif [[ ${OSTYPE} == "linux"* ]]; then
    if [[ ${version} == *"-clang" ]]; then
      echo "clang"
    elif [[ ${version} == *"-gcc" ]]; then
      echo "gcc"
    else
      log "Linux compiler not specified, using gcc"
      echo "gcc"
    fi
  else
    fail "Unrecognized platform: OSTYPE=${OSTYPE} kernel=${kernel}"
  fi
}

# Don't assign when initializing a local variable: https://unix.stackexchange.com/a/172629
get_archive_name() {
  local -r version="$1"
  local -r version_number="${version%%-*}" # without compiler name if present
  local result release_url variant

  check_release_data

  variant="$(get_variant "${version}")"
  result="$(jq -r "map(select(.tag_name == \"v${version_number}\") | .release_url, .${variant}) | join(\" \")" <"${CACHE_FILE}")" \
    || fail "Error searching cache for version: version=${version_number} variant=${variant}"

  debug "Lookup result: ${result}"

  local -r release_url="$(echo "${result}" | cut -d' ' -f1)"
  local -r archive_name="$(echo "${result}" | cut -d' ' -f2)"

  if [[ -z "${archive_name}" ]]; then
    [[ -z "${release_url}" ]] && fail "Version ${version_number} does not appear to be a release ${GH_RELEASES_URL}"
    fail "Version ${version_number} does not have a binary for ${variant}: ${release_url}"
  fi

  echo "${archive_name}"
}

list_all_versions() {
  check_release_data

  jq -r 'map(
    .tag_name[1:] as $name
    | if ((.clang or .gcc) | not) then $name else empty end,
      if (.gcc) then $name + "-gcc" else empty end,
      if (.clang) then $name + "-clang" else empty end
  ) | reverse | join(" ")' <"${CACHE_FILE}"
}

download_release() {
  local -r install_type="$1"
  local -r version="$2"
  local -r download_file="$3"
  local -r version_number="${version%%-*}" # without compiler name if present

  [[ ${download_file##*.} == "zip" ]] || fail "Only zip files are supported: ${download_file}"

  check_type "${install_type}"
  check_unzip

  (
    local archive_name # split because: https://unix.stackexchange.com/a/172629
    archive_name="$(get_archive_name "${version}")" || fail
    local -r url="$GH_REPO_URL/releases/download/v${version_number}/${archive_name}"

    # Download the archive file
    debug "Downloading $TOOL_NAME release ${version} from ${url}"
    curl "${curl_opts[@]}" -o "$download_file" "$url" || fail "Could not download $url"
    debug "Saved $download_file"

    #  Extract contents of zip file into the download directory
    debug "Extracting $TOOL_NAME archive"
    unzip -qq -o "${download_file}" -d "${ASDF_DOWNLOAD_PATH}" || fail "Could not extract ${download_file}"

    # Remove the archive file since we should not keep it in download directory
    rm "${download_file}"
  ) || (
    rm "${download_file}"
    fail "An error occurred while downloading $TOOL_NAME $version."
  )
}

install_version() {
  local -r install_type="$1"
  local -r version="$2"
  local -r install_path="${3%/bin}/bin"

  check_type "${install_type}"

  (
    local -r tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"

    mkdir -p "${install_path}"
    cp "${ASDF_DOWNLOAD_PATH}/${tool_cmd}" "${install_path}" || fail "Installing to ${install_path} failed"
    chmod 755 "${install_path}/${tool_cmd}"

    test -x "$install_path/$tool_cmd" || fail "Expected $install_path/$tool_cmd to be executable."

    log "$TOOL_NAME $version installation was successful!"
  ) || (
    rm -rf "$install_path"
    fail "An error occurred while installing $TOOL_NAME $version."
  )
}
