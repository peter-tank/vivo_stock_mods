d=recovery/root
r=/data/local/AIK-mobile/ramdisk
echo '########working on:'
echo $d
read
strings $d/system/bin/* $d/system/lib64/* $d/vendor/bin/* $d/vendor/bin/hw/* $d/vendor/lib64/* $d/vendor/lib64/hw/* | grep bin/ | sort | uniq > bin
strings $d/system/bin/* $d/system/lib64/* $d/vendor/bin/* $d/vendor/bin/hw/* $d/vendor/lib64/* $d/vendor/lib64/hw/* | grep "^[^ \t].*\.so$" | sort | uniq > so

strings $d/system/bin/* $d/system/lib64/* $d/vendor/bin/* $d/vendor/bin/hw/* $d/vendor/lib64/* $d/vendor/lib64/hw/* | grep "^[^ \t].*\.log$" | sort | uniq > log

strings $d/system/bin/* $d/system/lib64/* $d/vendor/bin/* $d/vendor/bin/hw/* $d/vendor/lib64/* $d/vendor/lib64/hw/* | grep "^[^ \t].*\.prop$" | sort | uniq >> prop

echo '########depends:'
cat bin
grep -Fxvf whitelist so

echo '########shares:'
grep -Fxf whitelist so

echo '########gets(new .so to sync):'
c=$(comm -13 whitelist so)
rm gets ramdisk
for f in $c; do 
  g=$(find $d -type f -name "$f");
  test -n "$g" && echo "$g" || echo "${f}" >> ramdisk;
done
for f in $(cat ramdisk); do
  g=$(find $r -type f -name "$f");
  test -n "$g"  && echo "r: ${g:${#r}}" || { echo "########missing $f";echo "${f}" >> new;};
done | tee -a gets;

cat << EOF > README.md
# Android updates for vivo V2054A (PD2054)

\`\`\`
$(cat props_platform.txt)
\`\`\`

\`\`\`
$(tree)
\`\`\`
EOF
