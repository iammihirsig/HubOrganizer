#!/usr/bin/env bash
set -euo pipefail

DEMO_ROOT="demo_data"
mkdir -p "$DEMO_ROOT"
cd "$DEMO_ROOT"

EXTENSIONS=(jpg png pdf doc docx txt md mp4 mkv mp3 zip py js ts sh cpp java)

# Create nested folders
for i in {1..10}; do
    for j in {1..5}; do
        mkdir -p "Folder_$i/Sub_$j"
    done
done

count=1
while [ $count -le 5000 ]; do
    ext="${EXTENSIONS[$RANDOM % ${#EXTENSIONS[@]}]}"
    folder="Folder_$((RANDOM % 10 + 1))/Sub_$((RANDOM % 5 + 1))"

    # Ensure folder exists
    mkdir -p "$folder"

    # Some filenames with spaces
    if [ $((RANDOM % 5)) -eq 0 ]; then
        filename="file number $count.$ext"
    else
        filename="file_$count.$ext"
    fi

    # Create the file with content
    echo "Demo content $count" > "$folder/$filename"

    count=$((count + 1))
done

echo "✅ 5000 demo files created in $DEMO_ROOT"
