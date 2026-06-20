#!/usr/bin/env bash
set -Eeuo pipefail

REPO="Tweakl/xboard-node-userdiff-fix"
RELEASE="v1.13-userdiff-fix-1"
ASSET="xboard-node-linux-amd64"
EXPECTED_SHA256="7bf4c248c70dc303919e88d7a4050dd093d2efd2a8b7f8ba44404051275874e0"
SERVICE="xboard-node.service"
TARGET="/usr/local/bin/xboard-node"
TEMP_DIR=""

log() {
    printf '[xboard-node-fix] %s\n' "$*"
}

fail() {
    printf '[xboard-node-fix] 错误：%s\n' "$*" >&2
    exit 1
}

cleanup() {
    [[ -z "$TEMP_DIR" ]] || rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

check_common_requirements() {
    [[ ${EUID:-$(id -u)} -eq 0 ]] || fail "请使用 root 权限运行此脚本"

    case "$(uname -m)" in
        x86_64|amd64) ;;
        *) fail "当前版本仅支持 Linux amd64" ;;
    esac

    command -v systemctl >/dev/null || fail "缺少 systemd"
    [[ -x "$TARGET" ]] || fail "未找到 $TARGET"
    systemctl cat "$SERVICE" >/dev/null 2>&1 || fail "未找到 $SERVICE"
}

install_patch() {
    command -v curl >/dev/null || fail "缺少 curl"
    command -v sha256sum >/dev/null || fail "缺少 sha256sum"

    if "$TARGET" -v 2>&1 | grep -q 'v1.13-userdiff-fix'; then
        fail "修复补丁已经安装，无需重复安装"
    fi

    local download url actual_sha256 stamp backup
    TEMP_DIR=$(mktemp -d)
    download="$TEMP_DIR/$ASSET"

    url="https://github.com/$REPO/releases/download/$RELEASE/$ASSET"
    log "正在下载补丁版本"
    curl -fL --retry 3 --connect-timeout 15 "$url" -o "$download"

    actual_sha256=$(sha256sum "$download" | awk '{print $1}')
    [[ "$actual_sha256" == "$EXPECTED_SHA256" ]] || fail "SHA-256 校验失败"
    chmod 755 "$download"
    "$download" -v | grep -q 'v1.13-userdiff-fix' || fail "二进制版本不符合预期"

    stamp=$(date +%Y%m%d-%H%M%S)
    backup="${TARGET}.before-userdiff-${stamp}"
    cp -a "$TARGET" "$backup"

    log "正在安装补丁，现有连接可能会短暂中断"
    systemctl stop "$SERVICE"
    install -o root -g root -m 755 "$download" "$TARGET"

    if systemctl start "$SERVICE" && sleep 5 && systemctl is-active --quiet "$SERVICE"; then
        log "修复补丁安装成功"
        log "原版本备份：$backup"
        "$TARGET" -v
        return 0
    fi

    log "启动失败，正在恢复原版本：$backup"
    install -o root -g root -m 755 "$backup" "$TARGET"
    systemctl start "$SERVICE" || true
    fail "补丁版本启动失败，已恢复原版本"
}

uninstall_patch() {
    if ! "$TARGET" -v 2>&1 | grep -q 'v1.13-userdiff-fix'; then
        fail "当前未检测到修复补丁"
    fi

    local backups backup patched_copy
    shopt -s nullglob
    backups=("${TARGET}.before-userdiff-"*)
    shopt -u nullglob
    ((${#backups[@]} > 0)) || fail "未找到安装前的备份文件，无法卸载"
    backup="${backups[$((${#backups[@]} - 1))]}"

    TEMP_DIR=$(mktemp -d)
    patched_copy="$TEMP_DIR/xboard-node-patched"
    cp -a "$TARGET" "$patched_copy"

    log "正在卸载修复补丁，并恢复：$backup"
    systemctl stop "$SERVICE"
    install -o root -g root -m 755 "$backup" "$TARGET"

    if systemctl start "$SERVICE" && sleep 5 && systemctl is-active --quiet "$SERVICE"; then
        log "修复补丁已卸载，原版本恢复成功"
        "$TARGET" -v
        return 0
    fi

    log "原版本启动失败，正在恢复补丁版本"
    install -o root -g root -m 755 "$patched_copy" "$TARGET"
    systemctl start "$SERVICE" || true
    fail "卸载失败，已恢复补丁版本"
}

show_menu() {
    printf '\n'
    printf 'xboard-node UUID 更新修复补丁\n'
    printf '1. 安装修复\n'
    printf '2. 卸载修复\n'
    printf '\n'
}

check_common_requirements
show_menu
[[ -r /dev/tty ]] || fail "当前环境无法读取选项，请在终端中运行此命令"
read -r -p "请输入选项 [1-2]：" choice </dev/tty

case "$choice" in
    1) install_patch ;;
    2) uninstall_patch ;;
    *) fail "无效选项：$choice" ;;
esac
