#!/bin/bash
set -e
TMPDIR=$(mktemp -d tests/tmp.XXXXXX)
mkdir -p "$TMPDIR/library" "$TMPDIR/recipes" "$TMPDIR/bin" /home/calibre
cp example.recipe "$TMPDIR/recipes/test.recipe"
cat > "$TMPDIR/bin/calibredb" <<EOS
#!/bin/bash
echo "\$@" >> "$TMPDIR/cmd.log"
EOS
chmod +x "$TMPDIR/bin/calibredb"
cat > "$TMPDIR/bin/ebook-convert" <<EOS
#!/bin/bash
# create dummy output file
printf '' > "\$2"
EOS
chmod +x "$TMPDIR/bin/ebook-convert"
PATH="$TMPDIR/bin:$PATH" LIBRARY_FOLDER="$TMPDIR/library" RECIPES_FOLDER="$TMPDIR/recipes" DUPLICATE_STRATEGY="ignore" bash download_news.sh
grep -- '--duplicates ignore' "$TMPDIR/cmd.log"
rm -rf "$TMPDIR"
