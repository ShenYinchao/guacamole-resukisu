#!/usr/bin/env bash
set -euo pipefail

kit_dir="$(pwd)"
kernel_ref=0521dc291cf10bd754fb5ff385e74875c406d577
resukisu_ref=8770c7e324a22895703c4916b8a16520e0b81c79
clang_ref=b5f16aee7b8af4c339972027e91e7e793c2e55d9
mkdir -p diagnostics work-ci
exec > >(tee -a "$kit_dir/diagnostics/build.log") 2>&1
trap 'status=$?; for dir in out-baseline out-root; do for file in .config Module.symvers include/config/kernel.release; do if [[ -f "$kit_dir/work-ci/$dir/$file" ]]; then cp "$kit_dir/work-ci/$dir/$file" "$kit_dir/diagnostics/${dir}-$(basename "$file")"; fi; done; done; exit "$status"' EXIT

cd "$kit_dir/work-ci"
git init kernel
git -C kernel remote add origin https://github.com/LineageOS/android_kernel_oneplus_sm8150.git
git -C kernel fetch --depth=1 origin "$kernel_ref"
git -C kernel checkout --detach FETCH_HEAD
[[ "$(git -C kernel rev-parse HEAD)" == "$kernel_ref" ]]

mkdir clang
curl --fail --location --retry 3 \
  "https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/$clang_ref/clang-r563880c.tar.gz" \
  --output clang.tar.gz
tar -xzf clang.tar.gz -C clang
export PATH="$kit_dir/work-ci/clang/bin:$PATH"
export LD_LIBRARY_PATH="$kit_dir/work-ci/clang/lib:$kit_dir/work-ci/clang/lib64:${LD_LIBRARY_PATH:-}"
clang --version | tee "$kit_dir/diagnostics/compiler.txt"
grep -q 'r563880c' "$kit_dir/diagnostics/compiler.txt"
grep -q '14054515' "$kit_dir/diagnostics/compiler.txt"

export KBUILD_BUILD_USER=root KBUILD_BUILD_HOST=guacamole-build KBUILD_BUILD_VERSION=0
export KBUILD_BUILD_TIMESTAMP='Mon Oct 5 03:06:33 UTC 2026'
export ARCH=arm64
make_args=(ARCH=arm64 LLVM=1 LLVM_IAS=1 CROSS_COMPILE=aarch64-linux-gnu- \
  CROSS_COMPILE_ARM32=arm-linux-gnueabi- CLANG_TRIPLE=aarch64-linux-gnu- \
  CC=clang LD=ld.lld AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy \
  OBJDUMP=llvm-objdump STRIP=llvm-strip HOSTCC=clang HOSTCXX=clang++ \
  HOSTAR=llvm-ar HOSTLD=ld.lld)

# Preserve the original release string for existing vendor modules.
printf '%s\n' '-g0521dc291cf1' > kernel/.scmversion
mkdir out-baseline out-root
cp "$kit_dir/config/original.config" out-baseline/.config
make -C kernel O="$kit_dir/work-ci/out-baseline" "${make_args[@]}" olddefconfig
python3 "$kit_dir/scripts/check_config.py" "$kit_dir/config/original.config" \
  out-baseline/.config baseline "$kit_dir/diagnostics/baseline-config-report.json"
make -C kernel O="$kit_dir/work-ci/out-baseline" "${make_args[@]}" -j"$(nproc)" Image modules
[[ "$(cat out-baseline/include/config/kernel.release)" == '4.14.357-openela-perf-g0521dc291cf1' ]]

# Pin the last ReSukiSU commit before the upstream project renamed itself.
git clone https://github.com/Baka-SU/BakaSU.git kernel/KernelSU
git -C kernel/KernelSU checkout --detach "$resukisu_ref"
[[ "$(git -C kernel/KernelSU rev-parse HEAD)" == "$resukisu_ref" ]]
grep -q 'REPO_NAME := ReSukiSU' kernel/KernelSU/kernel/Kbuild
ln -s ../KernelSU/kernel kernel/drivers/kernelsu
printf '\nobj-$(CONFIG_KSU) += kernelsu/\n' >> kernel/drivers/Makefile
printf '\nsource "drivers/kernelsu/Kconfig"\n' >> kernel/drivers/Kconfig
git -C kernel apply --check "$kit_dir/patches/resukisu.patch"
git -C kernel apply "$kit_dir/patches/resukisu.patch"
git -C kernel diff > "$kit_dir/diagnostics/applied.patch"

cp "$kit_dir/config/original.config" out-root/.config
kernel/scripts/config --file out-root/.config \
  --enable KSU --enable KSU_MANUAL_HOOK --disable KSU_TRACEPOINT_HOOK \
  --disable KSU_SUSFS --enable KSU_MULTI_MANAGER_SUPPORT \
  --enable KSU_MANUAL_HOOK_AUTO_SETUID_HOOK \
  --enable KSU_MANUAL_HOOK_AUTO_INITRC_HOOK --enable KSU_MANUAL_HOOK_AUTO_INPUT_HOOK
make -C kernel O="$kit_dir/work-ci/out-root" "${make_args[@]}" olddefconfig
python3 "$kit_dir/scripts/check_config.py" "$kit_dir/config/original.config" \
  out-root/.config root "$kit_dir/diagnostics/root-config-report.json"
grep -qx 'CONFIG_KSU_MANUAL_HOOK=y' out-root/.config
make -C kernel O="$kit_dir/work-ci/out-root" "${make_args[@]}" -j"$(nproc)" Image modules
[[ "$(cat out-root/include/config/kernel.release)" == '4.14.357-openela-perf-g0521dc291cf1' ]]
python3 "$kit_dir/scripts/check_abi.py" out-baseline/Module.symvers \
  out-root/Module.symvers "$kit_dir/diagnostics/abi-report.json"

mkdir "$kit_dir/dist"
cp out-root/arch/arm64/boot/Image "$kit_dir/dist/Image"
cp out-root/.config "$kit_dir/dist/kernel.config"
cp "$kit_dir/diagnostics/abi-report.json" "$kit_dir/dist/"
cat > "$kit_dir/dist/BUILD-INFO.txt" <<EOF
Device: OnePlus 7 Pro / guacamole
ROM: lineage-23.2-20261005-nightly-guacamole
Kernel source: $kernel_ref
ReSukiSU source: $resukisu_ref
Compiler source: $clang_ref / clang-r563880c / build 14054515
Original boot SHA256: 94ca2a8b36eae84f4b8ad84586de71329edf28988b70c6f258d416af823e3fa7
Original kernel release: 4.14.357-openela-perf-g0521dc291cf1
Candidate only: Image is NOT a boot image. Do not flash it directly.
Runtime boot, recovery and Wi-Fi compatibility have NOT been tested.
No SUSFS patches are included.
EOF
cd "$kit_dir/dist"
sha256sum Image kernel.config abi-report.json BUILD-INFO.txt > SHA256SUMS
echo 'Candidate built. Review diagnostics and repack the original boot before any device test.'
