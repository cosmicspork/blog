#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to generate slug from title
generate_slug() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | tr ' ' '-' | sed 's/--*/-/g' | sed 's/^-\|-$//g'
}

# Function to validate date format
validate_date() {
    if date -d "$1" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

echo -e "${BLUE}Creating a new blog post...${NC}"
echo

# Get post title
while true; do
    read -p "Post title: " title
    if [[ -n "$title" ]]; then
        break
    fi
    echo -e "${RED}Title cannot be empty${NC}"
done

# Get post description (optional)
read -p "Description (optional): " description

# Get tags (optional)
echo "Tags (comma-separated, optional): "
read -p "> " tags_input

# Get categories (optional) 
echo "Categories (comma-separated, optional): "
read -p "> " categories_input

# Get date (default to today)
default_date=$(date +%Y-%m-%d)
while true; do
    read -p "Date [$default_date]: " date
    if [[ -z "$date" ]]; then
        date=$default_date
    fi
    
    if validate_date "$date"; then
        # Ensure date is in YYYY-MM-DD format
        date=$(date -d "$date" +%Y-%m-%d)
        break
    else
        echo -e "${RED}Invalid date format. Please use YYYY-MM-DD${NC}"
    fi
done

# Process tags and categories
process_taxonomy() {
    local input="$1"
    if [[ -z "$input" ]]; then
        echo ""
        return
    fi
    
    # Split by comma, trim whitespace, and format as TOML array
    echo "$input" | sed 's/,/\n/g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/.*/"&"/' | paste -sd ',' - | sed 's/^/[/;s/$/]/'
}

tags_toml=$(process_taxonomy "$tags_input")
categories_toml=$(process_taxonomy "$categories_input")

# Generate slug and filename
slug=$(generate_slug "$title")
filename="content/posts/${date}-${slug}.md"

# Check if file already exists
if [[ -f "$filename" ]]; then
    echo -e "${RED}Error: Post already exists at $filename${NC}"
    exit 1
fi

# Create the directory if it doesn't exist
mkdir -p "$(dirname "$filename")"

# Create the post file
{
    echo "+++"
    echo "title = \"$title\""
    echo "date = $date"
    echo "updated ="
    echo "description = \"$description\""
    echo "draft = true"
    
    # Add taxonomies section if we have tags or categories
    if [[ -n "$tags_toml" || -n "$categories_toml" ]]; then
        echo ""
        echo "[taxonomies]"
        [[ -n "$tags_toml" ]] && echo "tags = $tags_toml"
        [[ -n "$categories_toml" ]] && echo "categories = $categories_toml"
    fi
    
    echo "+++"
    echo ""
    echo "Write your post content here..."
} > "$filename"

echo
echo -e "${GREEN}✓ Created new post:${NC} $filename"
echo -e "${YELLOW}Don't forget to set draft = false when you're ready to publish!${NC}"