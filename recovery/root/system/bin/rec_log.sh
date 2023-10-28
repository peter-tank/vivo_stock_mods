#!/system/bin/sh
aoffset="1614674534"; # TW_QCOM_ATS_OFFSET
_tdiff="$(( ($(date "+%s" 2>/dev/null) - $(cat /sys/class/rtc/rtc0/since_epoch)) ))";
test "$_tdiff" -lt "10" && DO_OFFSET=true || DO_OFFSET=false;
#
# rdate a qcom hard time correction version of date
rdate () {
local _fm _rd;
$DO_OFFSET && test -n "$aoffset" && _rd="-d@$((aoffset + $(date "+%s" 2>/dev/null))) ${1:-"+%D %H:%M:%S"}";
_fm="${_rd:-"${1:-"+%D %H:%M:%S"}"}";
date "$_fm" 2>/dev/null;
}
  _log_sets () {
    local _d;
    _d="/data/local/tmp/nc_shell";
    test -d "$_d" || _d="/tmp";
    mkdir "$_d/$_stl" 2>/dev/null;
    echo "#$(rdate +%s): [${1}]=[${2}]" >> "$_d/_$stl/props_test.log";
  }
  _log_props () {
    local _d;
    _d="/data/local/tmp/nc_shell";
    test -d "$_d" || _d="/tmp";
    mkdir "$_d/$_stl" 2>/dev/null;
    _lpr="$_d/$_stl/props_last.log";
    _npr="$_d/$_stl/props_now.log";
    _dpr="$_d/$_stl/prop_changing.log";
    test ! -f "$_lpr" && getprop > "$_lpr" && return;
    getprop > "$_npr" && diff -q "$_lpr" "$_npr"  || {
      echo "#$(rdate +%s)" >> "$_dpr";
      diff "$_lpr" "$_npr" >> "$_dpr";
      cat "$_npr" > "$_lpr";
    }
  }

  _log_dirs () {
    local _d;
    _d="/data/local/tmp/nc_shell";
    test -d "$_d" || _d="/tmp";
    mkdir "$_d/$_stl" 2>/dev/null;
    _lpr="$_d/$_stl/dirs_last.log";
    _npr="$_d/$_stl/dirs_now.log";
    _dpr="$_d/$_stl/dir_changing.log";
    test ! -f "$_lpr" && find / -type d -print > "$_lpr" && return;
    find / -type d -print > "$_npr" && diff -q "$_lpr" "$_npr"  || {
      echo "#$(rdate +%s)" >> "$_dpr";
      diff "$_lpr" "$_npr" >> "$_dpr";
      cat "$_npr" > "$_lpr";
    }
  }

test -z "$_stl" && _stl="$(rdate +%s).log";
while true; do
  for _v in $(seq 1 10); do
    _log_props;
    _log_dirs;
  done
  test -w "/data/local/tmp/nc_shell" && cp -rf /tmp/*.log /data/local/tmp/nc_shell;
  touch "/data/local/tmp/nc_shell/props.test";
  test -f "/data/local/tmp/nc_shell/props.test" && {
    for _p in "$(cat "/data/local/tmp/nc_shell/props.test" | grep -v "^#")"; do
    _p="$(cut -d'|' -f1)";
    _v="$(cut -d'|' -f2)";
    setprop "$_p" "$_v" && _log_sets "$_p" "$_v";
    done
  }
done
