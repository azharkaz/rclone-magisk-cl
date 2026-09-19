#!/system/bin/sh
# Magisk runs this after boot-complete, already in the init mount namespace —
# no nsenter needed here (that was only required for manual testing from a
# separate root shell app with its own namespace).

MODDIR=${0%/*}

until [ "$(getprop sys.boot_completed)" = "1" ]; do
  sleep 2
done

sh "$MODDIR/scripts/mount-all.sh" >> "$MODDIR/logs/mount-all.log" 2>&1

# auto-chmod watcher runs for the life of the device; restarted if it ever
# exits (e.g. after all remotes' mounts got torn down and re-created)
(
  while true; do
    sh "$MODDIR/scripts/auto-chmod-watch.sh" >> "$MODDIR/logs/auto-chmod-watch.log" 2>&1
    sleep 5
  done
) &
