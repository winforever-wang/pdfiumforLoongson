#!/bin/bash
# PDFium 麒麟(loongarch64)构建包 —— 第 2 步：原生编译
# 用法: bash 02-build.sh [工作目录]   (默认 ~/pdfium-kylin, 须与 01-prepare.sh 一致)
set -e
KIT=$(cd "$(dirname "$0")" && pwd)
W=${1:-$HOME/pdfium-kylin}
[ -d "$W/pdfium-c13" ] || { echo "错误: 未找到 $W/pdfium-c13 —— 请先运行 01-prepare.sh"; exit 1; }

export PATH="$W/clang/bin:$W/bin:$PATH"
export LD_LIBRARY_PATH="$W/clang13-root/usr/lib/loongarch64-linux-gnu:$W/clang13-root/usr/lib/llvm-13/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

SRC="$W/pdfium-c13"
cd "$SRC"
mkdir -p out/kylin
cat > out/kylin/args.gn <<EOF
clang_base_path = "$W/clang"
clang_version = "13"
target_cpu = "loong64"
is_debug = false
symbol_level = 0
use_custom_libcxx = false
use_glib = false
use_lld = false
use_thin_lto = false
treat_warnings_as_errors = false
clang_use_chrome_plugins = false
simple_template_names = false
pdf_is_complete_lib = true
pdf_is_standalone = false
pdf_enable_v8 = false
pdf_enable_xfa = false
pdf_use_partition_alloc = false
use_system_libjpeg = true
use_system_libpng = true
EOF

echo "==> gn gen..."
# 预编译 gn 二进制在此机器 segfault, 需从源码编译
# gn 源码已打包在 kit 中 (gn-src.tar.xz), 无需网络
if [ ! -x "$W/bin/gn_src_ok" ]; then
  echo "    从源码编译 gn (使用 kit 中的 gn-src.tar.xz) ..."
  [ -f "$KIT/gn-src.tar.xz" ] || { echo "错误: 未找到 $KIT/gn-src.tar.xz"; exit 1; }
  rm -rf "$W/gn-build"
  mkdir -p "$W/gn-build"
  tar xJf "$KIT/gn-src.tar.xz" -C "$W/gn-build" --strip-components=1

  echo "    应用补充补丁 (tarball 未含的 C++17 兼容性修复)..."
  GNS="$W/gn-build/src/gn"

  # const char[] → std::string_view (使 .size() 可用)
  sed -i 's|const char kTrimPrefix\[\] = "trim "|std::string_view kTrimPrefix = "trim "|' "$GNS/input_conversion.cc"
  sed -i 's|const char kSubsytemPrefix\[\] = "/SUBSYSTEM:"|std::string_view kSubsytemPrefix = "/SUBSYSTEM:"|' "$GNS/visual_studio_utils.cc"
  sed -i 's|const char\* kXCTestFileSuffixes\[\]|std::string_view kXCTestFileSuffixes[]|' "$GNS/xcode_writer.cc"
  sed -i 's|const char kXCTestModuleTargetNamePostfix\[\] = "_module"|std::string_view kXCTestModuleTargetNamePostfix = "_module"|' "$GNS/xcode_writer.cc"
  sed -i 's|const char kXCUITestRunnerTargetNamePostfix\[\] = "_runner"|std::string_view kXCUITestRunnerTargetNamePostfix = "_runner"|' "$GNS/xcode_writer.cc"

  # last_commit_position.h (--no-last-commit-position 不生成此文件)
  cat > "$GNS/last_commit_position.h" <<'HPPEOF'
#pragma once
#define LAST_COMMIT_POSITION "unknown"
#define LAST_COMMIT_POSITION_NUM 0
HPPEOF

  # std::ranges::all_of (C++20) → std::all_of + 显式迭代器 (C++17)
  sed -i 's|std::ranges::all_of(\([^,]*\),|std::all_of(\1.begin(), \1.end(),|' "$GNS/parse_tree_unittest.cc"

  mkdir -p /tmp/gn_fakebin
  printf '#!/bin/sh\necho "v1.0.0"\n' > /tmp/gn_fakebin/git
  chmod +x /tmp/gn_fakebin/git

  cd "$W/gn-build"
  echo "    运行 gen.py (生成 build.ninja) ..."
  PATH="/tmp/gn_fakebin:$PATH" CC=clang CXX=clang++ python3 build/gen.py \
    --platform linux --allow-warnings --no-last-commit-position 2>&1 | tail -10

  if [ -f out/build.ninja ]; then
    echo "    编译 gn (ninja)..."
    PATH="/tmp/gn_fakebin:$PATH" "$W/bin/ninja" -C out 2>&1 | tail -15
  else
    echo "    gen.py 未生成 build.ninja, 诊断:"
    ls -la out/ 2>/dev/null | head -10
  fi

  rm -rf /tmp/gn_fakebin

  if [ -x out/gn ]; then
    cp out/gn "$W/bin/gn"
    chmod +x "$W/bin/gn"
    if "$W/bin/gn" --version >/dev/null 2>&1; then
      echo "    gn 源码编译成功!"
      printf '#!/bin/sh\nexit 0\n' > "$W/bin/gn_src_ok"
      chmod +x "$W/bin/gn_src_ok"
    else
      echo "    gn 编译完成但运行失败, 尝试诊断..."
      file out/gn
      ldd out/gn 2>&1 | head -5
    fi
  else
    echo "    gn 编译未产出二进制"
    ls -la out/ 2>/dev/null | head -10
  fi

  cd "$SRC"
  if [ ! -x "$W/bin/gn_src_ok" ]; then
    echo "==> gn 源码编译失败, 无法继续"
    exit 1
  fi
fi

"$W/bin/gn" gen out/kylin

echo "==> 编译 (8 核约 20~60 分钟; 中断后重跑本脚本会增量续编)..."
time ninja -C out/kylin obj/libpdfium.a

echo "==> 链接 libpdfium.so..."
mkdir -p out/kylin/final
JPEG=""
for c in /usr/lib/loongarch64-linux-gnu/libjpeg.so.62 \
         /usr/lib/loongarch64-linux-gnu/libjpeg.so.8 \
         /usr/lib/loongarch64-linux-gnu/libjpeg.so; do
  [ -e "$c" ] && JPEG="$c" && break
done
if [ -n "$JPEG" ]; then
  echo "    使用系统 libjpeg: $JPEG"
  clang++ -shared -Wl,-soname,libpdfium.so \
    -Wl,--whole-archive out/kylin/obj/libpdfium.a -Wl,--no-whole-archive \
    -lpthread -lm -ldl -lstdc++ -lgcc_s "$JPEG" \
    -o out/kylin/final/libpdfium.so
else
  echo "    警告: 未找到系统 libjpeg 运行库, jpeg 解码符号保持未定义 (详见 README 常见问题)"
  clang++ -shared -Wl,-soname,libpdfium.so \
    -Wl,--whole-archive out/kylin/obj/libpdfium.a -Wl,--no-whole-archive \
    -lpthread -lm -ldl -lstdc++ -lgcc_s \
    -o out/kylin/final/libpdfium.so
fi
ls -la out/kylin/final/libpdfium.so
echo "==> 编译完成。下一步: bash 03-verify.sh"
