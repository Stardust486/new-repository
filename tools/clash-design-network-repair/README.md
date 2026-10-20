# Clash 下设计软件网络排查与修复包

本工具包记录并复现一项已验证的修复：Windows hosts 文件里存在指向 api.mcneel.com 的错误本机映射，导致 Rhino API 直连失败。删除这些精确匹配的错误行并备份原文件后，Rhino API 的直连和 Clash 代理访问均恢复为 HTTP 200。

这不是 Adobe 修复方案。PS、AI 的 Adobe“应用访问已停用”弹窗没有被本工具解决，也没有证据证明它由本工具修复。

## 文件

- 修复-ClashHosts.ps1：检查 hosts 文件、Windows 系统代理状态，并测试 Rhino API 的直连和 Clash 代理连通性。

## 运行原理

1. 脚本读取 Windows hosts 文件，保留原文件编码和换行格式，并逐行比对四种已确认的错误映射。只接受整行精确匹配，不做模糊搜索。
2. 默认只显示匹配数量，不写入文件；同时通过 curl 分别直连和经指定的 Clash 本地代理访问 Rhino API 地址，显示 HTTP 状态，帮助判断是 hosts 映射还是网络路径问题。
3. 使用 -Apply 后，脚本先检查管理员权限，再把 hosts 原文件完整备份到同目录，然后只删去匹配行并保留其余内容。找不到匹配行时不会改写文件。完成后再显示连通性检查结果。

## 使用

1. 下载脚本并先阅读内容。
2. 在 PowerShell 运行预览（默认只读，不需管理员权限）：

   ~~~powershell
   .\修复-ClashHosts.ps1
   ~~~

3. 如果预览发现本次确认的错误行，且你决定清理，使用管理员身份打开 PowerShell，再运行：

   ~~~powershell
   .\修复-ClashHosts.ps1 -Apply
   ~~~

4. 修改前脚本会在 hosts 文件旁保存带时间戳的完整备份。没有匹配行时不会改写文件。
5. 如果 Clash 使用其他本机代理地址，可指定代理，例如：

   ~~~powershell
   .\修复-ClashHosts.ps1 -Proxy http://127.0.0.1:7897
   ~~~

## 安全范围

- 只移除本次发现的四种 api.mcneel.com 整行映射；不改动其他 hosts 记录。
- 只有显式加 -Apply 并以管理员权限运行时才写入。
- 修改前自动备份 hosts 原文件；需要回退时可将备份内容恢复。
- 不修改 Clash 配置、Adobe 授权/验证、设计软件、防火墙或现有生产文件。
- 脚本不会重启应用，也不会更改 PowerShell 执行策略。

## 本次排查记录

- Clash Verge 当时使用规则模式、Windows 系统代理 127.0.0.1:7897，TUN 关闭。
- Rhino API 修复前直连失败、代理 HTTP 200；清理 hosts 错误行后直连与代理均 HTTP 200。
- PS 和 AI 的 Adobe 应用访问停用提示未由这项 hosts 修复解决。请勿将本工具包当作 Adobe 弹窗修复程序。

适用 Windows PowerShell 5.1 及以上版本。