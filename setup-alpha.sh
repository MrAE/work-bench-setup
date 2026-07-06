#!/bin/bash

# ALPHA Directory Setup Script
# Creates a modern home directory structure with cleanup utilities
# Usage: bash setup-alpha.sh

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

ALPHA_HOME="${HOME}/ALPHA"

echo ""
echo "════════════════════════════════════════════════════════════"
echo "ALPHA Directory Setup"
echo "════════════════════════════════════════════════════════════"
echo ""

# Check if ALPHA already exists
if [[ -d "$ALPHA_HOME" ]]; then
    echo -e "${YELLOW}⚠️  $ALPHA_HOME already exists${NC}"
    read -p "Proceed anyway? (y/n): " -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
fi

# Create directory structure
echo -e "${BLUE}Creating directory structure...${NC}"
mkdir -p "$ALPHA_HOME"/{dev,library,writing,active,archive,scratch}
echo "  ✓ Directories created"
echo ""

# Create README for active/
echo -e "${BLUE}Creating active/README.md...${NC}"
cat > "$ALPHA_HOME/active/README.md" << 'EOF'
# active/

## Purpose

Workspace for projects currently in progress. This is your desk—messy is fine, but organize regularly.

## Contents

- Work-in-progress code, analysis, writing
- Temporary outputs while developing
- Datasets you're actively using
- Notes and experiments tied to current projects

## Cleanup Policy

**No auto-deletion.** The `CLEANUP` script only *warns* about files untouched for 180+ days.

When warned, move stale items to:
- **`../archive/`** if the project is complete or dormant (organize by year)
- **`../library/`** if it's reference material you've finished with
- **`../dev/`** if it should live in a git repo
- Delete if truly no longer needed

## Exempt from Cleanup

- `.git/` directories (entire git repos)
- Files/folders you explicitly whitelist in `.cleanupignore`

## When to Run

Monthly or when the folder feels chaotic. Run with:

```bash
./CLEANUP                 # Dry-run (shows what would be flagged)
./CLEANUP --confirm       # Acknowledge and log
```

## Tips

- Keep active projects in version control (git)—they're naturally protected
- Move finished work to `archive/` before it gets flagged
- Use descriptive folder names so you remember what's in progress
EOF
echo "  ✓ active/README.md created"
echo ""

# Create README for scratch/
echo -e "${BLUE}Creating scratch/README.md...${NC}"
cat > "$ALPHA_HOME/scratch/README.md" << 'EOF'
# scratch/

## Purpose

Temporary storage for downloads, screenshots, test files, and ephemeral work. Think of this as a trash bin you occasionally clean.

## Contents

- Downloads that haven't been sorted
- Screenshots and temp captures
- Test files and one-off experiments
- Junk that doesn't belong elsewhere yet

## Cleanup Policy

**Auto-delete files untouched for 30 days.** The `CLEANUP` script removes old files after confirmation.

If you need something longer-term, move it:
- To **`../library/`** if it's reference material
- To **`../dev/`** if it's code (especially if it should be versioned)
- To **`../active/`** if you're actively using it
- To **`../writing/`** if it's prose or documentation

## Exempt from Cleanup

- `.git/` directories (entire git repos)
- Files in subdirectories named `.keep/` (for intentional persistence)
- Files/folders you explicitly whitelist in `.cleanupignore`

## When to Run

Weekly or when the folder is cluttered. Run with:

```bash
./CLEANUP                 # Dry-run (shows what would be deleted)
./CLEANUP --confirm       # Actually delete old files
```

## Tips

- This is *not* a backup. Deleted files are gone.
- Screenshot accumulation happens fast—move keepers to `library/` early.
- `.dmg` files and installers are safe to delete once installed.
EOF
echo "  ✓ scratch/README.md created"
echo ""

# Create CLEANUP script for scratch/
echo -e "${BLUE}Creating scratch/CLEANUP...${NC}"
cat > "$ALPHA_HOME/scratch/CLEANUP" << 'SCRIPT'
#!/bin/bash

# CLEANUP script for scratch/ folder
# Removes files untouched for 30+ days
# Usage: ./CLEANUP          (dry-run, shows what would be deleted)
#        ./CLEANUP --confirm (actually delete)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/.cleanup.log"
IGNOREFILE="$SCRIPT_DIR/.cleanupignore"
DAYS_THRESHOLD=30
CONFIRM="${1:---dry-run}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "════════════════════════════════════════════════════════════"
echo "CLEANUP: scratch/ folder (files untouched for ${DAYS_THRESHOLD}+ days)"
echo "════════════════════════════════════════════════════════════"
echo ""

# Function to check if a path should be ignored
should_ignore() {
    local path="$1"
    
    # Always ignore .git directories
    if [[ "$path" == *".git"* ]]; then
        return 0
    fi
    
    # Check .cleanupignore file if it exists
    if [[ -f "$IGNOREFILE" ]]; then
        while IFS= read -r pattern; do
            # Skip comments and empty lines
            [[ "$pattern" =~ ^#.*$ || -z "$pattern" ]] && continue
            
            if [[ "$path" == *"$pattern"* ]]; then
                return 0
            fi
        done < "$IGNOREFILE"
    fi
    
    return 1
}

# Find files to clean
DELETED_COUNT=0
CANDIDATES=()

while IFS= read -r file; do
    # Skip hidden system files at root level
    if [[ "$(basename "$file")" == .* ]] && [[ "$file" == "$SCRIPT_DIR"/* ]]; then
        continue
    fi
    
    if should_ignore "$file"; then
        continue
    fi
    
    CANDIDATES+=("$file")
done < <(find "$SCRIPT_DIR" -maxdepth 3 -not -path "*/.*" -type f -mtime +${DAYS_THRESHOLD} 2>/dev/null)

if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
    echo -e "${GREEN}✓ No files to clean. Looking good!${NC}"
    echo ""
    exit 0
fi

# Display candidates
echo -e "${YELLOW}Found ${#CANDIDATES[@]} file(s) untouched for ${DAYS_THRESHOLD}+ days:${NC}"
echo ""

for file in "${CANDIDATES[@]}"; do
    relative_path="${file#"$SCRIPT_DIR/"}"
    mod_time=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$file" 2>/dev/null || stat --format=%y "$file" 2>/dev/null | cut -d' ' -f1-2 || echo "unknown")
    size=$(du -h "$file" 2>/dev/null | cut -f1)
    echo "  • $relative_path (modified: $mod_time, size: $size)"
done

echo ""
echo "════════════════════════════════════════════════════════════"

if [[ "$CONFIRM" == "--confirm" ]]; then
    echo ""
    read -p "⚠️  Delete these files? (type 'yes' to confirm): " -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        for file in "${CANDIDATES[@]}"; do
            if rm "$file" 2>/dev/null; then
                relative_path="${file#"$SCRIPT_DIR/"}"
                echo "  Deleted: $relative_path"
                DELETED_COUNT=$((DELETED_COUNT + 1))
            fi
        done
        
        echo ""
        echo -e "${GREEN}✓ Deleted $DELETED_COUNT file(s).${NC}"
        
        # Log the action
        {
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] Deleted $DELETED_COUNT file(s)"
            for file in "${CANDIDATES[@]}"; do
                echo "  - ${file#"$SCRIPT_DIR/"}"
            done
        } >> "$LOG_FILE"
    else
        echo "Cancelled. No files deleted."
    fi
else
    echo ""
    echo -e "${YELLOW}DRY-RUN MODE${NC} (no files deleted)"
    echo "Run with ${YELLOW}./CLEANUP --confirm${NC} to actually delete."
    echo ""
fi
SCRIPT

chmod +x "$ALPHA_HOME/scratch/CLEANUP"
echo "  ✓ scratch/CLEANUP created (executable)"
echo ""

# Create CLEANUP script for active/
echo -e "${BLUE}Creating active/CLEANUP...${NC}"
cat > "$ALPHA_HOME/active/CLEANUP" << 'SCRIPT'
#!/bin/bash

# CLEANUP script for active/ folder
# Warns about files untouched for 180+ days (never auto-deletes)
# Usage: ./CLEANUP          (shows stale items)
#        ./CLEANUP --confirm (acknowledge and log)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/.cleanup.log"
IGNOREFILE="$SCRIPT_DIR/.cleanupignore"
DAYS_THRESHOLD=180
CONFIRM="${1:---dry-run}"

# Colors for output
RED='\033[0;31m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "════════════════════════════════════════════════════════════"
echo "CLEANUP: active/ folder (files untouched for ${DAYS_THRESHOLD}+ days)"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "⚠️  REMINDER ONLY (no files will be deleted)"
echo ""

# Function to check if a path should be ignored
should_ignore() {
    local path="$1"
    
    # Always ignore .git directories
    if [[ "$path" == *".git"* ]]; then
        return 0
    fi
    
    # Check .cleanupignore file if it exists
    if [[ -f "$IGNOREFILE" ]]; then
        while IFS= read -r pattern; do
            # Skip comments and empty lines
            [[ "$pattern" =~ ^#.*$ || -z "$pattern" ]] && continue
            
            if [[ "$path" == *"$pattern"* ]]; then
                return 0
            fi
        done < "$IGNOREFILE"
    fi
    
    return 1
}

# Find files to flag
CANDIDATES=()

while IFS= read -r file; do
    # Skip hidden system files at root level
    if [[ "$(basename "$file")" == .* ]] && [[ "$file" == "$SCRIPT_DIR"/* ]]; then
        continue
    fi
    
    if should_ignore "$file"; then
        continue
    fi
    
    CANDIDATES+=("$file")
done < <(find "$SCRIPT_DIR" -maxdepth 3 -not -path "*/.*" -type f -mtime +${DAYS_THRESHOLD} 2>/dev/null)

if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
    echo -e "${GREEN}✓ No stale items. Active folder is tidy!${NC}"
    echo ""
    exit 0
fi

# Display candidates for action
echo -e "${RED}Found ${#CANDIDATES[@]} item(s) untouched for ${DAYS_THRESHOLD}+ days:${NC}"
echo ""
echo "Please organize or move these to appropriate locations:"
echo ""

for file in "${CANDIDATES[@]}"; do
    relative_path="${file#"$SCRIPT_DIR/"}"
    mod_time=$(stat -f "%Sm" -t "%Y-%m-%d" "$file" 2>/dev/null || stat --format=%y "$file" 2>/dev/null | cut -d' ' -f1 || echo "unknown")
    days_ago=$(( ($(date +%s) - $(stat -f "%m" "$file" 2>/dev/null || stat --format=%Y "$file" 2>/dev/null || date +%s)) / 86400 ))
    
    echo -e "  ${BLUE}→${NC} $relative_path"
    echo "      Last modified: $mod_time ($days_ago days ago)"
done

echo ""
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Consider moving to:"
echo "  • ../archive/   if the project is complete or dormant"
echo "  • ../library/   if it's reference material"
echo "  • ../dev/       if it should be in version control (git)"
echo ""

if [[ "$CONFIRM" == "--confirm" ]]; then
    echo ""
    read -p "Acknowledge these reminders? (y/n): " -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}✓ Logged.${NC} Please organize these items."
        
        # Log the reminder
        {
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] Flagged ${#CANDIDATES[@]} stale item(s)"
            for file in "${CANDIDATES[@]}"; do
                echo "  - ${file#"$SCRIPT_DIR/"}"
            done
        } >> "$LOG_FILE"
    else
        echo "Cancelled."
    fi
else
    echo -e "${YELLOW}Run with ./CLEANUP --confirm${NC} to acknowledge and log these reminders."
    echo ""
fi
SCRIPT

chmod +x "$ALPHA_HOME/active/CLEANUP"
echo "  ✓ active/CLEANUP created (executable)"
echo ""

# Summary
echo "════════════════════════════════════════════════════════════"
echo -e "${GREEN}✓ Setup Complete!${NC}"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Location: $ALPHA_HOME"
echo ""
echo "Structure:"
echo "  dev/          - Git repos & coding projects"
echo "  library/      - Reference material (read-only)"
echo "  writing/      - Prose & documentation"
echo "  active/       - Work-in-progress (warnings at 180 days)"
echo "  archive/      - Completed work"
echo "  scratch/      - Temp junk (auto-delete at 30 days)"
echo ""
echo "Next steps:"
echo "  1. cd $ALPHA_HOME"
echo "  2. Read the READMEs in active/ and scratch/"
echo "  3. Create .cleanupignore files as needed"
echo "  4. Add an alias to your shell config:"
echo ""
echo "     alias alpha='cd $ALPHA_HOME'"
echo ""
