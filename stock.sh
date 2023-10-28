stock="../stock"
echo "fetch missing from stock:"
echo "$stock"
read

for f in $(cat new); do
	echo $f..
	p="$(cd "$stock"; find . -type f -name "$f" -print)"
	echo "$stock/${p:2}";
	read
	test -n "$p" && cp -v "$stock/${p:2}" "./recovery/root/${p:2}";
done
