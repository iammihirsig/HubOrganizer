#!/usr/bin/env bash

DEFAULT_ROOT="$HOME/Downloads"

# Category mapping
declare -A CATEGORY_MAP=(
    [jpg]=Images [png]=Images [gif]=Images [jpeg]=Images [webp]=Images
    [pdf]=Documents [doc]=Documents [docx]=Documents [txt]=Documents [md]=Documents
    [mp4]=Videos [mkv]=Videos [mov]=Videos
    [mp3]=Audio [wav]=Audio
    [zip]=Archives [tar]=Archives [gz]=Archives
    [py]=Code [js]=Code [ts]=Code [sh]=Code [cpp]=Code [c]=Code [java]=Code
)

# Subcategory mapping (optional, for smart sorting)
declare -A SUBCATEGORY_MAP=(
    [pdf]=PDF
    [doc]=DOC
    [docx]=DOCX
    [txt]=TXT
    [md]=MD
    [py]=Python
    [js]=JavaScript
    [ts]=TypeScript
    [sh]=Shell
    [cpp]=Cpp
    [c]=C
    [java]=Java
)
