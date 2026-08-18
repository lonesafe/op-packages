#!/usr/bin/env bash

set -euo pipefail

if (( $# < 2 || $# > 3 )); then
	echo "Usage: $0 <openwrt-root> <feed-name> [report-path]" >&2
	exit 2
fi

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
openwrt_root=$(cd "$1" && pwd)
feed_name=$2
report=${3:-"$repo_root/compat/openwrt-main-report.md"}
log_dir=${COMPAT_LOG_DIR:-"$(dirname "$report")/logs"}

mkdir -p "$log_dir" "$(dirname "$report")"

feed_log="$log_dir/feed-update.log"
config_log="$log_dir/defconfig.log"
actual_missing="$log_dir/missing-dependencies.txt"
actual_cycles="$log_dir/kconfig-cycles.txt"
known_missing="$log_dir/known-missing-dependencies.txt"
known_cycles="$log_dir/known-kconfig-cycles.txt"
unexpected_missing="$log_dir/unexpected-missing-dependencies.txt"
unexpected_cycles="$log_dir/unexpected-kconfig-cycles.txt"

cd "$openwrt_root"

feed_rc=0
./scripts/feeds update -i "$feed_name" >"$feed_log" 2>&1 || feed_rc=$?

config_rc=0
make defconfig >"$config_log" 2>&1 || config_rc=$?

grep "^WARNING: Makefile 'package/feeds/$feed_name/" "$config_log" \
	| sed -E "s#^WARNING: Makefile 'package/feeds/$feed_name/([^/]+)/Makefile'.* dependency on '([^']+)'.*#\1:\2#" \
	| sort -u >"$actual_missing" || true

sed -n '/error: recursive dependency detected!/{n;s/.*symbol \(PACKAGE_[^ ]*\).*/\1/p;}' \
	"$config_log" | sort -u >"$actual_cycles"

grep -Ev '^[[:space:]]*(#|$)' "$repo_root/compat/known-missing-dependencies.txt" \
	| sort -u >"$known_missing"
grep -Ev '^[[:space:]]*(#|$)' "$repo_root/compat/known-kconfig-cycles.txt" \
	| sort -u >"$known_cycles"

comm -13 "$known_missing" "$actual_missing" >"$unexpected_missing"
comm -13 "$known_cycles" "$actual_cycles" >"$unexpected_cycles"

feed_errors=$(grep -c "ERROR: please fix feeds/$feed_name/" "$feed_log" || true)
missing_count=$(wc -l <"$actual_missing" | tr -d ' ')
cycle_count=$(wc -l <"$actual_cycles" | tr -d ' ')
unexpected_missing_count=$(wc -l <"$unexpected_missing" | tr -d ' ')
unexpected_cycle_count=$(wc -l <"$unexpected_cycles" | tr -d ' ')
openwrt_revision=$(git rev-parse HEAD)

markdown_list() {
	local file=$1
	if [[ -s "$file" ]]; then
		awk '{ print "- `" $0 "`" }' "$file"
	else
		echo '- None'
	fi
}

{
	echo '# OpenWrt compatibility report'
	echo
	echo "- OpenWrt revision: \`$openwrt_revision\`"
	echo "- Feed: \`$feed_name\`"
	echo "- Feed index errors: $feed_errors"
	echo "- Known missing dependencies still present: $missing_count"
	echo "- Known Kconfig cycles still present: $cycle_count"
	echo "- Unexpected missing dependencies: $unexpected_missing_count"
	echo "- Unexpected Kconfig cycles: $unexpected_cycle_count"
	echo
	echo '## Unexpected missing dependencies'
	echo
	markdown_list "$unexpected_missing"
	echo
	echo '## Unexpected Kconfig cycles'
	echo
	markdown_list "$unexpected_cycles"
	echo
	echo 'Known findings are tracked in `compat/` and remain compatibility debt.'
} >"$report"

cat "$report"

if (( feed_rc != 0 || config_rc != 0 || feed_errors != 0 || unexpected_missing_count != 0 || unexpected_cycle_count != 0 )); then
	exit 1
fi
