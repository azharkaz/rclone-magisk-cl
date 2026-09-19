These config files are created at runtime (by hand for now, later by the
companion app) — they are never committed to the repo since they hold
credentials.

## rclone.conf
Standard rclone config format (`rclone config`), holding every backend
(cloud and SFTP alike). This is what `mount-all.sh` reads to know which
remotes exist.

## mount-modes.conf
```
# <rclone-remote-name>=internal|external
OWRTzrt=external
meganz=internal
```
`internal` binds under `/storage/emulated/0/magisk-mounts/<name>` (default,
safest, works everywhere). `external` binds at `/storage/<name>`, alongside
the real SD card — cosmetically closer to a separate volume in file
managers, though it will not appear as a distinct entry in Android's own
storage-volume list (that requires real vold/uevent block-device
registration, which this project intentionally does not attempt).

## ssh-remotes.conf
```
# <rclone-remote-name>=<host:port>=<user>=<password>=<remote-root-path>
OWRTzrt=172.29.159.62:22=root=mypassword=/root
```
Only SSH/SFTP remotes that should get auto-chmod-on-write belong here.
Never list cloud remotes (Mega etc.) — chmod is meaningless there and this
file is skipped entirely for anything not listed.
