# Clash 下设计软件网络排查与修复包

本工具包记录并复现一项已验证的修复：Windows hosts 文件里存在指向 \`api.mcneel.com\` 的错误本机映射，导致 Rhino API 直连失败。删除这些精确匹配的错误行并备份原文件后，Rhino API 的直连和 Clash 代理访问均恢复为 HTTP 200。

这不是 Adobe 修复方案。此前 PS、AI 的 Adobe“应用访问已停用”弹窗没有被应用离线防火墙规则解决；也没有证据证明它由本工具修复。

## 文件

- \`修复-ClashHosts.ps1\`：检查 hosts 文件、Windows 系统代理状态，并测试 Rhino API 的直连和 Clash 代理连通性。

## 使用

1. 下载脚本并先阅读内容。
2. 在 PowerShell 运行预览（默认只读，不需管理员权限）：

   \`\`\`powershell
   .\修复-ClashHosts.ps1
   \`\`\`

3. 如果预览发现本次确认的错误行，且你决定清理，使用管理员身份打开 PowerShell，再运行：

   \`\`\`powershell
   .\修复-ClashHosts.ps1 -Apply
   \`\`\`

4. 修改前脚本会在 hosts 文件旁保存带时间戳的完整备份。修改后会再次显示直连和代理测试结果。没有匹配行时不会改写文件。
5. 如果 Clash 使用不同本机端口，可指定代理地址，例如：

   \`\`\`powershell
   .\修复-ClashHosts.ps1 -Proxy http://127.0.0.1:7897
   \`\`\`

## 安全范围

- 只移除本次发现的四种 \`api.mcneel.com\` 整行映射；不改动其他 hosts 记录。
- 只有显式加 \`-Apply\` 并以管理员权限运行时才写入。
- 修改前自动备份 hosts 原文件；需要回退时可将备份内容恢复。
- 不修改 Clash 配置、Adobe 授权/验证、设计软件、防火墙或现有生产文件。
- 脚本不会重启应用，也不会更改 PowerShell 执行策略。

## 本次排查记录

- Clash Verge 当时使用规则模式、Windows 系统代理 \`127.0.0.1:7897\`，TUN 关闭。
- Rhino API 修复前直连失败、代理 HTTP 200；清理 hosts 错误行后直连与代理均 HTTP 200。
- PS 和 AI 的 Adobe 应用访问停用提示仍需按 Adobe 官方方式处理；请勿将本工具包当作它们的修复程序。

适用 Windows PowerShell 5.1 及以上版本。