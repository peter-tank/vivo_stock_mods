#!/system/bin/sh
# mac:-mip > remote:-rip > gip(auto detect, fallback: 192.168.1.1), SoftAP mode force port: 7777, last running on: \$nip:\$nport for your scripting.
node="/tmp/nc_shell.pip"; # reconnect to updateto new settings
mac="xx:xx:xx:xx:xx:xx"; # blank to force mip, no arp checking, ignore CAPs
mip=""; # ignore online checking
remote="192.168.1.170"; # blank to force rip, no arp checking
rip=""; # ignore online checking
fip="192.168.1.170" # fallback IP on error.
port="7777"; # fallback: 7777
mod="/data/local/tmp/nc_shell/flash.src"; # fallback /data/local/tmp/nc_shell/flash.src, lost script dynamic loading on no access able place. MUST KEEP IN QUOTED.
log="/data/local/tmp/nc_shell/nc_shell.log"; # forced, changing need service fully reloads. MUST KEEP IN QUOTED.
RLOG="${RLOG:-"${log}"}"; # DO NOT CHANGE ME, script auto exit on diff with $log
delay=5; # re-checking timer in seconds, default: 5
vd="/sys/class/leds/vibrator"; # vibrator device
ldev="/sys/class/backlight/panel0-backlight/brightness"; # brightness device
ldevmax="/sys/class/backlight/panel0-backlight/max_brightness";  # max brightness
ldefault="1800"; # default brightness
aoffset="1614674534"; # TW_QCOM_ATS_OFFSET, utc: $(( ($(date +%s) - $(cat /sys/class/rtc/rtc0/since_epoch)) ))
echo "#!$0";
echo "#PATH=${PATH}";
# other globals: HEADER_LN DO_OFFSET RLOG dryrun_flash nip nport
# set -x
# DO NOT T0UCH THIS LINE
HEADER_LN="$(grep -nm1 -F "# DO NOT T0UCH THIS LINE" "$0" | sed -e 's/^\([0-9]*\):.*$/\1/')"; # cut header line number in this file for building the new .src config file.

_tdiff="$(( ($(date "+%s" 2>/dev/null) - $(cat /sys/class/rtc/rtc0/since_epoch)) ))";
test "$_tdiff" -lt "10" && DO_OFFSET=true || DO_OFFSET=false;
#
# rdate a qcom hard time correction version of date
# depends: $EPOCHREALTIME $DO_OFFSET $aoffset
rdate () {
local _fm _rd;
$DO_OFFSET && test -n "$aoffset" && _rd="-d@$((aoffset + $(date "+%s" 2>/dev/null))) ${1:-"+%D %H:%M:%S"}";
_fm="${_rd:-"${1:-"+%D %H:%M:%S"}"}";
date "$_fm" 2>/dev/null;
}

hex2ip () {
  for i in $(cat | sed -E 's/(..)(..)(..)(..)/\4 \3 \2 \1/') ; do
    printf "%d." $((16#$i));
  done | sed 's/.$//';
}

build_pip() {
  mknod "$node" p || {
    echo "  ! build name pip fails.";
    node="";
    return 1;
  }
}

test_set_pip () {
if test -w "$(dirname $node)"; then
  if test -w "$node"; then
    test -p "$node" && echo "  - reuse name pip: $node" || {
      rm -rf "$node";
      echo "  - [$?] rebuild name pip.";
      build_pip;
    }
  else
    build_pip;
  fi
else
  echo "  ! can not access: $node";
  node="";
  return 1;
fi
}

# 
# duration(ms), activate default device: vd="/sys/class/leds/vibrator";
# echo [duration_1[,sleep_1:-0.05]{1..n}] | vib
# depends: sed sleep
vib () {
  local _h;
  v() {
    local _n="$1";
    test -w "$vd/duration" && {
      echo -n "${_n:-100}" > "$vd/duration" 2>/dev/null;
      echo -n "1" > "$vd/activate" 2>/dev/null;
    }
    shift 1;
    test "$1" && $($*) || s;
  }
  s() {
    sleep "${1:-0.05}";
  }
  for _h in $(test "$#" -eq 0 && cat || printf '%s\n' "$@" | sed -e '/^\s*$/d'); do
    $(echo "$_h" | sed -e '/^\s*$/d' -e 's/,/\ns /' -e 's/^/v /');
  done
}

# light[brightness_1[,duration_1:-0.05]{1..n}]
# depends: sed sleep $lmax $ldev $ldefault
light () {
  local _h;
  n() {
    local _n="$1";
    test "$_n" -gt "$lmax" && _n="$lmax";
    test -w "$ldev" && echo -n "${_n:-$ldefault}" > "$ldev" 2>/dev/null;
    shift 1;
    test "$1" && $($*) || s;
  }
  s() {
    sleep ${1:-0.05};
  }
  for _h in $(test "$#" -eq 0 && cat || printf '%s\n' "$@" | sed -e '/^\s*$/d'); do
    $(echo "$_h" | sed -e '/^\s*$/d' -e 's/,/\ns /' -e 's/^/n /');
  done
}

# 
# ddf ()
# force flash all <block_name>-xxx.img under working dir.
# depends: dd $PWD $dryrun_flash=0|1
ddf () {
local img dst;
light $lmax,1;
for img in *.img; do
  dst="/dev/block/by-name/$(echo $img|cut -d'-' -f1)";
  if test $dryrun_flash -eq 1; then
    echo "  > dryrun: dd bs=4k if="$PWD/$img" of="$dst"";
    vib 1000,${delay:-5};
  elif test -b "$dst"; then
    echo "  #$(rdate)";
    dd bs=4k if="$PWD/$img" of="$dst";
    echo "  > flash[$?]: dd bs=4k if="$PWD/$img" of="$dst"";
    vib 1000,${delay:-5};
  else
    echo "  !!! no dev block: <$dst>";
    echo "  ? on: dd bs=4k if="$PWD/$img" of="$dst"";
    vib 500,0.5 500,${delay:-5}
  fi
done
light $ldefault;
}

# 
# check_do_flash <flash step dir name from workdir>
# depends: find sed sort ddf md5sum
# . pwd/dir pwd/dir/0 pwd/dir/0.md5sum pwd/dir/0/<block_name>-xxx.img
check_do_flash  () {
local _sl _fl _id _step imgd;
test -n "$1" || return 1
cd "$1" || return 2
_fl="$(find . -mindepth 1 -maxdepth 1 -type d -print | sed -e 's|^..||' | sort)";

_sl="$(count_key_down "VU" "5s")";
test "$_sl" -eq 0 && echo "  ? selection timer out in 5s." && return 3;

light 5,0.2;
for _step in $(seq 1 "$_sl"); do vib 300,0.3; done
light $ldefault;

echo "  ? flash step: [$_sl]";
test "$(count_combinds_down "VD" "5s")" -eq 1 || return 4

light 5,0.2;
for _step in $(seq 1 "$_sl"); do vib 200,0.2; done
echo "  ! confirmed flash step: [$_sl]";
light $ldefault;

for imgd in ${_fl}; do
  _id="$PWD/$imgd";
  test "$_sl" -ne 1 && _sl="$((_sl-1))" && continue;
  echo "  #$_id...";
  if test -d "${_id}" && test -f  "${_id}.md5sum"; then
    cd "$imgd" && {
      md5sum -c "../${imgd}.md5sum" 2>&1 >/dev/null;
      test $? -eq 0 && ddf || echo "  * error: md5sum or failure on flashing!";
      cd ../;
    } || echo "  * access error on: $imgd"    
  else
    echo "  ! no ${imgd}.md5sum, skiped."
  fi
  echo;
  test "$_sl" -eq 1 && break;
done
}

# 
# count_key_down <VU|VD|PO> [timeout:-2s]
# count key pressed times.
# depends: getevent grep wc
count_key_down () {
  local _ev _kc _keys;
  case "${1}" in
    "VU"):
      _ev="/dev/input/event1";
      _kc="0073";
      ;;
    "VD"):
      _ev="/dev/input/event0";
      _kc="0072";
      ;;
    "PO"):
      _ev="/dev/input/event0";
      _kc="0074";
      ;;
    *):
      echo "  - not a supported key name."
      return 1;;
  esac
  light 5 $lmax,0.1 5 $lmax,0.2;
  vib 250,0.2;
  timeout --foreground "${2:-2s}" getevent "$_ev" | grep -cxF "0001 $_kc 00000001";
  light $ldefault,0.2;
}

# 
# count_combinds_down <VU|VD|PO> [timeout:-2s]
# count key pressed times combinds with power key holds in recovery mode.
# depends: getevent grep wc
count_combinds_down () {
  light 5 $lmax,0.1 5 $lmax,0.1 5 $lmax,1;
  vib 250,4;
  test "$(getprop "recovery.service" "0")" != "0" && {
    test "$(getprop "recovery.power_key_long_hold" "0")" -ne 0 && count_key_down "$@" || echo 0;
  } || count_key_down "$@";
}

bbye () {
test -w "$node" && rm "$node";
vib 2000;
setprop nc_shell.status "stop";
}

# set -x;
vib 2000,5;
test "$(getprop nc_shell.status)" = "running" && exit 1;
trap bbye EXIT;
# ps -Af | grep $0 | grep  -qvF "grep" 2>/dev/null && exit 1;
setprop nc_shell.status "running";

get_header_n () {
local _header _ln;
_header="# DO NOT T0UCH THIS LINE";
_ln="$(grep -nm1 -F "$_header" "$1" 2>/dev/null | sed -e 's/^\([0-9]*\):.*$/\1/')";
echo "${_ln:-"0"}";
}

new_src_header () {
  local _ln;
  _ln="$(get_header_n "$1")";
  head -n "${_ln}" "$1" 2>/dev/null;
  sed -e "1,${_ln}d;" "$1" 2>/dev/null | grep "^#";
}

get_header_var () {
local _mod _var _hl _val;
_mod="$1"; shift 1;
_var="$1"; shift 1;

_hl="$(get_header_n "$_mod")";
_val="$(head -n "$_hl" "$_mod" 2>/dev/null | grep "^${_var}=\"[^$]*$" | tail -n 1 | cut -d"\"" -f2)";
echo "${_val}";
}

get_ready_logs () {
local _mod _lmod _llog _clog;
_mod="$1"; shift 1;

# TODO: better build up a checking list in log var preloading, avoid circling..
while test -f "$_mod"; do # the deepest log settings we can reach, fallback to initial: $RLOG
  _mod="$(get_header_var "$_mod" "mod")";
  _clog="$(get_header_var "$_mod" "log")";
  test -n "$_clog" && test -w "$(dirname "$_clog")" && _llog="${_clog:-"$_llog"}";
  test "$_lmod" = "${_mod:-"$_lmod"}" && break; # self refrence or no next .src
  _lmod="$_mod";
done
echo "${_llog:-"$1"}";
}

logs2cache_dir () {
local _ll;
_ll="/data/local/tmp/nc_shell/ls_${1}.log";
mkdir "$_ll" && cp -varf /tmp/ls_*.log "$_ll";
}
log="$(get_ready_logs "$mod" "$log")";
if test ! -w "$(dirname "$log")"; then
  log="/tmp/nc_shell_tmp.log";
  test -w "$(dirname "$log")" || log="/dev/stdout";
fi
RLOG="$log";
echo "#logs redirected to: $RLOG";

{
while true; do
vib 200,0.4 1000,${delay:-5};

echo -e "\n#$(rdate)($(rdate +%s)) $node";
# run dd cmd only in recovery mode on prop: `recovery.service=1`.
dryrun_flash=0;
if test $(id -u) -ne 0 || test "$(getprop "recovery.service" "0")" -eq 0; then
  dryrun_flash=1;
  echo "  ! dry run flash on mode only!";
fi

lmax=$(cat "$ldevmax" 2>/dev/null | grep -m1 "^[0-9]*$");
lmax=${lmax:-$ldefault};
mod=${mod:-"/data/local/tmp/nc_shell/flash.src"};
node=${node:-"/data/local/tmp/nc_shell/nc_shell.pip"};
fip="${fip:-"192.168.1.99"}";

test ! -d "$mod" && test ! -e "$mod" && test -w $(dirname "$mod") && new_src_header "$0" > "$mod" && echo "  + [$?] new source file sample: $mod";

if test -f "$mod";  then
  echo "#loading source file: $mod";
  source "$mod" 2>&1;
else
  echo "#failure on source file: $mod";
fi

echo "#$0"
test -n "$mac" && mip=$(grep -Fi "$mac" /proc/net/arp | cut -d' ' -f1 | head -1) && echo "  + mip: $mip";
test -n "$remote" && rip=$(grep wlan0 /proc/net/arp | cut -d' ' -f1 | grep -Fx "$remote") && echo "  + rip: $rip";
gip=$(grep wlan0 /proc/net/route | head -1 | cut -f3 | hex2ip) && echo "  + gip: $gip";

# mac > mip > remote:-rip > gip
if test -z "$gip" || test "$gip" = "0.0.0.0"; then
  gip="$fip";
  echo "  ! gateway IP error!";
fi

nip=${mip:-${rip:-${gip}}};
test "$nip" = "0.0.0.0" && {
  nip="$fip";
  echo "  - final IP error, set to failsafe!";
}
test "${#gip}" -ge 11 && {
  if test -d "/tmp/selector_wifi/SoftAP" || test -d "/cache/SoftAP"; then
    nip="$gip";
    port="7777";
    echo "  !! SoftAP[Gateway] mode!";
  fi
}
nport=${port:-"7777"};
test_set_pip || {
  for node in "/tmp/${mod##*/}.pip" "/cache/${mod##*/}.pip"; do
  test_set_pip && echo "  ! name pip error, fallback to: $node" && break || node="";
  done
}

test -p "$node" && {
  echo "toybox netcat: [$nip]:[$nport]";
  light 5,0.2;
  sh 0< "$node" 2>&1 | toybox netcat -w 5 "$nip" "$nport" 2>&1 >"$node";
  light $ldefault,1;
} | sed -e 's/^\(.*\)$/  - \1/g' || echo "  * netcat skiped."

log="$(get_ready_logs "$mod" "$log")"; # auto exit on deepest new log ready.
if test "$RLOG" != "$log"; then
  test -d "/tmp/" && {
    ls -Rlaph / > "/tmp/ls_$(rdate +%s).log";
    touch "/tmp/reload_nc";
  }
elif test -f "/tmp/reload_nc" && test ! -f "/tmp/copy_out" && test ! -f "/cache/copy_out"; then
#test "$(getprop recovery.crypto.decrypt.result)" = "success"; then
  test -d "/data/local/tmp/nc_shell" && {
    logs2cache_dir "$(rdate +%s)";
    touch "/tmp/copy_out";
    touch "/cache/copy_out";
    rm "/tmp/reload_nc";
    sleep 1; exit;
  }
fi

# test -d "/data/local/AIK-mobile" && light 5,0.2 $ldefault,1;
done;
} >> "$RLOG"
