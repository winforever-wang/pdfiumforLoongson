#!/bin/bash
# PDFium 麒麟(loongarch64)构建包 —— 第 1 步：解包并准备环境
# 用法: bash 01-prepare.sh [工作目录]   (默认 ~/pdfium-kylin)
set -e
KIT=$(cd "$(dirname "$0")" && pwd)
W=${1:-$HOME/pdfium-kylin}

echo "==> kit 目录: $KIT"
echo "==> 工作目录: $W"

case "$W" in
  *[[:space:]]*) echo "错误: 工作目录路径不能包含空格"; exit 1 ;;
esac

# ---- 环境检查 ----
[ "$(uname -m)" = "loongarch64" ] || { echo "错误: 目标机架构不是 loongarch64 (实际: $(uname -m))"; exit 1; }
[ -x /usr/bin/gcc ] || { echo "错误: 未找到 /usr/bin/gcc"; exit 1; }
[ -d /usr/include/c++/8 ] || { echo "错误: 未找到 /usr/include/c++/8 —— 需要 gcc-8 的 C++ 头文件 (libstdc++-8-dev 包)"; exit 1; }
AVAIL=$(df -Pk "$(dirname "$W")" | awk 'NR==2{print int($4/1048576)}')
echo "==> 目标分区可用空间约 ${AVAIL} GB (需要 ≥ 6 GB)"
[ "${AVAIL:-0}" -ge 6 ] || { echo "错误: 磁盘空间不足"; exit 1; }

mkdir -p "$W"

echo "==> [1/6] 解压 clang 工具链..."
tar xf "$KIT/clang13-root.tar.xz" -C "$W"
[ -x "$W/clang13-root/usr/lib/llvm-13/bin/clang-13" ] || { echo "错误: clang13-root 解压不完整"; exit 1; }

echo "==> [2/6] 解压 pdfium 源码..."
tar xf "$KIT/pdfium-src.tar.xz" -C "$W"
[ -d "$W/pdfium-c13" ] || { echo "错误: 源码解压不完整"; exit 1; }

echo "==> [3/6] 安装 ninja (gn 将在 02-build.sh 中从源码编译)..."
mkdir -p "$W/bin"
cp "$KIT/ninja" "$W/bin/ninja"
chmod +x "$W/bin/ninja"
"$W/bin/ninja" --version

echo "==> [4/6] 准备 C++ 头文件目录 (系统 gcc-8 头 + C++20 兼容补丁)..."
rm -rf "$W/cxx-headers"
mkdir -p "$W/cxx-headers"
cp -a /usr/include/c++/8/. "$W/cxx-headers/"
if [ -d /usr/include/loongarch64-linux-gnu/c++/8 ]; then
  mkdir -p "$W/cxx-headers/loongarch64-linux-gnu"
  cp -a /usr/include/loongarch64-linux-gnu/c++/8/. "$W/cxx-headers/loongarch64-linux-gnu/"
fi
for f in array bit concepts ranges version; do
  cp "$KIT/extras/cxx-shims/$f" "$W/cxx-headers/$f"
done

echo "==> [5/6] 准备 jpeg/png 系统头..."
mkdir -p "$W/system-include"
cp "$KIT"/extras/system-include/* "$W/system-include/"

echo "==> [6/6] 生成包装编译器..."
REAL="$W/clang13-root/usr/lib/llvm-13/bin"
mkdir -p "$W/clang/bin"
for t in clang-13 llvm-ar llvm-nm llvm-readelf llvm-objcopy llvm-strip ld.lld lld; do
  ln -sfn "$REAL/$t" "$W/clang/bin/$t"
done
cat > "$W/clang/bin/clang" <<EOF
#!/bin/bash
export LD_LIBRARY_PATH="$W/clang13-root/usr/lib/loongarch64-linux-gnu:$W/clang13-root/usr/lib/llvm-13/lib\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
exec "$REAL/clang-13" "\$@"
EOF
cat > "$W/clang/bin/clang++" <<EOF
#!/bin/bash
export LD_LIBRARY_PATH="$W/clang13-root/usr/lib/loongarch64-linux-gnu:$W/clang13-root/usr/lib/llvm-13/lib\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
exec "$REAL/clang-13" --driver-mode=g++ -nostdinc++ -isystem "$W/cxx-headers" -isystem "$W/cxx-headers/loongarch64-linux-gnu" -isystem "$W/cxx-headers/backward" -isystem "$W/system-include" "\$@"
EOF
chmod +x "$W/clang/bin/clang" "$W/clang/bin/clang++"

echo "==> [6.5/6] 链接 clang 运行时库 (解决版本路径 13 vs 13.0.1 不匹配)..."
CLANG_RT_SRC="$W/clang13-root/usr/lib/llvm-13/lib/clang/13.0.1/lib/linux"
CLANG_RT_DST="$W/clang/lib/clang/13/lib/linux"
mkdir -p "$CLANG_RT_DST"
if [ -d "$CLANG_RT_SRC" ]; then
  for f in "$CLANG_RT_SRC"/*.a; do
    [ -f "$f" ] && ln -sfn "$f" "$CLANG_RT_DST/$(basename "$f")"
  done
  echo "    已链接: $(ls "$CLANG_RT_DST" | wc -l) 个运行时库文件"
else
  echo "    警告: 未找到 $CLANG_RT_SRC, 跳过链接"
fi

echo "==> 工具链自检..."
printf 'int main(){return 0;}\n' > /tmp/pdfium_kit_hello.c
printf '#include <vector>\n#include <string>\nint main(){std::vector<std::string> v; v.push_back("ok"); return v.size()==1?0:1;}\n' > /tmp/pdfium_kit_hello.cpp
if ! "$W/clang/bin/clang" /tmp/pdfium_kit_hello.c -o /tmp/pdfium_kit_hello_c 2>/tmp/pdfium_kit_c.err; then
  echo "    C 自检失败, 错误如下:"; cat /tmp/pdfium_kit_c.err; exit 1
fi
/tmp/pdfium_kit_hello_c && echo "    C 编译+运行: OK" || { echo "    C 程序运行失败"; exit 1; }
if ! "$W/clang/bin/clang++" /tmp/pdfium_kit_hello.cpp -o /tmp/pdfium_kit_hello_cxx -lstdc++ -lgcc_s 2>/tmp/pdfium_kit_cxx.err; then
  echo "    C++ 自检失败, 完整错误如下:"
  cat /tmp/pdfium_kit_cxx.err
  echo "    ---- 当前 clang++ 包装器内容 ----"
  cat "$W/clang/bin/clang++"
  exit 1
fi
/tmp/pdfium_kit_hello_cxx && echo "    C++ 编译+运行: OK" || { echo "    C++ 程序运行失败"; exit 1; }

echo "==> 准备完成。下一步: bash 02-build.sh"
