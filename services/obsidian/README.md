## References

## Note Organize 
- Link: https://github.com/different-ai/note-companion/tree/master

1. Clone: `git clone https://github.com/different-ai/note-companion.git note_companion`
2. Install Requirements: Node, pnpm
3. Fill in env file `.env`
4. Add env File: `cp .env note_companion/packages/web/.env.local`
5. A - Install: `cd note_companion/packages/web && pnpm build:self-host && pnpm start`
5. B - Install via docker: `docker compose down && docker image prune -a -f && docker compose build && docker compose up -d`

