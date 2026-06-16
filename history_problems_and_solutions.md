# ZcChat2 构建问题与解决方案

## 问题一：界面文字不可见（白底白字）

**现象：** 对话框显示白色，输入框打字也看不见文字。

**原因：** `Dialog::paintEvent` 将背景硬编码为白色 (`Qt::white`)，但 `QTextEdit` 和 `QLabel` 没有设置文字颜色。Windows 深色主题下，文字颜色跟随系统调色板变为白色，导致白底白字。

**修复：** 在 `windows/dialog/dialog.ui` 中为 `textEdit` 添加 `color: #000000;`，为 `label_name` 添加 `color: #000000;` 样式。

---

## 问题二：DLL 找不到 / 入口点不匹配

**现象：** 启动时报错找不到 `ElaWidgetTools.dll`、`ZcWidgetTools.dll`、`ZcJsonLib.dll`，以及 `ZcAiLib.dll` 入口点错误 `??1QNetworkRequest@@QEAA@XZ`。

**原因：** `build/` 目录中缺少第三方 DLL。`CMakeLists.txt` 的 POST_BUILD 步骤仅复制了 `ZcAiLib.dll`，其余 DLL 未被复制。此外，预编译的 `ZcAiLib.dll` 是用不同 Qt 版本编译的，与 Qt 6.8.0 不兼容。

**解决：** 从源码重新编译 `ZcAiLib`（匹配 Qt 6.8.0），并将所有第三方 DLL 复制到 `build/` 目录。

---

## 问题三：MSVC 编译头文件冲突

**现象：** 编译第三方库时，`C:\msys64\ucrt64\include` 被自动加入编译器搜索路径（通过 Vulkan Headers 发现），与 MSVC 标准库头文件冲突，导致 `type_traits` 等头文件找不到。

**原因：** CMake 的 `FindWrapVulkanHeaders` 发现了 msys64 的 include 目录并加入搜索路径。msys64 的头文件（MinGW/GCC 风格）与 MSVC 编译器不兼容。

**解决：** 编译时设置 `-DCMAKE_DISABLE_FIND_PACKAGE_Vulkan=TRUE`，并在编译命令中清空 `INCLUDE` 环境变量 (`set INCLUDE=`)。

---

## 问题四：ElaWidgetTools 版本不兼容

**现象：** 用 GitHub 上游 ElaWidgetTools 源码编译后，链接 ZcChat2 时报错找不到 `appendBreadcrumb`、`setLeftButtonText` 等符号。

**原因：** ZcChat2 使用的是定制版 ElaWidgetTools，头文件中的函数签名不同（如 `QString` 按值传递 vs 上游的 `const QString&` 按引用传递），导致 MSVC 名称修饰（name mangling）不同，符号无法匹配。

**解决：** 不替换 ElaWidgetTools，保留原始预编译的 DLL 和 lib。

---

## 问题五（根本原因）：PATH 中的 MinGW Qt 覆盖了 MSVC Qt

**现象：** 即使所有 DLL 都在 build 目录中，启动时仍报入口点错误，如 `?setIndent@QLabel@@QEAAXH@Z` 找不到。

**原因：** 系统 PATH 环境变量中包含 `C:\msys64\ucrt64\bin\` 和 `C:\msys64\mingw64\bin\`，其中有 **MinGW 编译的 Qt DLL**。Windows DLL 搜索顺序中，PATH 中的目录优先于 exe 所在目录，导致加载了错误的 Qt 运行时。MinGW 和 MSVC 编译的 Qt 完全不兼容。

**解决：** 将正确的 Qt 6.8.0 MSVC DLL 和插件复制到 `build/` 目录：
- `Qt6Core.dll`、`Qt6Gui.dll`、`Qt6Widgets.dll`、`Qt6Network.dll`、`Qt6Multimedia.dll`、`Qt6Svg.dll`
- `platforms/qwindows.dll`
- `multimedia/*.dll`
- `tls/*.dll`

exe 同目录的 DLL 优先于 PATH 搜索，确保加载正确版本。

---

## 构建命令参考

```bash
# 在 VS Developer Command Prompt 中执行
"C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64

# 编译第三方库（需要清空 INCLUDE 避免 msys64 冲突）
set INCLUDE=
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=C:/Qt/6.8.0/msvc2022_64 -DCMAKE_DISABLE_FIND_PACKAGE_Vulkan=TRUE
cmake --build build --target <target_name>

# 编译 ZcChat2 主程序
cd build
rmdir /s /q CMakeFiles
cmake .. -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_DISABLE_FIND_PACKAGE_Vulkan=TRUE
ninja
```
