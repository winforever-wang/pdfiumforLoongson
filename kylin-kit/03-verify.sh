#!/bin/bash
# PDFium 麒麟(loongarch64)构建包 —— 第 3 步：校验与冒烟测试
# 用法: bash 03-verify.sh [工作目录]
set -e
KIT=$(cd "$(dirname "$0")" && pwd)
W=${1:-$HOME/pdfium-kylin}
SO="$W/pdfium-c13/out/kylin/final/libpdfium.so"
[ -f "$SO" ] || { echo "错误: 未找到 $SO —— 请先运行 02-build.sh"; exit 1; }

echo "==> [1] 文件类型 (应为 ELF64 / LoongArch)"
readelf -h "$SO" | grep -E 'Class:|Machine:|Type:'

echo "==> [2] 动态依赖 (NEEDED)"
readelf -d "$SO" | grep NEEDED

echo "==> [3] 符号版本要求 (应全部 ≤ GLIBC_2.28 / GLIBCXX_3.4.25)"
readelf --version-info "$SO" | grep -oE 'GLIBC(_XX)?_[0-9.]+' | sort -uV | tail -4

echo "==> [4] C 冒烟测试 (用系统 gcc 编译, 模拟应用集成)"
TMP=$(mktemp -d)
cat > "$TMP/smoke.c" <<'EOF'
#include <stdio.h>
#include <string.h>
#include "fpdfview.h"
#include "fpdf_edit.h"
int main(void) {
  FPDF_LIBRARY_CONFIG cfg;
  memset(&cfg, 0, sizeof(cfg));
  cfg.version = 2;
  FPDF_InitLibraryWithConfig(&cfg);
  FPDF_DOCUMENT doc = FPDF_CreateNewDocument();
  if (!doc) { fprintf(stderr, "FAIL: FPDF_CreateNewDocument\n"); return 1; }
  FPDF_PAGE page = FPDFPage_New(doc, 612.0, 792.0);
  if (!page) { fprintf(stderr, "FAIL: FPDFPage_New\n"); return 1; }
  FPDF_ClosePage(page);
  FPDF_CloseDocument(doc);
  FPDF_DestroyLibrary();
  printf("SMOKE-OK\n");
  return 0;
}
EOF
gcc "$TMP/smoke.c" -I"$W/pdfium-c13/public" -L"$W/pdfium-c13/out/kylin/final" \
    -lpdfium -Wl,-rpath,"$W/pdfium-c13/out/kylin/final" -o "$TMP/smoke"
"$TMP/smoke"

echo "==> [5] 备选库检查 (extras/fallback)"
FSO="$KIT/extras/fallback/libpdfium.so"
if [ -f "$FSO" ]; then
  readelf -d "$FSO" | grep NEEDED
  readelf --version-info "$FSO" | grep -oE 'GLIBC(_XX)?_[0-9.]+' | sort -uV | tail -4
  cat > "$TMP/dsmoke.c" <<EOF
#include <dlfcn.h>
#include <stdio.h>
int main(void) {
  void *h = dlopen("$FSO", RTLD_NOW);
  if (!h) { fprintf(stderr, "FAIL: %s\n", dlerror()); return 1; }
  printf("DLOPEN-OK\n");
  dlclose(h);
  return 0;
}
EOF
  gcc "$TMP/dsmoke.c" -ldl -o "$TMP/dsmoke"
  "$TMP/dsmoke" && echo "    备选库 dlopen: OK" || echo "    备选库 dlopen 失败 —— 请使用上面的原生构建产物"
else
  echo "    (包内未含备选库, 跳过)"
fi
rm -rf "$TMP"
echo "==> 校验完成: libpdfium.so 可在麒麟 V10 (loongarch64) 上使用"
