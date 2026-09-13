#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
report=${1:-"$repo_root/compat/static-report.md"}
findings_dir=${STATIC_FINDINGS_DIR:-"$(dirname "$report")/static-findings"}

# shellcheck disable=SC1091
source "$repo_root/compat/baseline.env"

cd "$repo_root"
mkdir -p "$findings_dir" "$(dirname "$report")"

collect_matching_files() {
	local output=$1
	local pattern=$2
	shift 2
	{
		rg -l "$pattern" \
			--glob '!.git/**' \
			--glob '!.github/**' \
			--glob '!compat/**' \
			--glob '!scripts/**' \
			"$@" . || true
	} | sort -u >"$output"
}

filter_reviewed_exceptions() {
	local check=$1
	local findings=$2
	local filtered="${findings}.filtered"

	awk -F '\t' -v check="$check" -v reviewed="$findings_dir/reviewed-exceptions.tsv" '
		NR == FNR {
			if ($0 !~ /^[[:space:]]*(#|$)/ && $1 == check)
				exceptions[$2] = $0
			next
		}
		$0 in exceptions {
			print exceptions[$0] >> reviewed
			next
		}
		{ print }
	' "$repo_root/compat/static-exceptions.tsv" "$findings" >"$filtered"
	mv "$filtered" "$findings"
}

: >"$findings_dir/reviewed-exceptions.tsv"

collect_matching_files "$findings_dir/hash-skips.txt" \
	'PKG_(MIRROR_)?HASH\s*:?=\s*(skip|x)' --glob '**/Makefile'
collect_matching_files "$findings_dir/opkg-runtime.txt" \
	'\bopkg\b' --glob '!README*' --glob '!**/*.po' --glob '!**/*.pot' --glob '!**/*.css' \
	--glob '!**/test/**' --glob '!**/tests/**' --glob '!**/Makefile'
collect_matching_files "$findings_dir/ipk-references.txt" \
	'\.ipk\b' --glob '!README*' --glob '!**/*.po' --glob '!**/*.pot' --glob '!**/*.css' \
	--glob '!**/test/**' --glob '!**/tests/**'
collect_matching_files "$findings_dir/iptables-references.txt" \
	'\biptables(-save|-restore)?\b' --glob '!**/*.po' --glob '!**/*.pot' --glob '!**/*.css' \
	--glob '!**/test/**' --glob '!**/tests/**'
collect_matching_files "$findings_dir/leading-v-versions.txt" \
	'^PKG_VERSION:=v' --glob '**/Makefile'

filter_reviewed_exceptions opkg-runtime "$findings_dir/opkg-runtime.txt"
filter_reviewed_exceptions ipk-references "$findings_dir/ipk-references.txt"
filter_reviewed_exceptions iptables-references "$findings_dir/iptables-references.txt"
sort -u -o "$findings_dir/reviewed-exceptions.tsv" "$findings_dir/reviewed-exceptions.tsv"

makefiles=$(find . -name Makefile -type f -not -path './.git/*' | wc -l | tr -d ' ')
hash_skip=$(wc -l <"$findings_dir/hash-skips.txt" | tr -d ' ')
opkg_runtime=$(wc -l <"$findings_dir/opkg-runtime.txt" | tr -d ' ')
ipk_refs=$(wc -l <"$findings_dir/ipk-references.txt" | tr -d ' ')
iptables_refs=$(wc -l <"$findings_dir/iptables-references.txt" | tr -d ' ')
leading_v_versions=$(wc -l <"$findings_dir/leading-v-versions.txt" | tr -d ' ')

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
Tests, CSS, and narrowly reviewed exceptions are excluded from the runtime counts.
Detailed file lists and matched exceptions are stored in the static-findings artifact.
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
		echo "$name increased from $maximum to $current; inspect $findings_dir" >&2
		status=1
	fi
done

cat "$report"
exit "$status"
