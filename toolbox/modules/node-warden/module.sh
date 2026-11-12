#!/usr/bin/env bash
# Node Warden 功能目录：调用 node-warden 仓库的 bootstrap.sh。
# bootstrap.sh 不在本仓库内，按环境变量、已安装路径、同仓检出、GitHub 下载的顺序解析。

if [[ -z "${TOOLBOX_ROOT:-}" ]]; then
  TOOLBOX_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd -P)
  export TOOLBOX_ROOT
fi
# shellcheck source=/dev/null
source "$TOOLBOX_ROOT/toolbox/lib/common.sh"

MODULE_ID="node-warden"
MODULE_TITLE="Node Warden"
MODULE_DESCRIPTION="安装、更新、卸载和检查 Node Warden 面板、GitHub 代理与 Docker 代理。"
NODE_WARDEN_REPO="tktogether/node-warden"
NODE_WARDEN_BOOTSTRAP_ENV="NODE_WARDEN_BOOTSTRAP"
NODE_WARDEN_BOOTSTRAP_PATH="/opt/node-warden/bootstrap.sh"

node_warden_bootstrap() {
  resolve_bootstrap "$NODE_WARDEN_REPO" "$NODE_WARDEN_BOOTSTRAP_ENV" "$NODE_WARDEN_BOOTSTRAP_PATH"
}

node_warden_exec() {
  local action=$1
  shift
  local bootstrap
  bootstrap=$(node_warden_bootstrap) || return 1
  exec bash "$bootstrap" "$action" "$@"
}

module_list() {
  printf 'Node Warden 操作：\n'
  printf '  %-14s %s\n' "install" "从零安装或重新配置"
  printf '  %-14s %s\n' "update" "更新已安装的 Node Warden"
  printf '  %-14s %s\n' "status" "显示组件和端口状态"
  printf '  %-14s %s\n' "uninstall" "卸载组件"
  printf '  %-14s %s\n' "self-test" "运行安装器自检"
  printf '  %-14s %s\n' "cn-setup" "国内网络设置"
  printf '  %-14s %s\n' "cn-restore" "恢复国内网络设置"
  printf '  %-14s %s\n' "where" "显示解析到的 bootstrap.sh 路径"
  printf '  %-14s %s\n' "remote" "显示远程运行命令"
  printf '\nbootstrap.sh 查找顺序：环境变量 %s、已安装路径 %s、同仓检出、GitHub 下载（raw.githubusercontent.com、gh-proxy.com、ghfast.top、ghproxy.net）。\n' \
    "$NODE_WARDEN_BOOTSTRAP_ENV" "$NODE_WARDEN_BOOTSTRAP_PATH"
}

module_run() {
  local action="${1:-}"
  if [[ $# -gt 0 ]]; then
    shift
  fi
  case "$action" in
    ""|list)
      module_list
      ;;
    install|update|uninstall|cn-setup|cn-restore)
      require_root
      node_warden_exec "$action" "$@"
      ;;
    status|self-test|logs|version)
      node_warden_exec "$action" "$@"
      ;;
    where)
      local resolved
      resolved=$(node_warden_bootstrap) || return 1
      printf '%s\n' "$resolved"
      ;;
    remote)
      local url
      printf '远程运行命令（按可用性选择）：\n'
      while IFS= read -r url; do
        printf '  curl -fsSL %s -o /tmp/warden-toolbox.sh && sudo bash /tmp/warden-toolbox.sh node-warden install\n' "$url"
      done < <(github_url_candidates 'https://raw.githubusercontent.com/tktogether/warden-toolbox/main/toolbox.sh')
      printf '\n其它操作把命令末尾的 node-warden install 换成 node-warden status 等。\n'
      ;;
    help|--help|-h)
      module_list
      printf '\n示例：\n'
      printf '  sudo bash toolbox.sh node-warden install\n'
      printf '  sudo bash toolbox.sh node-warden update\n'
      printf '  sudo bash toolbox.sh node-warden status\n'
      ;;
    *)
      die "未知操作：$action"
      ;;
  esac
}

module_menu() {
  local choice
  while true; do
    printf '\nNode Warden\n'
    printf '  1) install      从零安装或重新配置\n'
    printf '  2) update       更新已安装的 Node Warden\n'
    printf '  3) status       显示组件和端口状态\n'
    printf '  4) self-test    运行安装器自检\n'
    printf '  5) uninstall    卸载组件\n'
    printf '  6) cn-setup     国内网络设置\n'
    printf '  7) cn-restore   恢复国内网络设置\n'
    printf '  8) remote       远程运行命令\n'
    printf '  0) 返回\n'
    read -r -p '选择: ' choice || return 0
    case "$choice" in
      0|q) return 0 ;;
      1) module_run install ;;
      2) module_run update ;;
      3) module_run status ;;
      4) module_run self-test ;;
      5) module_run uninstall ;;
      6) module_run cn-setup ;;
      7) module_run cn-restore ;;
      8) module_run remote ;;
      *) warn "无效选择。" ;;
    esac
  done
}
