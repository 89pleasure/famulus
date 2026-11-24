#!/usr/bin/env bash
# Checks a release tag before anything is built or uploaded. Run by .github/workflows/release.yml;
# by hand:  bash tools/release_check.sh v0.2.0-beta.1
#
# - The tag is v<major>.<minor>.<patch>, optionally followed by -beta.<n> or -alpha.<n>, and nothing
#   else: the packager uploads every tag without "alpha" or "beta" in it as a Release, so a tag like
#   v0.2.0-rc1 would reach every player.
# - CHANGELOG.md has a section "## <version>" (the tag without the v) with text in it; CurseForge
#   wants a changelog for every file.
# - Famulus/Famulus.toc names the CurseForge project (## X-Curse-Project-ID).
#
# With a second argument, the changelog section is written to that file (the packager reads it as
# the file's changelog, see .pkgmeta).

set -euo pipefail

tag="${1:?usage: bash tools/release_check.sh <tag> [notes-file]}"
notes="${2:-}"
cd "$(dirname "$0")/.."

fail() {
    # "::error::" turns the line into an annotation on GitHub; locally it is just printed.
    echo "::error::$1" >&2
    exit 1
}

pattern='^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-(alpha|beta)\.[1-9][0-9]*)?$'
if [[ ! $tag =~ $pattern ]]; then
    fail "\"$tag\" is not a release tag. Use v1.2.3 (Release), v1.2.3-beta.1 (Beta) or v1.2.3-alpha.1 (Alpha)."
fi
type="${BASH_REMATCH[5]:-release}"
version="${tag#v}"

[[ -f CHANGELOG.md ]] || fail "CHANGELOG.md is missing."
section=$(tr -d '\r' < CHANGELOG.md | awk -v v="$version" '/^## / { if (found) exit; found = ($2 == v); next } found')
if [[ -z "${section//[[:space:]]/}" ]]; then
    fail "CHANGELOG.md has no section \"## $version\" with text in it."
fi

if ! tr -d '\r' < Famulus/Famulus.toc | grep -Eq '^## X-Curse-Project-ID: *[0-9]+ *$'; then
    fail "Famulus/Famulus.toc has no \"## X-Curse-Project-ID: <number>\" line."
fi

if [[ -n "$notes" ]]; then
    printf '## Famulus %s\n\n%s\n' "$version" "$(sed '/./,$!d' <<< "$section")" > "$notes"
fi

echo "$tag uploads as $type."
