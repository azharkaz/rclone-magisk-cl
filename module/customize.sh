SKIPUNZIP=0

set_perm_recursive "$MODPATH/scripts" 0 0 0755 0755
set_perm_recursive "$MODPATH/system/vendor/bin" 0 0 0755 0755
mkdir -p "$MODPATH/conf" "$MODPATH/vfscache" "$MODPATH/logs" "$MODPATH/scripts/generated"
