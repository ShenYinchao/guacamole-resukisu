# 一加 7 Pro：LineageOS 23.2 的 ReSukiSU 编译准备

仅针对 `lineage-23.2-20261005-nightly-guacamole` 和内核
`4.14.357-openela-perf-g0521dc291cf1`。

这是构建文件，不是已经编译并验证能开机的刷机包。

## 上传到 GitHub

1. 登录自己的 GitHub，新建空仓库（例如 `guacamole-resukisu`）。
2. 将本文件所在目录里的所有内容上传至仓库根目录。保留 `.github/workflows/build.yml` 的目录结构。
3. 不要只上传整个 ZIP，也不要再套一层 `guacamole-resukisu-build` 文件夹。
4. 打开仓库的 Actions。如有启用提示，先启用 Actions。
5. 选择 `Build guacamole ReSukiSU` → `Run workflow` → 确认运行。
6. 完成后下载 Artifacts 中的 diagnostics 和 candidate 两个结果。
7. 将构建结果或失败日志带回本次对话。此时先不要刷手机。

不用上传账号密码、访问令牌、手机序列号、原始 boot.img 或完整 ROM。
私有仓库会使用账号的 Actions 配额；不要为了构建开启付费额度。

## 构建做什么

- 使用与手机内核编号对应的完整 LineageOS 源码提交。
- 使用原始 boot.img 中提取的完整配置。
- 要求与原内核相同的 Clang r563880c、构建号 14054515。
- 先编译未加 root 的基线，再集成固定版本的 ReSukiSU 并编译。
- ReSukiSU 源码固定为上游更名 BakaSU 前的最后一个提交；仓库地址自动迁移后的名称不改变这个提交的内容。
- 使用非 GKI 手动钩子，不加入 SUSFS。
- 检查配置变化、内核 release 字符串和基线/修改版导出符号 CRC。
- 任一检查失败就停止，不上传候选内核。

上述检查不等于手机实测，也不完全证明与已安装的 vendor 模块兼容。
后续仍需要打包原始 boot、核验管理器，以及测试启动、Recovery、Wi-Fi、蓝牙、通话等。

## 保留恢复文件

保留电脑原始 `boot.img`（本次找到的位置为 `C:\Users\shen\Downloads\boot.img`）。
其 SHA-256 为：

`94ca2a8b36eae84f4b8ad84586de71329edf28988b70c6f258d416af823e3fa7`

编译结果里的 `Image` 是内核本体，不能当成 `boot.img` 直接刷。
本构建目录内没有自动刷手机、清空手机或重新锁定 Bootloader 的步骤。

## 上游来源和许可

- LineageOS 内核：https://github.com/LineageOS/android_kernel_oneplus_sm8150
- ReSukiSU（现仓库地址）：https://github.com/Baka-SU/BakaSU
- 非 GKI 安装说明：https://resukisu.org/zh-Hans/guide/install/nongki.html
- 手动钩子参考：https://resukisu.org/zh-Hans/guide/manual-integrate.html
- 编译器：https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/

内核修改遵循上游内核的 GPL-2.0 许可；ReSukiSU 及工具链按各自仓库许可使用。
