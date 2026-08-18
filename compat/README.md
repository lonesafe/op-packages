# OpenWrt compatibility status

The repository is checked against the current OpenWrt `main` build system. The
first audited baseline was OpenWrt commit `00f7f33d2f458484416e87a066ee2e171c1578aa`
on 2026-08-18.

## Current result

- 849 Makefiles were indexed.
- The feed metadata index completes without a package dump error.
- 14 obsolete dependency names, metadata failures, or APK-invalid versions were fixed.
- An APK smoke build for `mipsel_24kc` completed successfully with
  `luci-app-public-ip-monitor-1.0.0-r1.apk`.
- 27 missing third-party dependencies remain tracked in
  `known-missing-dependencies.txt`.
- 21 Kconfig dependency cycles remain tracked in
  `known-kconfig-cycles.txt`.
- 235 package Makefiles still disable source hash verification. New instances
  are rejected by the static baseline, and existing ones must be removed over
  time.

A tracked issue is not considered compatible. Until its dependency or Kconfig
cycle is fixed, install and build that package only after reviewing its source
and target requirements.

## Checks

`scripts/compat/static-check.sh` prevents increases in known source-level debt.
`scripts/compat/check-openwrt.sh` regenerates the feed index and OpenWrt Kconfig
metadata, failing on any issue not recorded in `compat/`.

The CI workflow always tests the latest OpenWrt `main`; a new upstream break is
therefore visible before the compatibility baseline is updated.
