# xboard-node UUID 更新修复补丁

本仓库用于修复 `xboard-node` v1.13 的用户同步问题。该问题通常发生在
Xboard 用户重置订阅凭据之后。

当用户的数据库 ID 不变、但 UUID 已更新时，旧版逻辑不会把旧 UUID
加入待删除列表。Xray 因此可能继续保留旧身份，同时把新身份判定为重复。
这一问题在 VLESS Encryption 节点上尤其明显：旧订阅仍可使用，新订阅却无法连接。

## 一键使用

适用于 Linux amd64、使用标准 systemd 服务的安装环境：

```bash
curl -fsSL https://raw.githubusercontent.com/Tweakl/xboard-node-userdiff-fix/main/install.sh | sudo bash
```

运行后请选择：

- 输入 `1`：安装修复补丁；
- 输入 `2`：卸载修复补丁，并恢复最近一次安装前的备份。

安装脚本会：

- 检查系统架构和现有安装；
- 使用 SHA-256 校验发布的二进制文件；
- 为当前二进制文件创建带时间戳的备份；
- 重启 `xboard-node.service` 并检查运行状态；
- 安装或卸载后检查服务状态，失败时自动回滚。

脚本不会读取、修改或上传 Xboard 配置、节点凭据、用户数据、IP 地址或域名。

## 查看补丁

完整源码改动和回归测试位于
[`fix-userdiff.patch`](fix-userdiff.patch)，适用于上游版本
[`v1.13`](https://github.com/cedar2025/xboard-node/releases/tag/v1.13)。

## 手动回滚

安装成功后，脚本会显示备份文件路径。恢复命令如下：

```bash
sudo systemctl stop xboard-node
sudo install -m 755 /usr/local/bin/xboard-node.before-userdiff-YYYYMMDD-HHMMSS /usr/local/bin/xboard-node
sudo systemctl start xboard-node
```

## 适用范围

这是独立构建的兼容性补丁，并非上游官方版本。补丁仅修改 UUID 更新时的
用户替换逻辑，不涉及节点配置或其他功能。
