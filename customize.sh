# Mount ro partitions
mount_name efs /efs '-o ro'
mount_name sec_efs /sec_efs '-o ro'
mount_name product /product '-o ro'
mount_name odm /odm '-o ro'
mount_name prism /prism '-o ro'
mount_name optics /optics '-o ro'

# Functions
get_omc_path() {
  if [ -d "/product/omc/" ]; then
    omc_root=/product/omc
  elif [ -d "/odm/omc/" ]; then
    omc_root=/odm/omc
  elif [ -d "/system/omc/" ]; then
    omc_root=/system/omc
  elif [ -d "/product/etc/omc/" ]; then
    omc_root=/product/etc/omc
  elif [ -d "/odm/etc/omc/" ]; then
    omc_root=/odm/etc/omc
  elif [ -d "/system/etc/omc/" ]; then
    omc_root=/system/etc/omc
  else
    if [ -d "/prism/etc/carriers/" ]; then
      if [ -d "/optics/configs/carriers/" ]; then
        if [ -d "/optics/configs/carriers/single/" ]; then
           omc_root=/optics/configs/carriers/single
        else
           omc_root=/optics/configs/carriers
        fi
      fi
    fi
  fi
}

# Paths
path_mps="/efs/imei/mps_code.dat";
path_mps2="/sec_efs/imei/mps_code.dat";

# Your script starts here
omc_code=`cat ${path_mps} 2>/dev/null`;
[ ! -z "$omc_code" ] || omc_code=`cat ${path_mps2} 2>/dev/null`;
[ -n "$omc_code" ] || abort "! Could not read the CSC code"

get_omc_path

[ -d "$omc_root/$omc_code" ] || abort "! OMC folder not found: $omc_root/$omc_code"
original_files=`find "$omc_root/$omc_code" -type f -name '*.xml'`
[ -n "$original_files" ] || abort "! No xml files found in $omc_root/$omc_code"

for i in $original_files; do
  grep -qF " $i " /proc/mounts && abort "! $i is already mounted by a module. Disable the module, reboot, then flash again"
done

ui_print "- Copy omc files"
chmod 755 $MODPATH/omc-decoder
: > $MODPATH/files.list
count=0
ui_print "- Start decoding..."
for i in $original_files; do
  [ "$(head -c 1 "$i")" = "<" ] && continue
  mkdir -p "$(dirname "$MODPATH$i")"
  if $MODPATH/omc-decoder -d "$i" "$MODPATH$i" >/dev/null 2>&1 && [ "$(head -c 1 "$MODPATH$i")" = "<" ]; then
    echo "$i" >> $MODPATH/files.list
    count=$((count+1))
    ui_print "- Successfully decoded $i!"
  else
    rm -f "$MODPATH$i"
    ui_print "- Not decoded $i!"
  fi
done
[ "$count" -gt 0 ] || abort "! Nothing was decoded"

echo "BUILD_FP='$(getprop ro.build.fingerprint)'" > $MODPATH/config.sh

# Set permissions and restore the original SELinux labels
set_perm_recursive "$MODPATH" 0 0 0755 0644
while read -r f; do
  chcon --reference="$f" "$MODPATH$f" || ui_print "! Could not copy the SELinux label of $f"
done < $MODPATH/files.list
chmod 755 $MODPATH/post-fs-data.sh

# Clean up files
rm -rf $MODPATH/omc-decoder
