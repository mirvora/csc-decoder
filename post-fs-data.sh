#!/system/bin/sh
MODDIR=${0%/*}

[ -f "$MODDIR/config.sh" ] || exit 0
. "$MODDIR/config.sh"
[ "$(getprop ro.build.fingerprint)" = "$BUILD_FP" ] || exit 0

while read -r f; do
  n=0
  while [ ! -e "$f" ] && [ "$n" -lt 5 ]; do sleep 1; n=$((n+1)); done
  [ -f "$f" ] || continue
  grep -qF " $f " /proc/mounts && continue
  mount --bind "$MODDIR$f" "$f"
done < "$MODDIR/files.list"
