#!/bin/bash

# New Workbench Setup Script
# Creates a structured workbench in ~/ALPHA/active/ with RDF & BibTeX support
# Usage: bash new-workbench.sh

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

ALPHA_HOME="${HOME}/ALPHA/active"

echo ""
echo "════════════════════════════════════════════════════════════"
echo "New Workbench Setup"
echo "════════════════════════════════════════════════════════════"
echo ""

# Check if ALPHA/active exists
if [[ ! -d "$ALPHA_HOME" ]]; then
    echo -e "${YELLOW}⚠️  $ALPHA_HOME not found. Run setup-alpha.sh first.${NC}"
    exit 1
fi

# Gather workbench metadata
echo -e "${BLUE}Workbench Information${NC}"
echo ""

read -p "Topic/slug (e.g., 'causal-inference'): " -r SLUG
SLUG=$(echo "$SLUG" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/-$//')

if [[ -z "$SLUG" ]]; then
    echo "Error: slug cannot be empty"
    exit 1
fi

# Generate date
DATE=$(date +%Y-%m)

# Build directory name
WB_NAME="wb-${DATE}-${SLUG}"
WB_PATH="$ALPHA_HOME/$WB_NAME"

# Check if it already exists
if [[ -d "$WB_PATH" ]]; then
    echo -e "${YELLOW}⚠️  $WB_NAME already exists${NC}"
    exit 1
fi

read -p "Title (full name): " -r TITLE
read -p "Description (brief): " -r DESCRIPTION
read -p "Author (default: $(git config user.name 2>/dev/null || echo 'You')): " -r AUTHOR
AUTHOR="${AUTHOR:-$(git config user.name 2>/dev/null || echo 'You')}"

echo ""
echo -e "${BLUE}Creating workbench: $WB_NAME${NC}"
echo ""

# Create directory structure
mkdir -p "$WB_PATH"/{papers,articles,reference}
echo "  ✓ Directories created"

# Create README
cat > "$WB_PATH/README.md" << EOF
# $TITLE

**Workbench:** \`$WB_NAME\`  
**Started:** $(date +"%Y-%m-%d")  
**Author:** $AUTHOR  

## Overview

$DESCRIPTION

## Where I Left Off

<!-- Summary of current progress, blockers, insights -->

## Next Steps

<!-- What's the plan moving forward? -->

## Key Insights

<!-- Major findings, connections, realizations -->

## Related Workbenches

<!-- Links to other workbenches in ~/ALPHA/active/ -->

## Files

- **\`workbench.ttl\`** — RDF ontology defining concepts and relationships
- **\`workbench.bib\`** — BibTeX file with publication metadata
- **\`papers/\`** — Research papers and PDFs
- **\`articles/\`** — Notes, summaries, blog posts
- **\`reference/\`** — Books, datasets, external resources

## Notes

Add topic concepts to \`workbench.ttl\` as you discover them. Update the BibTeX file when you add papers.

EOF
echo "  ✓ README.md created"

# Create workbench.ttl
NAMESPACE_URI="http://example.org/workbench/${WB_NAME}/"

cat > "$WB_PATH/workbench.ttl" << EOF
# RDF Ontology for Workbench: $WB_NAME
# Created: $(date +"%Y-%m-%d")
# Author: $AUTHOR

@prefix wb: <${NAMESPACE_URI}> .
@prefix skos: <http://www.w3.org/2004/02/skos/core#> .
@prefix dcterms: <http://purl.org/dc/terms/> .
@prefix dcat: <http://www.w3.org/ns/dcat#> .
@prefix owl: <http://www.w3.org/2002/07/owl#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix schema: <https://schema.org/> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

################################################################################
# WORKBENCH METADATA
################################################################################

wb:workbench a skos:ConceptScheme ;
    dcterms:title "$TITLE" ;
    dcterms:description "$DESCRIPTION" ;
    dcterms:created "$(date +"%Y-%m-%d")"^^xsd:date ;
    dcterms:modified "$(date +"%Y-%m-%d")"^^xsd:date ;
    schema:author "$AUTHOR" ;
    rdfs:comment "RDF ontology for tracking concepts and connections in this workbench" ;
    dcterms:hasPart wb:concept_template .

#################################################################################
## CONCEPTS
#################################################################################
#
## TEMPLATE: Copy this block and customize for each new concept
#wb:concept_template a skos:Concept ;
#    skos:prefLabel "Concept Name" ;
#    skos:definition "What this concept means in this context" ;
#    skos:broader wb:parent_concept ;
#    skos:narrower wb:child_concept ;
#    skos:related wb:related_concept ;
#    dcterms:references wb:pub_key_1 ;
#    owl:sameAs <http://dbpedia.org/resource/ExternalResource> ;
#    rdfs:comment "Additional notes about this concept" .
#
#################################################################################
## PUBLICATIONS & SOURCES
#################################################################################
#
## TEMPLATE: Reference a BibTeX entry with publication metadata
## The citation key should match entries in workbench.bib
## Format: wb:pub_{bibtex_key}
#
#wb:pub_key_1 a schema:ScholarlyArticle ;
#    dcterms:title "Paper/Resource Title" ;
#    schema:author "Author Name" ;
#    dcterms:issued "YYYY"^^xsd:gYear ;
#    dcterms:date "YYYY-MM-DD" ;
#    bibo:doi "10.xxxx/xxxxx" ;
#    schema:url <https://example.org/paper> ;
#    rdfs:comment "Quick notes on how this relates to the workbench" .
#
#################################################################################
## RELATIONSHIPS & NOTES
#################################################################################
#
## Example: Document a key finding or connection
#wb:finding_1 a rdfs:Resource ;
#    rdfs:label "Important Finding" ;
#    rdfs:comment "Description of what was found and its significance" ;
#    dcterms:isPartOf wb:concept_template ;
#    dcterms:references wb:pub_key_1 .
#
#################################################################################
## INSTRUCTIONS
#################################################################################
#
## To add a new concept:
## 1. Define it as: wb:your_concept a skos:Concept ;
## 2. Use skos:prefLabel for the name
## 3. Use skos:definition for the explanation
## 4. Link to other concepts with skos:broader, skos:narrower, skos:related
## 5. Reference papers with dcterms:references wb:pub_{key}
## 6. Optionally link to external resources with owl:sameAs
#
## To add a publication:
## 1. Add entry to workbench.bib with key: {citation_key}
## 2. Define here as: wb:pub_{citation_key} a schema:ScholarlyArticle ;
## 3. Include title, authors, year, DOI if available
## 4. Link concepts that use it with dcterms:references
#
## Useful vocabularies:
## - skos: Concept management (prefLabel, definition, broader, narrower, related)
## - dcterms: Dublin Core (title, creator, date, references, isPartOf)
## - schema.org: Structured data (ScholarlyArticle, author, url)
## - owl: Ontology (sameAs for external linking)
## - foaf: Social/person (Person, name, page)
## - bibo: Bibliographic (doi, isbn, pages)
EOF
echo "  ✓ workbench.ttl created"

# Create workbench.bib
cat > "$WB_PATH/workbench.bib" << 'EOF'
% BibTeX file for workbench publications
% Add publication metadata here
% Citation keys should match entries in workbench.ttl

% TEMPLATE: @article{key_name,
%   author = "Author Name",
%   title = "Article Title",
%   journal = "Journal Name",
%   year = 2024,
%   volume = 42,
%   pages = "100--120",
%   doi = "10.xxxx/xxxxx"
% }

% EXAMPLES OF ENTRY TYPES:

% Journal Article
% @article{author_year,
%   author = "First Last and Second Author",
%   title = "Article Title",
%   journal = "Journal Name",
%   year = 2024,
%   volume = 12,
%   number = 3,
%   pages = "45--67",
%   doi = "10.xxxx/xxxxx",
%   url = "https://example.org"
% }

% Conference Paper
% @inproceedings{author_year,
%   author = "First Last",
%   title = "Paper Title",
%   booktitle = "Proceedings of Conference Name",
%   year = 2024,
%   pages = "100--110",
%   doi = "10.xxxx/xxxxx"
% }

% Book
% @book{author_year,
%   author = "First Last",
%   title = "Book Title",
%   publisher = "Publisher Name",
%   year = 2024,
%   edition = "2nd"
% }

% Book Chapter
% @inbook{author_year,
%   author = "Chapter Author",
%   title = "Chapter Title",
%   booktitle = "Book Title",
%   publisher = "Publisher",
%   year = 2024,
%   pages = "45--67"
% }

% Thesis
% @phdthesis{author_year,
%   author = "First Last",
%   title = "Dissertation Title",
%   school = "University Name",
%   year = 2024
% }

% Website/Online Resource
% @misc{author_year,
%   author = "First Last",
%   title = "Resource Title",
%   howpublished = "\url{https://example.org}",
%   year = 2024,
%   note = "Accessed: 2024-MM-DD"
% }

% Add your publications below:

EOF
echo "  ✓ workbench.bib created"

# Create tasks.ttl
echo -e "${BLUE}Creating tasks.ttl...${NC}"

# Compute date 30 days from now (macOS and Linux compatible)
DATE_30=$(date -v +30d +%Y-%m-%d 2>/dev/null || date -d "+30 days" +%Y-%m-%d 2>/dev/null || echo "")

cat > "$WB_PATH/tasks.ttl" << EOF
# =============================================================================
# tasks.ttl — Workbench: $WB_NAME
# =============================================================================
# Task graph for the workbench timeline visualisation.
# Rendered by: ~/ALPHA/active/workbench-timeline.R
# =============================================================================

@prefix wb:     <${NAMESPACE_URI}> .
@prefix wbs:    <http://example.org/workbench/status#> .
@prefix schema: <https://schema.org/> .
@prefix rdfs:   <http://www.w3.org/2000/01/rdf-schema#> .
@prefix rdf:    <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix xsd:    <http://www.w3.org/2001/XMLSchema#> .

################################################################################
# STATUS VOCABULARY
# Defined here so this file is self-contained for SPARQL.
################################################################################

wbs:Active    a schema:ActionStatus ; rdfs:label "Active" .
wbs:Planned   a schema:ActionStatus ; rdfs:label "Planned" .
wbs:OnHold    a schema:ActionStatus ; rdfs:label "OnHold" .
wbs:Blocked   a schema:ActionStatus ; rdfs:label "Blocked" .
wbs:Completed a schema:ActionStatus ; rdfs:label "Completed" .

################################################################################
# TASKS
#
# TEMPLATE — copy and fill in:
#
# wb:task_name a schema:Action ;
#     schema:name          "Short description of the task" ;
#     schema:actionStatus  wbs:Planned ;          # Active | Planned | OnHold | Blocked | Completed
#     schema:startDate     "$(date +%Y-%m-%d)"^^xsd:date ;
#     schema:scheduledTime "${DATE_30}"^^xsd:date ;  # target completion (omit if unknown)
#     schema:priority      "high" ;               # high | medium | low
#     schema:about         wb:concept_name ;      # optional: links to concept in workbench.ttl
#     rdfs:comment         "Notes on this task, blockers, context" .
################################################################################

# Add tasks below:

EOF
echo "  ✓ tasks.ttl created"

# Optional: Initialize git repo
read -p "Initialize git repo? (y/n): " -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd "$WB_PATH"
    git init -q
    git config user.email "$(git config user.email)" 2>/dev/null || true
    
    cat > .gitignore << 'GITIGNORE'
# Temporary files
*.swp
*.swo
*~
.DS_Store
Thumbs.db

# PDF viewer cache
.zotero-ft-cache/

# BibTeX auxiliary files
*.aux
*.bbl
*.blg
*.bcf
*.xml

# Generated files
*.pdf.bak
GITIGNORE
    
    git add -A
    git commit -q -m "Initial workbench setup: $TITLE"
    echo "  ✓ Git repo initialized"
fi

cd - > /dev/null

# Summary
echo ""
echo "════════════════════════════════════════════════════════════"
echo -e "${GREEN}✓ Workbench Created!${NC}"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Location: $WB_PATH"
echo ""
echo "Files:"
echo "  • README.md        — Notes & progress"
echo "  • workbench.ttl    — RDF concepts & connections"
echo "  • workbench.bib    — Publication metadata"
echo "  • tasks.ttl        — Task graph (rendered by workbench-timeline.R)"
echo ""
echo "Directories:"
echo "  • papers/          — Research PDFs"
echo "  • articles/        — Notes & summaries"
echo "  • reference/       — Books, datasets, etc."
echo ""
echo "Next steps:"
echo "  1. cd $WB_PATH"
echo "  2. Edit README.md with your starting notes"
echo "  3. Add tasks to tasks.ttl, concepts to workbench.ttl"
echo "  4. Add papers to workbench.bib as you discover them"
echo "  5. Run ../workbench-timeline.R to visualise all active tasks"
echo ""
