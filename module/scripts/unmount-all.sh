#!/system/bin/sh
# unmount-all.sh — tears down every remote's mount and binds, without
# remounting. Safe to run repeatedly; already-unmounted remotes are skipped
# silently (umount errors on missing mountpoints are suppressed).

MODDIR="${0%/*}/.."
RCLONE_BIN="$MODDIR/system/vendor/bin/rclone"
RCLONE_CFG="$MODDIR/conf/rclone.conf"

SUBDIR="magisk-mounts"
BASES_INTERNAL="/storage/emulated/0 /mnt/pass_through/0/emulated/0 /mnt/user/0/emulated/0 /mnt/installer/0/emulated/0 /mnt/androidwritable/0/emulated/0"
BASES_EXTERNAL="/storage /mnt/user/0 /mnt/installer/0 /mnt/androidwritable/0"

[ -f "$RCLONE_CFG" ] || { echo "no rclone.conf, nothing to unmount"; exit 0; }

"$RCLONE_BIN" --config "$RCLONE_CFG" listremotes | sed 's/:$//' | while read -r NAME; do
  for BASE in $BASES_INTERNAL; do umount "$BASE/$SUBDIR/$NAME" 2>/dev/null; done
  for BASE in $BASES_EXTERNAL; do umount "$BASE/$NAME" 2>/dev/null; done
  umount "/mnt/rclone-$NAME" 2>/dev/null
  pkill -f "rclone mount $NAME:" 2>/dev/null
  echo "unmounted: $NAME"
done
