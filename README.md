# blog

[joshbowen.net](https://joshbowen.net) — a [Zola](https://www.getzola.org/) site
deployed to Cloudflare Workers static assets.

## Local development

Requires [Zola](https://www.getzola.org/documentation/getting-started/installation/)
(0.22+) and [just](https://github.com/casey/just). `bun` is only needed to deploy
by hand.

```sh
just            # list recipes
just dev        # serve at localhost:1111, drafts included
just post "A title for the post"
just build      # production build into public/
just check      # validate links
```

New posts are created with `draft = true`. Flip it to `false` to publish.

## Deployment

Pushing to `main` builds the site and deploys it via
`.github/workflows/deploy.yml`. The workflow also runs on pull requests and via
`workflow_dispatch`, building without deploying so the pipeline can be exercised
before it publishes.

Deploys need two repository secrets, `CLOUDFLARE_API_TOKEN` and
`CLOUDFLARE_ACCOUNT_ID`. `just deploy` runs the same `wrangler deploy` locally as
a break-glass path.

The workflow pins an exact Zola version and verifies its SHA256 before use;
`zola build` output differs between releases, so bump the version and the hash
together.
