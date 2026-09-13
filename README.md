# OpenWrt 插件源

本仓库基于 [kiddin9/op-packages](https://github.com/kiddin9/op-packages)，保留原始
Git 历史和 GPL-2.0 许可，并面向 OpenWrt 官方 `main` 持续做兼容检查与修复。

## 当前状态

- 上游插件会定时同步，兼容测试每天针对最新 OpenWrt `main` 运行。
- 849 个 Makefile 已通过 feed 索引；当前索引无解析失败。
- 尚有缺失依赖和 Kconfig 循环处于修复队列，因此不能宣称所有插件都已兼容。
- 具体基线、已修复项目和未完成问题见 [兼容状态](compat/README.md)。

## 作为源码 feed 使用

在 OpenWrt 源码根目录执行：

```sh
printf '%s\n' \
  'src-git op_packages https://github.com/lonesafe/op-packages.git' \
  >> feeds.conf
./scripts/feeds update -a
./scripts/feeds install -p op_packages <package-name>
make defconfig
```

建议按需安装单个插件。`./scripts/feeds install -a -p op_packages` 会把仍在兼容
修复队列中的包也装入构建树，适合开发检查，不适合作为稳定固件的默认配置。

OpenWrt `main` 使用 APK 包管理器。源码 feed 本身不区分 IPK/APK，但插件中的运行时
包管理调用必须适配 APK 后才能视为兼容。本仓库没有发布自己的二进制软件源，也绝不
建议关闭软件包签名校验。

## 本地检查

静态检查：

```sh
./scripts/compat/static-check.sh
```

完整元数据检查需要一份已安装官方 feeds 和本 feed 的 OpenWrt 构建树：

```sh
./scripts/compat/check-openwrt.sh /path/to/openwrt op_packages
```

## 维护原则

- 优先使用插件作者和 OpenWrt 官方的最新来源。
- 不覆盖官方已维护且更新的同名包。
- 新的缺失依赖、Kconfig 循环、`opkg` 运行时调用和跳过哈希校验不会静默进入。
- 每次同步保留来源和许可证信息；修复尽量回馈原项目。

本仓库中的软件分别遵循各自上游许可证；仓库维护脚本按根目录 `LICENSE` 发布。
