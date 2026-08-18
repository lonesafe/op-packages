#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
report=${1:-"$repo_root/compat/static-report.md"}

# shellcheck disable=SC1091
source "$repo_root/compat/baseline.env"

cd "$repo_root"

count_matching_files() {
	local pattern=$1
	shift
	{
		rg -l "$pattern" \
			--glob '!.git/**' \
			--glob '!.github/**' \
			--glob '!compat/**' \
			--glob '!scripts/**' \
			"$@" . || true
	} | wc -l | tr -d ' '
}

makefiles=$(find . -name Makefile -type f -not -path './.git/*' | wc -l | tr -d ' ')
hash_skip=$(count_matching_files 'PKG_(MIRROR_)?HASH\s*:?=\s*(skip|x)' --glob '**/Makefile')
opkg_runtime=$(count_matching_files '\bopkg\b' --glob '!README*' --glob '!**/*.po' --glob '!**/*.pot' --glob '!**/Makefile')
ipk_refs=$(count_matching_files '\.ipk\b' --glob '!README*' --glob '!**/*.po' --glob '!**/*.pot')
iptables_refs=$(count_matching_files '\biptables(-save|-restore)?\b' --glob '!**/*.po' --glob '!**/*.pot')
leading_v_versions=$(count_matching_files '^PKG_VERSION:=v' --glob '**/Makefile')

mkdir -p "$(dirname "$report")"
cat >"$report" <<EOF
# Static compatibility report

| Check | Current | Allowed baseline |
|---|---:|---:|
| Package Makefiles | $makefiles | at least $MIN_PACKAGE_MAKEFILES |
| Files with skipped source hashes | $hash_skip | at most $MAX_HASH_SKIP_FILES |
| Runtime files mentioning opkg | $opkg_runtime | at most $MAX_OPKG_RUNTIME_FILES |
| Files mentioning IPK artifacts | $ipk_refs | at most $MAX_IPK_REFERENCE_FILES |
| Files using legacy iptables commands | $iptables_refs | at most $MAX_IPTABLES_FILES |
| Makefiles with an APK-invalid leading v version | $leading_v_versions | at most $MAX_LEADING_V_VERSION_FILES |

The baseline is compatibility debt, not a claim that these findings are safe.
CI rejects regressions and the limits must be lowered as packages are migrated.
EOF

status=0

if (( makefiles < MIN_PACKAGE_MAKEFILES )); then
	echo "Package Makefile count dropped from $MIN_PACKAGE_MAKEFILES to $makefiles" >&2
	status=1
fi

for check in \
	"hash skip:$hash_skip:$MAX_HASH_SKIP_FILES" \
	"opkg runtime:$opkg_runtime:$MAX_OPKG_RUNTIME_FILES" \
	"IPK references:$ipk_refs:$MAX_IPK_REFERENCE_FILES" \
	"iptables references:$iptables_refs:$MAX_IPTABLES_FILES" \
	"leading v versions:$leading_v_versions:$MAX_LEADING_V_VERSION_FILES"; do
	IFS=: read -r name current maximum <<<"$check"
	if (( current > maximum )); then
		echo "$name increased from $maximum to $current" >&2
		status=1
	fi
done

cat "$report"
exit "$status"
