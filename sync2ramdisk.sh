d="recovery/root";
r="/data/local/AIK-mobile/ramdisk";
echo "########sync $d to:";
echo "$r";
echo -n "Press enter to continue.";
read;

_od="$PWD"
ssize () {
  test "$(stat -c "%s" "$1")" = "$(stat -c "%s" "$2")";
}
smd5sum () {
  test "$(md5sum -b "$1")" = "$(md5sum -b "$2")";
}
choice () {
  local _a;
  test -n "$*" && echo "$*";
  echo -n "  ? choice [y]?: ";
  read -r _a;
  test "$_a" = "y";
}
cd "$d" && {
  _g=$(find . -type f -print);
  for f in $_g; do
    f="${f:2}";
#    echo -n "$f";
    if test -f "$r/$f"; then
      if ! ssize "$f" "$r/$f"; then
	choice "  ! diff in file size: $f" && cat "$f" > "$r/$f";
	echo "  * [$?]re-sized: $f";
      else
	if smd5sum "$f" "$r/$f"; then
	  echo "  -       same: $f";
	else
	  cat "$f" > "$r/$f" 2>/dev/null;
	  echo "  * [$?]patched: $f";
	fi
      fi
    else
      cp "$f" "$r/$f" 2>/dev/null;
      echo "  + [$?]    new: $f";
    fi
  done
cd "$_od"
} || echo "access error: $d"
echo "patching system/bin/recovery not download updates, press enter to continue"
read
sed -ie 's|/system/bin/aria2c|/system/bin/aria2_|' "$r/system/bin/recovery";
