#!/system/bin/sh
# auto-chmod-watch.sh — event-driven (inotify), not polling.
# For each SSH/SFTP remote listed in conf/ssh-remotes.conf, watches its local
# rclone mountpoint for writes and, on write-close, chmods +x the corresponding
# remote path IF the file's content is a shebang script or an ELF binary.
# Cloud remotes (Mega etc.) are never watched — chmod is meaningless there.
#
# conf/ssh-remotes.conf format, one per line:
#   <rclone-remote-name>=<host:port>=<user>=<password>=<remote-root-path>
# <remote-root-path> must match the "root" the rclone sftp remote resolves to
# (e.g. /root), so a locally-changed file maps to the correct remote path.
# Example:
#   OWRTzrt=172.29.159.62:22=root=mypassword=/root
#
# NOTE: inotify on a directory only reports its DIRECT children, not files in
# nested subfolders — this only auto-chmods files copied straight into the
# remote's top-level folder, not into subdirectories within it.

MODDIR="${0%/*}/.."
SSHRUN="$MODDIR/system/vendor/bin/sshrun"
REMOTES_FILE="$MODDIR/conf/ssh-remotes.conf"

[ -f "$REMOTES_FILE" ] || { echo "no $REMOTES_FILE, nothing to watch"; exit 0; }
[ -x "$SSHRUN" ] || { echo "sshrun binary not found at $SSHRUN"; exit 1; }

GEN_DIR="$MODDIR/scripts/generated"
mkdir -p "$GEN_DIR"

# inotifyd execs PROG directly (no shell), so PROG must be a single path with
# no embedded arguments. We generate one tiny wrapper per remote with its
# connection details baked in; inotifyd then calls it as:
#   wrapper EVENTS FILE [DIRFILE]
grep -v '^#' "$REMOTES_FILE" | grep -v '^[[:space:]]*$' | while IFS='=' read -r NAME ADDR USER PASS ROOT; do
  [ -z "$NAME" ] && continue
  MNT_DIR="/mnt/rclone-$NAME"
  WRAPPER="$GEN_DIR/chmod-$NAME.sh"

  cat > "$WRAPPER" << EOF
#!/system/bin/sh
exec "$MODDIR/scripts/chmod-on-write.sh" "$NAME" "$ADDR" "$USER" "$PASS" "$ROOT" "\$@"
EOF
  chmod 700 "$WRAPPER"

  ( inotifyd "$WRAPPER" "$MNT_DIR:cw" ) &
  echo "watching: $NAME ($MNT_DIR) via $WRAPPER"
done

wait
