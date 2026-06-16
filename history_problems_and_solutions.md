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

**原因：** 用户 PATH 环境变量中包含 `C:\msys64\ucrt64\bin\` 和 `C:\msys64\mingw64\bin\`，其中有 **MinGW 编译的 Qt DLL**。虽然 Windows DLL 搜索顺序中 exe 同目录优先于 PATH，但由于 CMake 的 POST_BUILD 步骤只复制了 `ZcAiLib.dll`，build 目录中缺少其他 Qt 运行时 DLL，导致系统从 PATH 中加载了 msys64 的 MinGW Qt DLL。MinGW 和 MSVC 编译的 Qt 完全不兼容。

**解决：** 从用户 PATH 中移除 msys64 路径（开始菜单搜索"编辑系统环境变量" → 用户变量 → PATH → 删除 `C:\msys64\ucrt64\bin` 和 `C:\msys64\mingw64\bin`）。需要 MinGW 编译时，打开 MSYS2 UCRT64 终端，它会自动设置正确的 PATH。

---

## 问题六：清理重建后 build/ 目录残留错误的 DLL

**现象：** 清理重建后启动报 `appendBreadcrumb@ElaBreadcrumbBar` 入口点找不到。

**原因：** `build/` 目录中的 DLL 是之前手动复制的版本，CMake 的 POST_BUILD 步骤**只复制 `ZcAiLib.dll`**，不会覆盖 `elawidgettools.dll`、`ZcWidgetTools.dll`、`ZcJsonLib.dll`。如果之前 build/ 中残留了新编译的 DLL，清理重建后它们不会被替换回原始版本。

**解决：** 清理重建后，手动将 `3rdparty/` 中的原始 DLL 复制到 `build/`：
```bash
copy 3rdparty\ElaWidgetTools\bin\elawidgettools.dll build\
copy 3rdparty\ZcWidgetTools\bin\ZcWidgetTools.dll build\
copy 3rdparty\ZcJsonLib\bin\ZcJsonLib.dll build\
```

---

## 问题七：清理重建后 ZcAiLib.dll 被覆盖回旧版本

**现象：** 执行 `rmdir /s /q CMakeFiles` 清理后重新构建，启动时再次报入口点错误。

**原因：** CMake 的 POST_BUILD 步骤会将 `3rdparty/ZcAILib/bin/ZcAiLib.dll` 复制到 `build/`。原始版本的 DLL 是用不同 Qt 版本编译的，清理重建时会被覆盖回去。

**解决：** 每次清理重建后，需要用 Qt 6.8.0 重新编译 ZcAiLib 并替换 `3rdparty/ZcAILib/bin/ZcAiLib.dll` 和 `build/ZcAiLib.dll`。保留 `3rdparty/ZcAILib_src/` 源码目录以方便重新编译。

```bash
# 重新编译 ZcAiLib
cmd /c "vcvarsall.bat x64 && set INCLUDE= && cd 3rdparty/ZcAILib_src && cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=C:/Qt/6.8.0/msvc2022_64 -DCMAKE_DISABLE_FIND_PACKAGE_Vulkan=TRUE && cmake --build build --target ZcAiLib"

# 复制到目标位置
copy 3rdparty\ZcAILib_src\build\ZcAiLib.dll 3rdparty\ZcAILib\bin\
copy 3rdparty\ZcAILib_src\build\ZcAiLib.dll build\
```

---

## 完整重建流程（一键脚本）

清理重建后，按顺序执行以下命令即可恢复：

```bash
# 1. 进入 VS 开发环境
"C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64

# 2. 重新编译 ZcAiLib（需要清空 INCLUDE 避免 msys64 冲突）
set INCLUDE=
cd 3rdparty\ZcAILib_src
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=C:/Qt/6.8.0/msvc2022_64 -DCMAKE_DISABLE_FIND_PACKAGE_Vulkan=TRUE
cmake --build build --target ZcAiLib

# 3. 复制 ZcAiLib
copy build\ZcAiLib.dll ..\ZcAILib\bin\
copy build\ZcAiLib.dll ..\..\build\

# 4. 复制其他第三方 DLL 到 build 目录
cd ..\..
copy 3rdparty\ElaWidgetTools\bin\elawidgettools.dll build\
copy 3rdparty\ZcWidgetTools\bin\ZcWidgetTools.dll build\
copy 3rdparty\ZcJsonLib\bin\ZcJsonLib.dll build\

# 5. 构建 ZcChat2 主程序
cd build
cmake .. -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_DISABLE_FIND_PACKAGE_Vulkan=TRUE
ninja
```
