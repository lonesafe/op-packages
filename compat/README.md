# OpenWrt compatibility status

The repository is checked against the current OpenWrt `main` build system. The
first audited baseline was OpenWrt commit `00f7f33d2f458484416e87a066ee2e171c1578aa`
on 2026-08-18.

## Current result

- The latest scheduled snapshot was validated against OpenWrt commit
  `74ab4c432cd9500fb7a543505e3b0e458fd02c8f` on 2026-09-13.
- 860 Makefiles were indexed from the exact snapshot eligible for commit.
- The feed metadata index completes without a package dump error.
- 14 obsolete dependency names, metadata failures, or APK-invalid versions were fixed.
- An APK smoke build for `mipsel_24kc` completed successfully with
  `luci-app-public-ip-monitor-1.0.0-r1.apk`.
- 24 missing third-party dependencies remain tracked in
  `known-missing-dependencies.txt`.
- 19 Kconfig dependency cycles remain tracked in
  `known-kconfig-cycles.txt`.
- 21 package Makefiles still disable source hash verification. New instances
  are rejected by the static baseline, and existing ones must be removed over
  time.
- 136 runtime files still mention `opkg`, 53 files reference IPK artifacts,
  and 213 files use legacy `iptables` commands. These counts are bounded by
  the static baseline and may only decrease.

A tracked issue is not considered compatible. Until its dependency or Kconfig
cycle is fixed, install and build that package only after reviewing its source
and target requirements.

## Checks

`scripts/compat/static-check.sh` prevents increases in known source-level debt.
`scripts/compat/check-openwrt.sh` regenerates the feed index and OpenWrt Kconfig
metadata, failing on any issue not recorded in `compat/`. Kconfig cycles are
scoped to dependency blocks containing at least one package supplied by this
feed, so unrelated cycles in OpenWrt's official feeds are not attributed here.

Runtime checks ignore test directories and CSS because those files are not
installed executable paths. `static-exceptions.tsv` contains narrowly scoped,
reviewed false positives or required compatibility paths. An exception is tied
to its exact generated filename, so a changed upstream asset is reviewed again.

The CI workflow always tests the latest OpenWrt `main`; a new upstream break is
therefore visible before the compatibility baseline is updated.
