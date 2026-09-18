# Show available recipes
default:
    @just --list

# Development server, drafts included
dev:
    zola serve --interface 0.0.0.0 --base-url localhost --drafts

# Production build
build:
    zola build

# Validate the build and check that links resolve
check:
    zola check

# Create a new draft post: just post "My title"
post title:
    #!/usr/bin/env bash
    set -euo pipefail
    slug=$(echo "{{title}}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g; s/ \+/-/g; s/^-//; s/-$//')
    file="content/posts/$(date +%F)-${slug}.md"
    [ -e "$file" ] && { echo "exists: $file" >&2; exit 1; }
    cat > "$file" <<TOML
    +++
    title = "{{title}}"
    date = $(date +%F)
    description = ""
    draft = true

    [taxonomies]
    tags = []
    categories = []
    +++
    TOML
    sed -i 's/^    //' "$file"
    echo "created $file"

# Deploy by hand. CI deploys on push to main; this is the break-glass path.
deploy: build
    bunx wrangler deploy

# Remove build output
clean:
    rm -rf public
