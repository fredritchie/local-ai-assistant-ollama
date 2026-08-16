#!/usr/bin/env bash
set -Eeuo pipefail

readonly EXPECTED_DRAWIO_VERSION="31.1.8"
REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPOSITORY_ROOT
readonly SOURCE_DIRECTORY="${REPOSITORY_ROOT}/docs/diagrams/source"
readonly RENDER_DIRECTORY="${REPOSITORY_ROOT}/docs/diagrams"
readonly MANIFEST_FILE="${RENDER_DIRECTORY}/source.sha256"

usage() {
  cat <<'EOF'
Usage: scripts/render_architecture_diagrams.sh [--check] [--output DIRECTORY]

Render every docs/diagrams/source/*.drawio file to a same-named PNG.

  --check             Render to a temporary directory and verify that the
                      committed PNG files are current.
  --output DIRECTORY  Write rendered PNG files to DIRECTORY instead of the
                      repository diagram directory.

DRAWIO_BIN may point to the Draw.io executable. Set DRAWIO_USE_XVFB=1 for a
headless Linux runner. Draw.io 31.1.8 is required for reproducible output.
EOF
}

check_mode=false
output_directory="${RENDER_DIRECTORY}"

while (($# > 0)); do
  case "$1" in
    --check)
      check_mode=true
      shift
      ;;
    --output)
      if (($# < 2)); then
        echo "ERROR: --output requires a directory." >&2
        exit 2
      fi
      output_directory="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "${check_mode}" == true && "${output_directory}" != "${RENDER_DIRECTORY}" ]]; then
  echo "ERROR: --check and --output cannot be used together." >&2
  exit 2
fi

if [[ -n "${DRAWIO_BIN:-}" ]]; then
  drawio_binary="${DRAWIO_BIN}"
elif command -v drawio >/dev/null 2>&1; then
  drawio_binary="$(command -v drawio)"
elif command -v draw.io >/dev/null 2>&1; then
  drawio_binary="$(command -v draw.io)"
elif [[ -x /Applications/draw.io.app/Contents/MacOS/draw.io ]]; then
  drawio_binary=/Applications/draw.io.app/Contents/MacOS/draw.io
else
  echo "ERROR: Draw.io ${EXPECTED_DRAWIO_VERSION} is required but was not found." >&2
  echo "Set DRAWIO_BIN to the Draw.io executable and retry." >&2
  exit 1
fi

renderer=("${drawio_binary}")
if [[ "${DRAWIO_USE_XVFB:-0}" == "1" ]]; then
  if ! command -v xvfb-run >/dev/null 2>&1; then
    echo "ERROR: DRAWIO_USE_XVFB=1 requires xvfb-run." >&2
    exit 1
  fi
  renderer=(xvfb-run -a "${drawio_binary}")
fi

version_output="$("${renderer[@]}" --version 2>&1 || true)"
actual_version="$({
  printf '%s\n' "${version_output}" |
    tr -d '\r' |
    sed -nE 's/^[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)[[:space:]]*$/\1/p' |
    head -n 1
})"
if [[ "${actual_version}" != "${EXPECTED_DRAWIO_VERSION}" ]]; then
  echo "ERROR: Draw.io ${EXPECTED_DRAWIO_VERSION} is required; found ${actual_version:-unknown}." >&2
  if [[ -n "${version_output}" ]]; then
    echo "Draw.io version output:" >&2
    printf '%s\n' "${version_output}" >&2
  fi
  exit 1
fi

temporary_directory=""
cleanup() {
  if [[ -n "${temporary_directory}" ]]; then
    rm -rf -- "${temporary_directory}"
  fi
}
trap cleanup EXIT

sha256_digest() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    echo "ERROR: sha256sum or shasum is required." >&2
    return 1
  fi
}

write_source_manifest() {
  manifest_destination="$1"
  : >"${manifest_destination}"
  for source_file in "${sources[@]}"; do
    diagram_name="$(basename "${source_file}")"
    printf '%s  source/%s\n' \
      "$(sha256_digest "${source_file}")" \
      "${diagram_name}" >>"${manifest_destination}"
  done
}

if [[ "${check_mode}" == true ]]; then
  temporary_directory="$(mktemp -d)"
  output_directory="${temporary_directory}"
fi
mkdir -p -- "${output_directory}"

sources=()
while IFS= read -r -d '' source_file; do
  sources+=("${source_file}")
done < <(find "${SOURCE_DIRECTORY}" -maxdepth 1 -type f -name '*.drawio' -print0 | sort -z)
if ((${#sources[@]} == 0)); then
  echo "ERROR: no Draw.io sources found in ${SOURCE_DIRECTORY}." >&2
  exit 1
fi

for source_file in "${sources[@]}"; do
  diagram_name="$(basename "${source_file}" .drawio)"
  rendered_file="${output_directory}/${diagram_name}.png"
  "${renderer[@]}" --export --format png --output "${rendered_file}" "${source_file}" >/dev/null
  if [[ ! -s "${rendered_file}" ]]; then
    echo "ERROR: Draw.io did not create ${rendered_file}." >&2
    exit 1
  fi
  echo "Rendered docs/diagrams/${diagram_name}.png"
done

if [[ "${check_mode}" == true ]]; then
  status=0
  generated_manifest="${temporary_directory}/source.sha256"
  write_source_manifest "${generated_manifest}"
  for rendered_file in "${temporary_directory}"/*.png; do
    committed_file="${RENDER_DIRECTORY}/$(basename "${rendered_file}")"
    if [[ ! -f "${committed_file}" ]]; then
      echo "ERROR: missing committed render: ${committed_file#"${REPOSITORY_ROOT}/"}" >&2
      status=1
    fi
  done
  if [[ ! -f "${MANIFEST_FILE}" ]]; then
    echo "ERROR: missing diagram source manifest: ${MANIFEST_FILE#"${REPOSITORY_ROOT}/"}" >&2
    status=1
  elif ! cmp -s -- "${generated_manifest}" "${MANIFEST_FILE}"; then
    echo "ERROR: architecture sources changed without regenerating their PNG files." >&2
    status=1
  fi
  if ((status != 0)); then
    echo "Run bash scripts/render_architecture_diagrams.sh and commit the PNG and manifest changes." >&2
    exit "${status}"
  fi
  echo "All architecture sources are represented by current committed renders."
else
  write_source_manifest "${MANIFEST_FILE}"
  echo "Updated docs/diagrams/source.sha256."
fi
