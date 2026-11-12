# Warden Toolbox

Warden 系列的独立脚本工具箱：统一入口管理 Warden Gateway、Node Warden、常用系统与网络工具、BBR 配置。本仓库只包含 Bash 脚本，不包含上述项目的业务代码，也不随项目仓库一起发布。

## 远程运行

```bash
curl -fsSL https://raw.githubusercontent.com/tktogether/warden-toolbox/main/toolbox.sh -o /tmp/warden-toolbox.sh
sudo bash /tmp/warden-toolbox.sh
```

国内网络或代理受限时先执行 `bash /tmp/warden-toolbox.sh remote`，按可用地址替换命令中的 URL（gh-proxy.com、ghfast.top、ghproxy.net 前缀）。不使用 `bash <(curl ...)` 形式。

## 功能

- 项目维护：`gateway`、`node-warden` 两个功能目录分别调用对应项目的安装维护脚本（安装、升级、状态、日志、备份恢复、诊断、卸载、国内网络设置）。
- 常用工具：系统信息、网络带宽测试、Docker 镜像源测速、DNS 检查、端口检查、GitHub 访问测速、证书检查、磁盘占用、Docker 信息。
- BBR：状态、启用、回滚、方案兼容性检查、带宽测试、下载官方脚本检查（不执行）。

## 本地运行

```bash
git clone https://github.com/tktogether/warden-toolbox.git
cd warden-toolbox
bash toolbox.sh list
sudo bash toolbox.sh gateway status
```

不带参数在终端中运行会进入交互菜单；非终端环境不带参数时打印用法并返回非零。

## 模块与依赖

| 模块 | 说明 | 是否依赖其他项目 |
| --- | --- | --- |
| `gateway` | Warden Gateway 安装、升级、状态、日志、备份恢复、诊断、卸载 | 需要 warden-gateway 的 bootstrap.sh |
| `node-warden` | Node Warden 安装、更新、状态、卸载、自检、国内网络设置 | 需要 node-warden 的 bootstrap.sh |
| `common` | 9 个常用系统与网络工具 | 不依赖 |
| `bbr` | BBR 状态、启用、回滚、方案检查、带宽测试 | 不依赖（`legacy` 仅下载官方脚本检查） |

详细说明见 [docs/MODULES.md](docs/MODULES.md)。

## 项目脚本查找顺序

`gateway`、`node-warden` 模块不携带项目脚本，执行前按以下顺序解析对应项目的 `bootstrap.sh`：

1. 环境变量：`WARDEN_GATEWAY_BOOTSTRAP`、`NODE_WARDEN_BOOTSTRAP`。
2. 已安装路径：`/opt/warden-gateway/bootstrap.sh`、`/opt/node-warden/bootstrap.sh`。
3. 同仓检出：工具箱目录、其上级目录、当前目录存在 `bootstrap.sh`。
4. 下载：从对应 GitHub 仓库按 raw.githubusercontent.com、gh-proxy.com、ghfast.top、ghproxy.net 顺序获取到临时目录，校验文件非空且首行为 `#!` 后执行。

全部失败时输出可操作提示，例如设置环境变量、先安装项目或在项目源码目录直接运行 `bootstrap.sh`。只读操作（`status`、`logs`、`version`、`self-test`）不需要 root 权限。

## 接入已独立项目仓库

项目仓库把 `toolbox.sh` 独立到本仓库后，可在其根目录放置转发脚本 `integrations/toolbox-shim.sh`：

```bash
cp integrations/toolbox-shim.sh /path/to/project/toolbox.sh
```

转发脚本下载本仓库的 `toolbox.sh` 并透传全部参数与退出码，旧用法 `bash toolbox.sh <操作>` 保持可用。调试时可用 `WARDEN_TOOLBOX_LOCAL` 指向本地脚本，或用 `WARDEN_TOOLBOX_URL` 指定下载地址；下载顺序为直连、gh-proxy.com、ghfast.top、ghproxy.net。

## 常用命令

```bash
bash toolbox.sh version                 # 版本
bash toolbox.sh list                    # 模块清单
bash toolbox.sh self-test               # 语法、版本、模块清单自检
bash toolbox.sh remote                  # 远程运行地址
bash toolbox.sh gateway status          # 网关状态
bash toolbox.sh node-warden status      # Node Warden 状态
bash toolbox.sh common system-info      # 常用工具
bash toolbox.sh bbr status              # BBR 状态
bash tests/test_toolbox.sh              # 本仓库测试
```

## 环境变量

| 变量 | 作用 |
| --- | --- |
| `WARDEN_GATEWAY_BOOTSTRAP` | 指定 warden-gateway 的 bootstrap.sh 路径 |
| `NODE_WARDEN_BOOTSTRAP` | 指定 node-warden 的 bootstrap.sh 路径 |
| `TOOLBOX_REPO` | 自举使用的仓库，默认 `tktogether/warden-toolbox` |
| `TOOLBOX_BRANCH` | 自举使用的分支，默认 `main` |
| `TOOLBOX_ARCHIVE_URLS` | 自举源码包地址列表，空格分隔 |
| `TOOLBOX_GITHUB_PROXY` | 自举和 bootstrap.sh 下载时优先使用的 GitHub 代理前缀 |
| `BBR_STATE_DIR` | BBR 回滚记录目录，默认 `/var/lib/warden-toolbox/bbr` |

## 安全约束

- 不执行远程脚本，不使用 `eval`；所有下载均先落盘校验再运行。
- 主机名、端口、时长等输入在执行前校验。
- 需要 root 的操作在执行前检查权限并给出提示。
- 修改系统配置前先备份，`bbr` 启用前写入回滚记录。

## 目录结构

```
toolbox.sh                    总入口
toolbox/lib/common.sh         公共函数库（日志、校验、下载、bootstrap 解析）
toolbox/modules/common/       常用工具
toolbox/modules/bbr/          BBR 模块
toolbox/modules/gateway/      Warden Gateway 模块
toolbox/modules/node-warden/  Node Warden 模块
integrations/toolbox-shim.sh  项目仓库接入用转发脚本
docs/MODULES.md               模块与依赖说明
tests/test_toolbox.sh         本仓库测试
VERSION                       版本号
```

## 许可

MIT，见 [LICENSE](LICENSE)。
