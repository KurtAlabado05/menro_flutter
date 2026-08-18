## Task: Add PLANTNET_API_KEY to Cloudflare Worker env

- [ ] Confirm worker code reads `env.PLANTNET_API_KEY`
- [ ] Update `cloudflare-worker/wrangler.toml` to declare/use `PLANTNET_API_KEY` (prefer via secret)
- [ ] Redeploy worker via `npx wrangler deploy`

