# xboard-node UUID replacement fix

This repository fixes an `xboard-node` v1.13 user synchronization bug that
appears after an Xboard user resets their subscription credentials.

When a user's UUID changes without changing the database user ID, the old
UUID was not included in the removal set. Xray could therefore keep the old
identity while rejecting the new one as a duplicate. This is especially
visible on VLESS Encryption nodes: an old profile keeps working while the new
profile fails.

## One-command install

Linux amd64 with the standard systemd installation:

```bash
curl -fsSL https://raw.githubusercontent.com/Tweakl/xboard-node-userdiff-fix/main/install.sh | sudo bash
```

The installer:

- checks the system architecture and existing installation;
- verifies the release binary with SHA-256;
- keeps a timestamped backup of the current binary;
- restarts `xboard-node.service` and checks its health;
- automatically rolls back if the patched binary fails to start.

It does not read, modify, or upload Xboard configuration, node credentials,
user data, IP addresses, or domain names.

## Manual review

The complete source change and regression test are in
[`fix-userdiff.patch`](fix-userdiff.patch). It applies to upstream tag
[`v1.13`](https://github.com/cedar2025/xboard-node/releases/tag/v1.13).

## Rollback

The installer prints the backup path after a successful installation. To
restore it:

```bash
sudo systemctl stop xboard-node
sudo install -m 755 /usr/local/bin/xboard-node.before-userdiff-YYYYMMDD-HHMMSS /usr/local/bin/xboard-node
sudo systemctl start xboard-node
```

## Scope

This is an independently built compatibility patch, not an official upstream
release. The patch is intentionally limited to UUID replacement behavior.
