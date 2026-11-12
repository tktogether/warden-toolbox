# 模块与依赖说明

## 总览

| 模块 | 命令 | 主要动作 | 外部依赖 |
| --- | --- | --- | --- |
| `gateway` | `bash toolbox.sh gateway <动作>` | install、update、status、logs、version、backup、restore、doctor、uninstall、where、remote | warden-gateway 的 bootstrap.sh |
| `node-warden` | `bash toolbox.sh node-warden <动作>` | install、update、status、uninstall、self-test、cn-setup、cn-restore、where、remote | node-warden 的 bootstrap.sh |
| `common` | `bash toolbox.sh common <工具>` | 9 个常用工具，见下表 | 各工具自身命令（curl、dig、openssl 等） |
| `bbr` | `bash toolbox.sh bbr <动作>` | status、install、rollback、schemes、benchmark、legacy | 内核 BBR 支持、sysctl、curl |

`common` 也可用 `bash toolbox.sh tools <工具>` 调用。`where` 只打印解析到的 bootstrap.sh 路径，不执行。

## 常用工具

| 工具 | 用途 | 依赖 |
| --- | --- | --- |
| `system-info` | CPU、内存、磁盘、系统版本 | 无 |
| `net-bench` | 本机网络带宽测试 | curl 或 wget |
| `docker-mirror-speedtest` | Docker 镜像源测速 | curl、docker（可选） |
| `dns-check` | DNS 解析与响应检查 | dig 或 nslookup |
| `port-check` | 本机监听端口与远程 TCP 连通性 | ss 或 netstat |
| `github-speedtest` | GitHub 主要入口响应与下载速度 | curl |
| `cert-check` | TLS 证书有效期与链信息 | openssl |
| `disk-usage` | 磁盘和目录占用 | du、df |
| `docker-info` | Docker 版本、镜像、容器、磁盘占用 | docker |

## 项目模块的 bootstrap.sh 解析

`gateway`、`node-warden` 的动作由对应项目仓库的 `bootstrap.sh` 执行。工具箱本身不携带项目脚本，执行前按固定顺序解析：

1. 环境变量覆盖：`WARDEN_GATEWAY_BOOTSTRAP`、`NODE_WARDEN_BOOTSTRAP`。
2. 已安装路径：`/opt/warden-gateway/bootstrap.sh`、`/opt/node-warden/bootstrap.sh`。
3. 同仓检出：`$TOOLBOX_ROOT/bootstrap.sh`、其上级目录的 `bootstrap.sh`、当前目录的 `bootstrap.sh`。
4. 下载：`https://raw.githubusercontent.com/<项目仓库>/main/bootstrap.sh`，按 raw.githubusercontent.com、gh-proxy.com、ghfast.top、ghproxy.net 顺序尝试（设置 `TOOLBOX_GITHUB_PROXY` 时该前缀排在最前），单地址连接超时 10 秒、总超时 90 秒，写入临时目录后校验非空且首行为 `#!`。

解析由 `toolbox/lib/common.sh` 的 `resolve_bootstrap` 完成，成功时输出路径，失败时输出四条处理建议并返回非零。

示例：

```bash
# 使用项目源码检出
WARDEN_GATEWAY_BOOTSTRAP=/root/warden-gateway/bootstrap.sh bash toolbox.sh gateway status

# 已安装环境中直接调用
bash toolbox.sh gateway status

# 查看解析结果
bash toolbox.sh gateway where
```

## 权限

| 动作 | 是否需要 root |
| --- | --- |
| `gateway status/logs/version/self-test/where` | 否 |
| `gateway install/update/uninstall/backup/restore/doctor` | 是，执行前检查 |
| `node-warden status/self-test/where` | 否 |
| `node-warden install/update/uninstall/cn-setup/cn-restore` | 是，安装器内部检查 |
| `bbr install/rollback/legacy` | 是 |
| `bbr status/schemes/benchmark` | 否（读取系统状态） |
| `common` 工具 | 否（`disk-usage` 读取部分目录时可能受限） |

## BBR 状态文件

回滚记录默认写入 `/var/lib/warden-toolbox/bbr/bbr.previous`。拆分为独立仓库前位于 `/var/lib/warden-gateway/toolbox/bbr.previous` 和 `/var/lib/node-warden/toolbox/bbr.previous`，当前实现只读取旧路径作为回退，不做迁移；`bbr install` 发现回滚记录已存在时不会覆盖。

## 自举

`toolbox.sh` 在缺少 `toolbox/lib/common.sh` 时自动获取本仓库源码包：先尝试 `TOOLBOX_ARCHIVE_URLS`、`TOOLBOX_ARCHIVE_URL`，再使用 GitHub archive 与 codeload 直链及代理前缀，解包后重新执行。获取失败时打印已尝试的地址并退出非零。

## 测试

```bash
bash tests/test_toolbox.sh
```

覆盖模块清单、`resolve_bootstrap` 解析顺序（环境变量、已安装路径、同仓检出）、环境变量指向无效文件时的提示、项目动作转发、参数校验和行尾检查。
