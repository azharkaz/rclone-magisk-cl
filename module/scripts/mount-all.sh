#!/system/bin/sh
# mount-all.sh — universal mount loop for all rclone remotes.
# Supports two placement modes per remote via conf/mount-modes.conf:
#   internal -> /storage/emulated/0/magisk-mounts/<name> (+ all HyperOS sandbox views)
#   external -> /storage/<name> (+ top-level sandbox views), alongside the real SD card
#
# Must run in init's mount namespace (Magisk's post-fs-data/service.sh already do this;
# for manual testing from a separate root shell, wrap with:
#   nsenter --mount=/proc/1/ns/mnt -- sh mount-all.sh

MODDIR="${0%/*}/.."
RCLONE_BIN="$MODDIR/system/vendor/bin/rclone"
RCLONE_CFG="$MODDIR/conf/rclone.conf"
MODES_FILE="$MODDIR/conf/mount-modes.conf"
CACHE_DIR="$MODDIR/vfscache"
LOG_DIR="$MODDIR/logs"
export PATH="$MODDIR/system/vendor/bin:$PATH"

SUBDIR="magisk-mounts"
BASES_INTERNAL="/storage/emulated/0 /mnt/pass_through/0/emulated/0 /mnt/user/0/emulated/0 /mnt/installer/0/emulated/0 /mnt/androidwritable/0/emulated/0"
BASES_EXTERNAL="/storage /mnt/user/0 /mnt/installer/0 /mnt/androidwritable/0"

mkdir -p "$CACHE_DIR" "$LOG_DIR"

get_mode() {
  [ -f "$MODES_FILE" ] || { echo internal; return; }
  grep "^$1=" "$MODES_FILE" | tail -1 | cut -d= -f2 | tr -d ' \r'
}

[ -x "$RCLONE_BIN" ] || { echo "rclone binary not found at $RCLONE_BIN"; exit 1; }
[ -f "$RCLONE_CFG" ] || { echo "no rclone.conf at $RCLONE_CFG, nothing to mount"; exit 0; }

"$RCLONE_BIN" --config "$RCLONE_CFG" listremotes | sed 's/:$//' | while read -r NAME; do
  MNT_DIR="/mnt/rclone-$NAME"
  MODE=$(get_mode "$NAME")
  [ -z "$MODE" ] && MODE="internal"

  if [ "$MODE" = "external" ]; then
    BASES="$BASES_EXTERNAL"
    SUFFIX="$NAME"
  else
    BASES="$BASES_INTERNAL"
    SUFFIX="$SUBDIR/$NAME"
  fi

  # clean up any stale binds/mounts from a previous run (both schemes, in case mode changed)
  for BASE in $BASES_INTERNAL; do umount "$BASE/$SUBDIR/$NAME" 2>/dev/null; done
  for BASE in $BASES_EXTERNAL; do umount "$BASE/$NAME" 2>/dev/null; done
  umount "$MNT_DIR" 2>/dev/null
  pkill -f "rclone mount $NAME:" 2>/dev/null
  sleep 1
  rm -rf "$MNT_DIR"
  mkdir -p "$MNT_DIR"

  "$RCLONE_BIN" --config "$RCLONE_CFG" mount "$NAME:" "$MNT_DIR" \
    --allow-other --daemon \
    --dir-perms 0770 --file-perms 0660 --umask 000 \
    --vfs-cache-mode writes \
    --cache-dir "$CACHE_DIR" \
    --vfs-cache-max-size 512M --vfs-cache-max-age 6h \
    --attr-timeout 3s --uid 0 --gid 1015 \
    --log-file "$LOG_DIR/rclone-$NAME.log" -vv

  TRIES=0
  while ! mount | grep -q "^$NAME: on $MNT_DIR "; do
    sleep 1
    TRIES=$((TRIES+1))
    if [ $TRIES -ge 30 ]; then
      echo "TIMEOUT: $NAME did not mount in 30s"
      break
    fi
  done

  if mount | grep -q "^$NAME: on $MNT_DIR "; then
    for BASE in $BASES; do
      [ -d "$BASE" ] || continue
      TARGET="$BASE/$SUFFIX"
      mkdir -p "$TARGET" 2>/dev/null
      mount --bind "$MNT_DIR" "$TARGET" && echo "bind OK ($MODE): $TARGET" || echo "bind FAIL ($MODE): $TARGET"
      touch "$TARGET/.nomedia" 2>/dev/null
    done
    echo "done: $NAME ($MODE)"
  else
    echo "SKIPPED bind for $NAME — mount never became ready"
  fi
done
