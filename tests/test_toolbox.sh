#!/usr/bin/env bash
# Warden Toolbox 测试：模块清单、bootstrap 解析顺序、项目动作转发、参数校验和行尾。

set -uo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
TOOLBOX="$ROOT_DIR/toolbox.sh"
COMMON="$ROOT_DIR/toolbox/lib/common.sh"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); printf 'ok %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf 'not ok %s：%s\n' "$1" "$2"; }

check_rc() {
  local name=$1 expected=$2 actual=$3
  if [[ "$actual" -eq "$expected" ]]; then ok "$name"; else bad "$name" "退出码 $actual，期望 $expected"; fi
}

check_contains() {
  local name=$1 text=$2 needle=$3
  if [[ "$text" == *"$needle"* ]]; then ok "$name"; else bad "$name" "缺少：$needle"; fi
}

check_not_contains() {
  local name=$1 text=$2 needle=$3
  if [[ "$text" != *"$needle"* ]]; then ok "$name"; else bad "$name" "不应出现：$needle"; fi
}

check_empty() {
  local name=$1 text=$2
  if [[ -z "$text" ]]; then ok "$name"; else bad "$name" "内容非空：$text"; fi
}

# ---- 版本与入口 ----
out=$(bash "$TOOLBOX" version 2>&1)
rc=$?
check_rc "version 退出码" 0 "$rc"
check_contains "version 输出" "$out" "Warden Toolbox $(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"

out=$(bash "$TOOLBOX" list 2>&1)
check_contains "list 包含 gateway" "$out" "gateway"
check_contains "list 包含 node-warden" "$out" "node-warden"
check_contains "list 包含 common" "$out" "common"
check_contains "list 包含 bbr" "$out" "bbr"

out=$(bash "$TOOLBOX" self-test 2>&1)
rc=$?
check_rc "self-test 退出码" 0 "$rc"
check_contains "self-test 通过提示" "$out" "语法、版本和模块清单检查通过"

out=$(bash "$TOOLBOX" help 2>&1)
check_contains "help 含远程运行" "$out" "远程运行"
check_contains "help 含本仓库地址" "$out" "tktogether/warden-toolbox"
check_contains "help 使用 curl 落盘写法" "$out" "curl -fsSL"
check_contains "help 明示不使用进程替换" "$out" "不使用 bash <(curl"

out=$(bash "$TOOLBOX" remote 2>&1)
check_contains "remote 含 toolbox.sh" "$out" "toolbox.sh"
check_contains "remote 含代理前缀" "$out" "gh-proxy.com"
check_contains "remote 含内核仓库" "$out" "warden-toolbox"

out=$(bash "$TOOLBOX" no-such-command 2>&1)
rc=$?
check_rc "未知命令退出码" 1 "$rc"
check_contains "未知命令提示" "$out" "未知命令"

out=$(bash "$TOOLBOX" bbr no-such-action 2>&1)
rc=$?
check_rc "未知操作退出码" 1 "$rc"
check_contains "未知操作提示" "$out" "未知操作"

# ---- 模块清单 ----
out=$(bash "$TOOLBOX" gateway list 2>&1)
check_contains "gateway list 含 install" "$out" "install"
check_contains "gateway list 含 status" "$out" "status"
check_contains "gateway list 含 doctor" "$out" "doctor"
check_contains "gateway list 含 where" "$out" "where"

out=$(bash "$TOOLBOX" node-warden list 2>&1)
check_contains "node-warden list 含 cn-setup" "$out" "cn-setup"
check_contains "node-warden list 含 cn-restore" "$out" "cn-restore"
check_contains "node-warden list 含 self-test" "$out" "self-test"

out=$(bash "$TOOLBOX" common list 2>&1)
for tool in system-info net-bench docker-mirror-speedtest dns-check port-check github-speedtest cert-check disk-usage docker-info; do
  check_contains "common list 含 $tool" "$out" "$tool"
done

out=$(bash "$TOOLBOX" bbr list 2>&1)
for action in status install rollback schemes benchmark legacy; do
  check_contains "bbr list 含 $action" "$out" "$action"
done

# ---- 参数校验 ----
out=$(bash "$TOOLBOX" common port-check 99999 2>&1)
rc=$?
check_rc "端口越界退出码" 1 "$rc"
check_contains "端口越界提示" "$out" "端口无效"

out=$(bash "$TOOLBOX" common port-check "bad host" 443 2>&1)
rc=$?
check_rc "主机非法退出码" 1 "$rc"
check_contains "主机非法提示" "$out" "主机无效"

out=$(bash "$TOOLBOX" common port-check 1 2 3 2>&1)
rc=$?
check_rc "参数过多退出码" 1 "$rc"

# ---- bootstrap 解析顺序 ----
printf '#!/usr/bin/env bash\nprintf "FAKE_GATEWAY %%s\\n" "${1:-}"\n' > "$TMP_DIR/fake-gateway.sh"
printf '#!/usr/bin/env bash\nprintf "FAKE_NODE %%s\\n" "${1:-}"\n' > "$TMP_DIR/fake-node.sh"
mkdir -p "$TMP_DIR/same-repo"
printf '#!/usr/bin/env bash\n' > "$TMP_DIR/same-repo/bootstrap.sh"

resolve_probe() {
  local env_name=$1 env_value=$2 installed=$3 root=$4
  (
    cd "$TMP_DIR" || exit 1
    if [[ -n "$root" ]]; then export TOOLBOX_ROOT="$root"; else unset TOOLBOX_ROOT; fi
    if [[ -n "$env_value" ]]; then export "$env_name=$env_value"; fi
    # shellcheck source=/dev/null
    source "$COMMON"
    resolve_bootstrap "example/example" "$env_name" "$installed"
  ) 2>/dev/null
}

out=$(resolve_probe DEMO_ENV "$TMP_DIR/fake-gateway.sh" "$TMP_DIR/same-repo/bootstrap.sh" "$TMP_DIR/same-repo")
check_contains "解析优先环境变量" "$out" "fake-gateway.sh"

out=$(resolve_probe DEMO_ENV "" "$TMP_DIR/same-repo/bootstrap.sh" "$TMP_DIR/same-repo")
check_contains "解析优先已安装路径" "$out" "$TMP_DIR/same-repo/bootstrap.sh"

out=$(resolve_probe DEMO_ENV "" "$TMP_DIR/missing.sh" "$TMP_DIR/same-repo")
check_contains "解析回退同仓检出" "$out" "same-repo/bootstrap.sh"

out=$( ( cd "$TMP_DIR" || exit 1; source "$COMMON"; bootstrap_hint example/example DEMO_ENV /opt/example/bootstrap.sh ) 2>&1 )
check_contains "提示含环境变量" "$out" "DEMO_ENV=/path/to/bootstrap.sh"
check_contains "提示含已安装路径" "$out" "/opt/example/bootstrap.sh"
check_contains "提示含源码目录" "$out" "bootstrap.sh <操作>"

mapfile -t cands < <( ( source "$COMMON"; bootstrap_url_candidates example/example ) 2>/dev/null )
check_contains "下载首选直连地址" "${cands[0]:-}" "https://raw.githubusercontent.com/example/example/main/bootstrap.sh"
check_contains "下载次选 gh-proxy" "${cands[1]:-}" "https://gh-proxy.com/https://raw.githubusercontent.com/example/example/main/bootstrap.sh"
check_contains "下载三选 ghfast" "${cands[2]:-}" "ghfast.top/"
check_contains "下载四选 ghproxy" "${cands[3]:-}" "ghproxy.net/"

mapfile -t cands < <( ( export TOOLBOX_GITHUB_PROXY="https://proxy.example"; source "$COMMON"; bootstrap_url_candidates example/example ) 2>/dev/null )
check_contains "自定义代理排在最前" "${cands[1]:-}" "https://proxy.example/https://raw.githubusercontent.com/example/example/main/bootstrap.sh"
if ( source "$COMMON"; declare -f bootstrap_fetch >/dev/null ); then ok "提供短超时下载函数"; else bad "提供短超时下载函数" "bootstrap_fetch 未定义"; fi

# ---- 项目动作转发 ----
out=$(WARDEN_GATEWAY_BOOTSTRAP="$TMP_DIR/fake-gateway.sh" bash "$TOOLBOX" gateway status 2>&1)
rc=$?
check_rc "gateway status 退出码" 0 "$rc"
check_contains "gateway 转发 status" "$out" "FAKE_GATEWAY status"

out=$(NODE_WARDEN_BOOTSTRAP="$TMP_DIR/fake-node.sh" bash "$TOOLBOX" node-warden self-test 2>&1)
rc=$?
check_rc "node-warden self-test 退出码" 0 "$rc"
check_contains "node-warden 转发 self-test" "$out" "FAKE_NODE self-test"

out=$(WARDEN_GATEWAY_BOOTSTRAP="$TMP_DIR/fake-gateway.sh" bash "$TOOLBOX" gateway where 2>&1)
check_contains "gateway where 输出路径" "$out" "fake-gateway.sh"

out=$(WARDEN_GATEWAY_BOOTSTRAP="$TMP_DIR/missing.sh" bash "$TOOLBOX" gateway status 2>&1)
rc=$?
check_rc "无效环境变量退出码" 1 "$rc"
check_contains "无效环境变量提示" "$out" "WARDEN_GATEWAY_BOOTSTRAP"
check_contains "无效环境变量给出建议" "$out" "未能获得"

if [[ "$(id -u)" -ne 0 ]]; then
  out=$(bash "$TOOLBOX" gateway install 2>&1)
  rc=$?
  check_rc "非 root 安装退出码" 1 "$rc"
  check_contains "非 root 安装提示" "$out" "需要 root 权限"
fi

# ---- 项目仓库接入脚本 ----
SHIM="$ROOT_DIR/integrations/toolbox-shim.sh"
if [[ -f "$SHIM" ]]; then ok "提供项目仓库接入脚本"; else bad "提供项目仓库接入脚本" "文件不存在"; fi
shim_content=$(cat "$SHIM" 2>/dev/null || true)
check_contains "接入脚本指向独立仓库" "$shim_content" "tktogether/warden-toolbox"
check_contains "接入脚本支持地址覆盖" "$shim_content" "WARDEN_TOOLBOX_URL"
out=$(WARDEN_TOOLBOX_LOCAL="$TMP_DIR/fake-gateway.sh" bash "$SHIM" version 2>&1)
rc=$?
check_rc "接入脚本转发退出码" 0 "$rc"
check_contains "接入脚本转发参数" "$out" "FAKE_GATEWAY version"

# ---- 自动获取源码后的临时目录清理 ----
BOOT="$TMP_DIR/bootstrap-clean"
mkdir -p "$BOOT/run" "$BOOT/tmpdir" "$BOOT/bin" "$BOOT/pkg"
tar czf "$BOOT/pkg/src.tgz" -C "$ROOT_DIR" --exclude=.git .
cp "$TOOLBOX" "$BOOT/run/toolbox.sh"
cat > "$BOOT/bin/curl" <<'STUB'
#!/usr/bin/env bash
# 测试桩：把 local:// 地址映射到本地文件，其余地址一律失败。
dest=""; url=""
while (($#)); do
  case "$1" in
    -o) dest=$2; shift 2 ;;
    -*) shift ;;
    *) url=$1; shift ;;
  esac
done
[[ "$url" == local://* ]] || exit 22
cp "${url#local://}" "$dest"
STUB
chmod +x "$BOOT/bin/curl"

out=$(PATH="$BOOT/bin:$PATH" TMPDIR="$BOOT/tmpdir" TOOLBOX_ARCHIVE_URL="local://$BOOT/pkg/src.tgz" bash "$BOOT/run/toolbox.sh" version 2>&1)
rc=$?
check_rc "自动获取源码后正常执行" 0 "$rc"
check_contains "自动获取源码后输出正常" "$out" "Warden Toolbox"
check_empty "自动获取源码后清理临时目录" "$(ls -A "$BOOT/tmpdir" 2>/dev/null)"

out=$(PATH="$BOOT/bin:$PATH" TMPDIR="$BOOT/tmpdir" TOOLBOX_ARCHIVE_URL="local://$BOOT/pkg/src.tgz" bash "$BOOT/run/toolbox.sh" no-such-command 2>&1)
rc=$?
check_rc "自动获取源码后透传退出码" 1 "$rc"
check_empty "失败时也清理临时目录" "$(ls -A "$BOOT/tmpdir" 2>/dev/null)"

# ---- 行尾与编码 ----
cr_files=""
while IFS= read -r -d '' f; do
  if ! tr -d '\r' < "$f" | cmp -s - "$f"; then
    cr_files+="${f}"$'\n'
  fi
done < <(find "$ROOT_DIR" -type f \( -name '*.sh' -o -name '*.md' \) -not -path '*/.git/*' -print0)
check_empty "脚本与文档为 LF 行尾" "$cr_files"

if (( FAIL > 0 )); then
  printf '\n通过 %d 项，失败 %d 项。\n' "$PASS" "$FAIL"
  exit 1
fi
printf '\n通过 %d 项，失败 0 项。\n' "$PASS"
