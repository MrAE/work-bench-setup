#!/bin/bash

# render-workbench.sh
# Renders self-contained HTML reports from workbench-report.Rmd
#
# Usage:
#   ./render-workbench.sh                     # render all workbenches
#   ./render-workbench.sh wb-2026-06-demo     # render one
#   ./render-workbench.sh wb-2026-06-a wb-2026-06-b  # render several

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/workbench-report.Rmd"
REPORTS_DIR="$SCRIPT_DIR/reports"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "════════════════════════════════════════════════════════════"
echo "Workbench Report Renderer"
echo "════════════════════════════════════════════════════════════"
echo ""

# Verify template exists
if [[ ! -f "$TEMPLATE" ]]; then
    echo -e "${RED}✗ Template not found: $TEMPLATE${NC}"
    exit 1
fi

# Verify Rscript is available
if ! command -v Rscript &>/dev/null; then
    echo -e "${RED}✗ Rscript not found. Is R installed?${NC}"
    exit 1
fi

# Ensure reports directory exists
mkdir -p "$REPORTS_DIR"

# Determine which workbenches to render
if [[ $# -eq 0 ]]; then
    # All wb-YYYY-MM-* directories
    mapfile -t WB_DIRS < <(find "$SCRIPT_DIR" -maxdepth 1 -type d \
        -name "wb-[0-9][0-9][0-9][0-9]-[0-9][0-9]-*" | sort)

    if [[ ${#WB_DIRS[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No workbench directories found in: $SCRIPT_DIR${NC}"
        exit 0
    fi

    echo "Rendering all ${#WB_DIRS[@]} workbench(es)..."
else
    WB_DIRS=()
    for arg in "$@"; do
        dir="$SCRIPT_DIR/$arg"
        if [[ ! -d "$dir" ]]; then
            echo -e "${YELLOW}⚠  Skipping (not found): $arg${NC}"
        else
            WB_DIRS+=("$dir")
        fi
    done

    if [[ ${#WB_DIRS[@]} -eq 0 ]]; then
        echo -e "${RED}✗ No valid workbench directories to render.${NC}"
        exit 1
    fi
fi

echo ""

# Render each workbench
SUCCESS=0
FAILED=0

for wb_dir in "${WB_DIRS[@]}"; do
    wb_name="$(basename "$wb_dir")"
    out_file="$REPORTS_DIR/${wb_name}.html"

    echo -e "${BLUE}Rendering:${NC} $wb_name"

    # Build Rscript inline call — paths escaped for R
    r_wb_path="${wb_dir//\\/\\\\}"
    r_template="${TEMPLATE//\\/\\\\}"
    r_out="${out_file//\\/\\\\}"

    if Rscript --no-init-file -e "
        rmarkdown::render(
            input       = '$r_template',
            params      = list(wb_path = '$r_wb_path'),
            output_file = '$r_out',
            quiet       = TRUE
        )
    " 2>&1; then
        echo -e "  ${GREEN}✓ ${out_file}${NC}"
        SUCCESS=$((SUCCESS + 1))
    else
        echo -e "  ${RED}✗ Render failed: $wb_name${NC}"
        FAILED=$((FAILED + 1))
    fi

    echo ""
done

# Summary
echo "════════════════════════════════════════════════════════════"
echo -e "${GREEN}✓ $SUCCESS rendered${NC}" \
    $([ $FAILED -gt 0 ] && echo -e "  ${RED}✗ $FAILED failed${NC}")
echo ""
echo "Reports: $REPORTS_DIR"
echo ""
