# HubOrganizer v1 🚀

A modular CLI tool to recursively organize files into categorized folders.

## Features

- Recursive file scanning using fd
- Smart extension-based categorization
- Subcategories (PDF, Cpp, MP3, etc.)
- Dry-run preview with scrollable UI
- Duplicate-safe renaming
- Logging system
- Auto empty folder cleanup
- Real execution mode

## Usage

```bash
./hub.sh --dry-run ~/Downloads
./hub.sh ~/Downloads
