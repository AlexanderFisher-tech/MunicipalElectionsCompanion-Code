#!/bin/zsh
# Rebuilds Docs/MEC-iOS-Documentation.pdf from Docs/iOS-Documentation.md using headless Google Chrome.
DOCS="${0:A:h:h}"
TMP=$(mktemp -d)
python3 -I "$DOCS/tools/build_pdf.py" "$DOCS/iOS-Documentation.md" "$TMP/doc.html"
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --no-pdf-header-footer \
  --allow-file-access-from-files --print-to-pdf="$DOCS/MEC-iOS-Documentation.pdf" "file://$TMP/doc.html"
