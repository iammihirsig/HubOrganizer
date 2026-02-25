#!/usr/bin/env bash
set -euo pipefail

# ----------------------------
# Step 0 — Variables
# ----------------------------
# Defaults
DRY_RUN=0
FULL_DRY_RUN=0
UNDO=0
UNDO_DRY_RUN=0
DEFAULT_ROOT="$HOME/Downloads"

# Single-pass arg parsing
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --dry-run-full) FULL_DRY_RUN=1 ;;
        --undo) UNDO=1 ;;
        --undo-dry-run) UNDO_DRY_RUN=1 ;;
    esac
done

FILES=()
declare -A FILE_DESTINATIONS
declare -A CATEGORY_COUNT

# Category mapping
declare -A CATEGORY_MAP=(
    [jpg]=Images [jpeg]=Images [png]=Images [gif]=Images [webp]=Images
    [pdf]=Documents [doc]=Documents [docx]=Documents [txt]=Documents [md]=Documents
    [mp4]=Videos [mkv]=Videos [mov]=Videos
    [mp3]=Audio [wav]=Audio
    [zip]=Archives [tar]=Archives [gz]=Archives
    [py]=Code [js]=Code [ts]=Code [sh]=Code [cpp]=Code [c]=Code [java]=Code
)
declare -A SUBCATEGORY_MAP=(
    [pdf]=PDF [doc]=DOC [docx]=DOCX [txt]=TXT [md]=MD
    [py]=Python [js]=JavaScript [ts]=TypeScript [sh]=Shell [cpp]=Cpp [c]=C [java]=Java
    [jpg]=JPG [jpeg]=JPEG [png]=PNG [gif]=GIF [webp]=WEBP
    [mp4]=MP4 [mkv]=MKV [mov]=MOV
    [mp3]=MP3 [wav]=WAV
    [zip]=ZIP [tar]=TAR [gz]=GZ
)

# ----------------------------
# Logging / Helpers
# ----------------------------
log_info() { echo -e "\e[34m[INFO]\e[0m $*"; }
log_success() { echo -e "\e[32m[SUCCESS]\e[0m $*"; }
log_error() { echo -e "\e[31m[ERROR]\e[0m $*"; }
cleanup() { echo; log_info "Exiting..."; exit 1; }
trap cleanup SIGINT

# ----------------------------
# Step 1 — Select Root Folder
# ----------------------------
select_root() {
    echo
    read -rp "Select root folder [Default: $DEFAULT_ROOT, q to quit]: " input

    # Quit
    if [[ "$input" == "q" ]]; then
        log_info "User chose to quit."
        exit 0
    fi

    # Default
    if [[ -z "$input" ]]; then
        ROOT="$DEFAULT_ROOT"

    # Absolute path
    elif [[ "$input" = /* && -d "$input" ]]; then
        ROOT="$input"

    # Relative path from current directory
    elif [[ -d "$PWD/$input" ]]; then
        ROOT="$PWD/$input"

    # Otherwise search entire HOME
    else
        # Try fd+fzf if available, otherwise fallback to find
        if command -v fd >/dev/null 2>&1 && command -v fzf >/dev/null 2>&1; then
            ROOT=$(fd -t d -i --no-ignore "$input" "$HOME" 2>/dev/null | fzf)
        else
            ROOT=$(find "$HOME" -type d -iname "*$input*" 2>/dev/null | head -n1 || true)
        fi

        if [[ -z "$ROOT" ]]; then
            log_error "No matching folders found."
            exit 1
        fi
    fi

    if [[ ! -d "$ROOT" ]]; then
        log_error "Invalid directory selected."
        exit 1
    fi

    log_success "Selected root: $ROOT"
}

# ----------------------------
# Step 2 — Scan Files
# ----------------------------
scan_files() {
    log_info "Scanning files recursively..."
    FILES=()
    if command -v fd >/dev/null 2>&1; then
        while IFS= read -r -d '' file; do
            FILES+=("$file")
        done < <(fd -t f -0 . "$ROOT" 2>/dev/null || true)
    else
        while IFS= read -r -d '' file; do
            FILES+=("$file")
        done < <(find "$ROOT" -type f -print0 2>/dev/null || true)
    fi

    if [[ "${#FILES[@]}" -eq 0 ]]; then
        log_info "No files found inside $ROOT"
        exit 0
    fi
    log_success "Found ${#FILES[@]} files."
}

# ----------------------------
# Step 3 — Categorize Files
# ----------------------------
categorize_files() {
    log_info "Categorizing files..."
    for file in "${FILES[@]}"; do
        filename="$(basename "$file")"
        if [[ "$filename" != *.* ]]; then
            category="Other"
            subcategory="Other"
        else
            ext="${filename##*.}"
            ext="${ext,,}"
            category="${CATEGORY_MAP[$ext]:-Other}"
            subcategory="${SUBCATEGORY_MAP[$ext]:-$ext}"
        fi
        FILE_DESTINATIONS["$file"]="$ROOT/$category/$subcategory"
        CATEGORY_COUNT["$category"]=$(( ${CATEGORY_COUNT["$category"]:-0} + 1 ))
    done
    log_success "Categorization complete."
}

# ----------------------------
# Step 4 — Show Summary
# ----------------------------
show_summary() {
    echo
    echo "========== Summary =========="
    echo "Total files: ${#FILES[@]}"
    echo
    for category in "${!CATEGORY_COUNT[@]}"; do
        printf "%-10s : %s\n" "$category" "${CATEGORY_COUNT[$category]}"
    done
    echo "============================="
}

# ----------------------------
# Step 5 — Confirmation
# ----------------------------
confirm_action() {
    echo
    read -rp "Proceed with organizing files? (y/N): " choice
    if [[ ! "$choice" =~ ^[Yy]$ ]]; then
        log_info "Operation cancelled."
        exit 0
    fi
}

# ----------------------------
# Step 6 — Execute Move
# ----------------------------
execute_move() {
    log_info "Moving files..."

    LOG_FILE="$ROOT/huborganizer.log"
    touch "$LOG_FILE"

    # Generate Run ID
    RUN_ID=$(date +"%Y-%m-%d_%H-%M-%S")

    # Mark run start
    echo "=== RUN START: $RUN_ID ===" >> "$LOG_FILE"

    for file in "${FILES[@]}"; do
        dest="${FILE_DESTINATIONS[$file]}"
        mkdir -p "$dest"

        filename="$(basename "$file")"
        target="$dest/$filename"

        # Handle duplicates
        if [[ -e "$target" ]]; then
            name="${filename%.*}"
            ext="${filename##*.}"
            counter=1
            while [[ -e "$dest/${name}_$counter.$ext" ]]; do
                ((counter++))
            done
            target="$dest/${name}_$counter.$ext"
        fi

        mv "$file" "$target"

        echo "$(date '+%Y-%m-%d %H:%M:%S') | $file → $target" >> "$LOG_FILE"
    done

    # Mark run end
    echo "=== RUN END: $RUN_ID ===" >> "$LOG_FILE"
    echo >> "$LOG_FILE"

    log_success "Organization complete."
    log_info "Log saved to $LOG_FILE"
}

# ----------------------------
# Undo — Extract Last Run
# ----------------------------
get_last_run_entries() {
    LOG_FILE="$ROOT/huborganizer.log"

    if [[ ! -f "$LOG_FILE" ]]; then
        log_error "No log file found."
        exit 1
    fi

    LAST_RUN_ID=$(grep "=== RUN START:" "$LOG_FILE" | tail -n1 | sed 's/=== RUN START: \(.*\) ===/\1/')

    if [[ -z "$LAST_RUN_ID" ]]; then
        log_error "No previous runs found."
        exit 1
    fi

    awk "/=== RUN START: $LAST_RUN_ID ===/,/=== RUN END: $LAST_RUN_ID ===/" "$LOG_FILE" \
        | grep " | "
}

# ----------------------------
# Undo — Restore Last Run
# ----------------------------
undo_last_run() {
    log_info "Preparing undo..."

    entries=$(get_last_run_entries)

    if [[ -z "$entries" ]]; then
        log_error "Nothing to undo."
        exit 1
    fi

    echo
    log_info "Undoing last run..."

    while IFS= read -r line; do

        old=$(echo "$line" | awk -F' \\| ' '{print $2}' | awk -F' → ' '{print $1}')
        new=$(echo "$line" | awk -F' → ' '{print $2}')

        if [[ ! -f "$new" ]]; then
            log_error "Missing file: $new (skipped)"
            continue
        fi

        mkdir -p "$(dirname "$old")"

        target="$old"

        if [[ -e "$target" ]]; then
            name="${old%.*}"
            ext="${old##*.}"
            counter=1
            while [[ -e "${name}_restored_$counter.$ext" ]]; do
                ((counter++))
            done
            target="${name}_restored_$counter.$ext"
        fi

        if [[ $UNDO_DRY_RUN -eq 1 ]]; then
            echo "[UNDO DRY RUN] $new → $target"
        else
            mv "$new" "$target"
            echo "Restored: $target"
        fi

    done <<< "$entries"

    if [[ $UNDO_DRY_RUN -eq 0 ]]; then
        log_success "Undo complete."
    fi

    # After successful undo, clean up empty category folders
    if [[ $UNDO_DRY_RUN -eq 0 ]]; then
        cleanup_categories_after_undo
    fi
}


# ----------------------------
# Post-undo cleanup of empty category folders
# ----------------------------
cleanup_categories_after_undo() {
    # Only run actual deletions when not a dry run
    if [[ $UNDO_DRY_RUN -eq 1 ]]; then
        log_info "Undo dry-run: skipping post-undo cleanup."
        return
    fi

    # Remove any empty directories under ROOT (category/subcategory folders)
    # Delete bottom-up to ensure nested empties are removed.
    deleted=$(find "$ROOT" -depth -type d -empty ! -path "$ROOT" -print -delete 2>/dev/null | wc -l || true)

    if [[ $deleted -gt 0 ]]; then
        log_success "Post-undo cleanup removed $deleted empty folder(s) under $ROOT"
    else
        log_info "No empty category folders to remove."
    fi
}


# ----------------------------
# Step 7 — Delete Empty Folders
# ----------------------------
# ----------------------------
# Step 7 — Delete Empty Source Folders
# ----------------------------
cleanup_empty_folders() {
    echo
    read -rp "[INFO] Remove empty source folders? (y/N): " del_choice
    [[ ! "$del_choice" =~ ^[Yy]$ ]] && {
        log_info "Empty folders left intact."
        return
    }

    # Delete empty directories bottom-up (deepest first)
    deleted=$(find "$ROOT" \
        -depth \
        -type d \
        -empty \
        ! -path "$ROOT" \
        -print -delete | wc -l)

    log_success "Deleted $deleted empty folder(s)."
}

# ----------------------------
# Step 8 — Dry-Run Preview
# ----------------------------
dry_run_preview() {
    echo
    log_info "Entering scrollable dry-run preview..."
    echo -e "\e[33mNavigation:\e[0m Use ↑/↓ to scroll, g/Home to top, G/End to bottom, / to search, q to quit."
    echo "Press any key to start preview..."
    read -rn1

    shorten_path() {
        local path="$1"
        local max_len=50
        if (( ${#path} > max_len )); then
            local start=${path:0:25}
            local end=${path: -25}
            echo "${start}…${end}"
        else
            echo "$path"
        fi
    }

    {
        for file in "${FILES[@]}"; do
            old=$(shorten_path "$file")
            new=$(shorten_path "${FILE_DESTINATIONS[$file]}")
            echo -e "\e[31m${old}\e[0m \e[33m→\e[0m \e[32m${new}\e[0m"
        done
    } | less -R

    log_success "Scrollable preview completed."
}

# ----------------------------
# Step 9 — Main
# ----------------------------
main() {
    select_root
    # If undo flag set, perform undo and exit
    if [[ $UNDO -eq 1 ]]; then
        undo_last_run
        exit 0
    fi
    scan_files
    categorize_files
    show_summary

    if [[ $DRY_RUN -eq 1 ]]; then
        dry_run_preview
        exit 0
    fi

    if [[ $FULL_DRY_RUN -eq 1 ]]; then
        DRY_FILE="$ROOT/.huborganizer_dryrun.log"
        echo "[FULL DRY RUN] Saving planned moves to $DRY_FILE"
        > "$DRY_FILE"
        for file in "${FILES[@]}"; do
            echo "$file → ${FILE_DESTINATIONS[$file]}" >> "$DRY_FILE"
        done
        exit 0
    fi

    confirm_action
    execute_move
    cleanup_empty_folders   # <-- delete empty folders after move
}

main
