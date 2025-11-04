# Development - watch for changes
dev:
    zola serve --interface 0.0.0.0 --base-url localhost

# Production build
build:
    zola build

# Deploy to Cloudflare Pages
deploy: build
    wrangler deploy

# Create a new blog post
post:
    ./scripts/new-post.sh

# Clean build directory
clean:
    rm -rf public