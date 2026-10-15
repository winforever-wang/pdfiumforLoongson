# PDFium 银河麒麟 V10 (龙芯 LoongArch64) 构建包

本包用于在银河麒麟桌面操作系统 V10 SP1（loongarch64，旧世界 ABI）上，从源码
**原生编译** PDFium，产出 `libpdfium.so` 动态库。

- 源码版本：pdfium（GitHub 镜像 2025-11-19，DEPS build_revision 371ecb08）
- 目标系统：银河麒麟桌面 V10 SP1（Build 20250417，内核 5.4.18-168-generic）
- 目标架构：loongarch64（3A5000 / 3A6000，旧世界 ABI）
- 产物：`libpdfium.so`（不含 V8 / XFA）
- **全程离线**：不需要网络，gn / ninja / clang 均随包提供

## 包内容

| 文件 | 说明 |
|---|---|
| `01-prepare.sh` | 解包并准备构建环境（在目标机运行）|
| `02-build.sh` | 原生编译（在目标机运行）|
| `03-verify.sh` | 校验产物 + 冒烟测试（在目标机运行）|
| `00-README.md` | 本说明 |
| `pdfium-src.tar.xz` | 已打好全部补丁的 pdfium 源码树 |
| `clang13-root.tar.xz` | 原生 loongarch64 clang-13 工具链（龙芯 Loongnix 版 LLVM/Clang）|
| `gn` | 静态链接的 loongarch64 gn 二进制（免安装）|
| `ninja` | loongarch64 ninja 二进制（免安装）|
| `extras/cxx-shims/` | 5 个 C++20 兼容头（array/bit/concepts/ranges/version，弥补 gcc-8 libstdc++ 缺口）|
| `extras/system-include/` | libjpeg / libpng 头文件（仅编译期使用）|
| `extras/fallback/` | 备选：交叉编译好的 `libpdfium.so`（见"备选方案"）|

## 系统要求

- 银河麒麟桌面 V10 SP1，loongarch64，glibc 2.28（系统自带即可）
- 已安装 gcc 8.3（系统默认自带，`gcc --version` 能看到即可）
- gcc-8 的 C++ 头文件在位（`/usr/include/c++/8` 存在）
- 磁盘剩余 ≥ 6 GB，内存 ≥ 8 GB
- 不需要 python、cmake、git

## 使用步骤

把整个 `kylin-kit` 目录拷贝到目标机（U 盘 / 内网传输均可，路径不要含空格），然后：

```bash
cd ~/kylin-kit
bash 01-prepare.sh      # 解包到 ~/pdfium-kylin，并自检工具链（含 C/C++ 编译运行测试）
bash 02-build.sh        # 原生编译，8 核约 20~60 分钟
bash 03-verify.sh       # 校验 ELF 属性 + C 程序冒烟测试
```

产物位置：

- `~/pdfium-kylin/pdfium-c13/out/kylin/final/libpdfium.so` —— 动态库
- `~/pdfium-kylin/pdfium-c13/public/` —— 集成用头文件（fpdfview.h 等）
- `~/pdfium-kylin/pdfium-c13/out/kylin/obj/libpdfium.a` —— 静态库（如需静态集成）

## 产物说明（重要）

1. **运行时依赖**：`libpdfium.so` 需要
   - `libstdc++.so.6`（系统自带即可）
   - `libjpeg.so.62`（系统一般已装；若缺：`sudo apt install libjpeg62-turbo`）
   - `libc / libm / libpthread / libdl / libgcc_s`（系统自带）
   - 无其他依赖（无 X11 / fontconfig / glib 要求）
2. **初始化**：使用前调用 `FPDF_InitLibraryWithConfig`（`version=2`，各字段清零），
   退出前调用 `FPDF_DestroyLibrary()`。
3. **集成方式**：
   - 编译期：`gcc app.c -I<路径>/public -L<路径> -lpdfium -o app`
   - 运行期：把 `libpdfium.so` 所在目录加入 `LD_LIBRARY_PATH`，或安装到
     `/usr/lib/loongarch64-linux-gnu/` 并执行 `sudo ldconfig`
   - `dlopen` 加载也可以（03-verify.sh 里有示例）
4. 头文件入口为 `fpdfview.h`，其余 API 头（fpdf_edit.h、fpdf_text.h 等）同目录。

## 备选方案（extras/fallback/）

若目标机原生编译遇到问题，可直接使用包内**交叉编译好的备选库**
`extras/fallback/libpdfium.so`：

- 与原生构建使用同一份源码、同一套配置，仅工具链不同
- 符号版本要求最高 GLIBC_2.27，麒麟 glibc 2.28 直接满足
- 依赖：libpthread / libm / libdl / libjpeg.so.62 / libstdc++.so.6 / libgcc_s / libc
- 若极端情况下报 GLIBCXX 版本错误，把捆绑的 libstdc++ 加入搜索路径：
  ```bash
  export LD_LIBRARY_PATH=/路径/extras/fallback:$LD_LIBRARY_PATH
  ```

## 常见问题

**Q: clang 报 `error while loading shared libraries: libLLVM-13.so.1`**
A: `LD_LIBRARY_PATH` 未生效。02-build.sh 已自动设置；手工调试 clang 时先执行：
```bash
export LD_LIBRARY_PATH=~/pdfium-kylin/clang13-root/usr/lib/loongarch64-linux-gnu:$LD_LIBRARY_PATH
```

**Q: 编译中断了**
A: 直接重跑 `bash 02-build.sh`，ninja 会增量续编。

**Q: 想改配置（比如开 XFA）**
A: 编辑 `~/pdfium-kylin/pdfium-c13/out/kylin/args.gn` 后执行：
```bash
export PATH=~/pdfium-kylin/clang/bin:~/pdfium-kylin/bin:$PATH
export LD_LIBRARY_PATH=~/pdfium-kylin/clang13-root/usr/lib/loongarch64-linux-gnu:$LD_LIBRARY_PATH
cd ~/pdfium-kylin/pdfium-c13
~/pdfium-kylin/bin/gn gen out/kylin && ninja -C out/kylin obj/libpdfium.a
```
注意：本包仅对 V8=false / XFA=false 配置做过验证，开启后可能引入更多依赖。

**Q: 提示 jpeg 符号未定义（jpeg_CreateDecompress 等）**
A: 02-build.sh 链接阶段没找到系统 libjpeg。安装运行库后重跑 02-build.sh：
```bash
sudo apt install libjpeg62-turbo
```

**Q: 应用以 RTLD_NOW 方式 dlopen 本库**
A: 建议按上面安装 libjpeg62-turbo，保证 NEEDED 全部可解析。

## 验证记录

- 同一份源码 + 兼容头 + 构建配置已在 x86-64 / clang-13 环境完整编译通过（0 错误），
  证明源码树与补丁自洽；
- 交叉编译的备选 `libpdfium.so`（9.6 MB）已通过 ELF / 依赖 / 符号版本审查：
  ELF64 / LoongArch / 旧世界，NEEDED 与版本要求全部落在麒麟 V10 系统库范围内；
- clang-13 工具链、gn、ninja 均为 loongarch64 旧世界 ABI，依赖版本
  （GLIBC ≤ 2.27 / GLIBCXX ≤ 3.4.21）低于麒麟 V10 系统版本，可直接运行。
