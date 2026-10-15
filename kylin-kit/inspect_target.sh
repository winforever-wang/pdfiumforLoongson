#!/bin/bash
# 麒麟 V10 (LoongArch64) 目标机构建环境体检脚本
# 用法: bash inspect_target.sh > result.txt 2>&1
# 然后把 result.txt 内容发回来即可

echo "===== 1. 系统版本 ====="
cat /etc/os-release 2>/dev/null | head -4
cat /etc/kylin-build 2>/dev/null
echo "kernel: $(uname -r)  arch: $(uname -m)"

echo ""
echo "===== 2. glibc 版本 ====="
ldd --version 2>/dev/null | head -1

echo ""
echo "===== 3. C/C++ 编译器 ====="
echo "gcc:  $(gcc --version 2>/dev/null | head -1)"
echo "g++:  $(g++ --version 2>/dev/null | head -1)"
for c in clang clang++ clang-15 clang-16 clang-17 clang-18; do
  p=$(command -v $c 2>/dev/null)
  if [ -n "$p" ]; then echo "FOUND $c -> $p : $($c --version 2>/dev/null | head -1)"; fi
done
ls -d /usr/lib/llvm-* /opt/llvm* /usr/local/llvm* 2>/dev/null

echo ""
echo "===== 4. 构建工具 ====="
echo "python3: $(command -v python3) $(python3 --version 2>&1)"
echo "make:    $(command -v make) $(make --version 2>/dev/null | head -1)"
echo "ninja:   $(command -v ninja) $(ninja --version 2>/dev/null)"
echo "gn:      $(command -v gn) $(gn --version 2>/dev/null)"
echo "cmake:   $(command -v cmake) $(cmake --version 2>/dev/null | head -1)"
echo "git:     $(command -v git) $(git --version 2>/dev/null)"
echo "curl:    $(command -v curl)"
echo "tar:     $(command -v tar)"
echo "patch:   $(command -v patch)"

echo ""
echo "===== 5. 包管理器 ====="
for pm in apt apt-get yum dnf; do p=$(command -v $pm 2>/dev/null); [ -n "$p" ] && echo "$pm -> $p"; done

echo ""
echo "===== 6. 网络连通性 ====="
probe() { code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 "$1" 2>/dev/null); echo "$2: $code"; }
probe https://github.com "github.com"
probe https://raw.githubusercontent.com/chromium/chromium/main/build/README.md "raw.github(chromium build)"
probe https://codeload.github.com/ninja-build/ninja/tar.gz/refs/tags/v1.12.1 "codeload.github(ninja源码包)"
probe https://gitee.com "gitee.com"
probe https://gitlab.loongnix.cn "gitlab.loongnix.cn"
probe https://chromium.googlesource.com "chromium.googlesource.com"
probe https://mirrors.loongnix.cn "mirrors.loongnix.cn"

echo ""
echo "===== 7. 资源 ====="
echo "CPU 核数: $(nproc)"
echo "内存:"
free -h 2>/dev/null | head -2
echo "home 磁盘空间:"
df -h ~ 2>/dev/null | tail -1
echo "根磁盘空间:"
df -h / 2>/dev/null | tail -1

echo ""
echo "===== 8. 新编译器搜索（可安装性） ====="
# 检查软件源里有没有新版 gcc / clang 可装
if command -v apt-get >/dev/null 2>&1; then
  apt-cache policy gcc-10 gcc-12 clang clang-15 clang-16 clang-17 2>/dev/null | grep -A1 "^gcc\|^clang" | head -20
elif command -v yum >/dev/null 2>&1; then
  yum list available 'gcc*' 'clang*' 2>/dev/null | grep -iE "gcc1[0-9]|clang-1[5-8]|llvm-1[5-8]" | head -15
fi

echo ""
echo "===== 9. ld 默认搜索路径里的 libstdc++ ====="
ls /usr/lib/loongarch64-linux-gnu/libstdc++* 2>/dev/null || ls /usr/lib64/libstdc++* 2>/dev/null | head -5

echo "===== 体检完成 ====="
