#!/bin/bash
set -e
W=${1:-$HOME/pdfium-kylin}
REAL="$W/clang13-root/usr/lib/llvm-13/bin"

echo "==> 修复 clang 包装器 (添加 system-include 路径)..."
cat > "$W/clang/bin/clang" <<WRAPPEOF
#!/bin/bash
export LD_LIBRARY_PATH="$W/clang13-root/usr/lib/loongarch64-linux-gnu:$W/clang13-root/usr/lib/llvm-13/lib\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
exec "$REAL/clang-13" -isystem "$W/system-include" "\$@"
WRAPPEOF
chmod +x "$W/clang/bin/clang"

echo "==> 新 clang 包装器内容:"
cat "$W/clang/bin/clang"

echo "==> 验证 jerror.h 可被找到:"
ls -la "$W/system-include/jerror.h"

echo "==> 完成。请重跑: cd ~/pdfium-kylin/pdfium-c13 && time ninja -C out/kylin obj/libpdfium.a 2>&1 | tee /tmp/ninja-build.log | tail -30"
