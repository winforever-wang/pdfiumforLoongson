
     PDFium 银河麒麟 V10动态库

在银河麒麟桌面操作系统 V10 SP1（loongarch64）
**原生编译** PDFium，产出 `libpdfium.so` 动态库。

- 源码版本：pdfium（GitHub 镜像 2025-11-19，DEPS build_revision 371ecb08，glibc 2.28）
- 目标系统：银河麒麟桌面 V10 SP1（Build 20250417，内核 5.4.18-168-generic）
- 目标架构：loongarch64（3A5000 / 3A6000，旧世界 ABI）
- 产物：`libpdfium.so`（不含 V8 / XFA）。

## 头文件说明
pdfium API 头文件在public\ 目录下
| 头文件 | 用途 |
| ---------- | ------------------------ |
| fpdfview.h | 核心入口：FPDF_LoadDocument, FPDF_GetPageCount, FPDF_CloseDocument 等 |
| fpdf_annot.h | 注释 |
| fpdf_attachment.h | 附件 |
| fpdf_catalog.h | 目录 |
| fpdf_dataavail.h | 数据可用性/渐进加载 |
| fpdf_doc.h | 文档操作 |
| fpdf_edit.h | 页面编辑（创建/修改对象） |
| fpdf_ext.h | 扩展模块 |
| fpdf_flatten.h | 扁平化 |
| fpdf_formfill.h | 表单填充 |
| fpdf_ppo.h | 页面操作（插入/删除/旋转） |
| fpdf_progressive.h | 渐进渲染 |
| fpdf_save.h | 保存 |
| fpdf_searchex.h | 搜索扩展 |
| fpdf_signature.h | 签名 |
| fpdf_structtree.h | 结构树 |
| fpdf_sysfontinfo.h | 系统字体信息 |
| fpdf_text.h | 文本提取/搜索 |
| fpdf_thumbnail.h | 缩略图 |
| fpdf_transformpage.h | 页面变换 |
| cpp/fpdf_scopers.h | C++ RAII 包装 |
| cpp/fpdf_deleters.h | C++ 删除器 |

## 验证记录

- 银河麒麟桌面操作系统 V10 SP1（loongarch64 3A6000， 16G Mem， 512G Disk, 独显）；
- 在展示PDF文档测试通过：打开PDF展示正确，获取页数、翻页，查询。
