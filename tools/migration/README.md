# README — `migrate_one_stack.sh`

This script migrates **one Docker Compose stack at a time** from a NAS-backed appdata path (e.g. `/mnt/nas/DockerServices/...`) to **local appdata** inside an LXC (default: `/srv/appdata/...`), and rewrites the compose file so it uses the new local path.

It’s designed for “I have 20 stacks and I want control” mode: run it stack-by-stack, test, then continue.

---

## What it does

Given a stack directory (a folder containing `compose.yaml` / `docker-compose.yaml` etc.):

1. **Finds** host bind-mounts in the compose that start with:

   * `${DOCKER_VOLUME_STORAGE}/...`

2. **Copies** the referenced folders/files from the old root (NAS) to the new root (local):

   * `<old_root>/<relative_path>` → `<new_root>/<relative_path>`

3. **Backs up** the compose file, then **rewrites** it:

   * `${DOCKER_VOLUME_STORAGE}` → `/srv/appdata` (or your `--new-root`)

4. Optionally **restarts** the stack:

   * `docker compose down && docker compose up -d`

---


## Requirements

### Inside the LXC

* `rsync` (**recommended**)
  Install it:

```bash
apt update && apt install -y rsync
```

---

## Folder expectations

Your **stack directory** must contain:

* one of:

  * `compose.yml`
  * `compose.yaml`
  * `docker-compose.yml`
  * `docker-compose.yaml`
* optional:

  * `.env` (if present and includes `DOCKER_VOLUME_STORAGE`, the script will use it)

Example:

```
/srv/compose/forgejo/
  compose.yaml
  .env                  # optional
```

---

## Old-root resolution rules

The script needs to know where the NAS appdata lives (`old root`).

It decides like this:

1. If `<stack_dir>/.env` exists and contains:

   * `DOCKER_VOLUME_STORAGE=/mnt/nas/DockerServices`
     then it uses that.

2. Otherwise, you must pass:

   * `--old-root /mnt/nas/DockerServices`

If neither exists, the script exits with an error (by design).

---

## Usage

### Dry run (recommended first)

Shows what it would copy and what it would rewrite, but changes nothing.

```bash
./migrate_one_stack.sh --stack /path/to/stack --dry
```

If the stack has **no `.env`**, specify `--old-root`:

```bash
./migrate_one_stack.sh --stack /path/to/stack --old-root /mnt/nas/DockerServices --dry
```

### Real migration (copy + rewrite)

```bash
./migrate_one_stack.sh --stack /path/to/stack --new-root /srv/appdata
```

### Real migration + restart the stack

```bash
./migrate_one_stack.sh --stack /path/to/stack --new-root /srv/appdata --restart
```

### Minimal “no .env” example

```bash
./migrate_one_stack.sh \
  --stack /srv/compose/forgejo \
  --old-root /mnt/nas/DockerServices \
  --new-root /srv/appdata \
  --restart
```

---

## What gets copied (mapping logic)

For each volume bind in compose like:

```yaml
- ${DOCKER_VOLUME_STORAGE}/forgejo/server:/data
```

If old root is `/mnt/nas/DockerServices` and new root is `/srv/appdata`, the script copies:

* **from**

  * `/mnt/nas/DockerServices/forgejo/server`
* **to**

  * `/srv/appdata/forgejo/server`

Then it rewrites the compose bind to:

```yaml
- /srv/appdata/forgejo/server:/data
```

---

## Backups and safety

* Before rewriting compose, the script creates a timestamped backup next to the file:

  * `compose.yaml.bak.YYYY-MM-DD_HHMMSS`

So rollback is as simple as:

```bash
cp compose.yaml.bak.<timestamp> compose.yaml
docker compose up -d
```

---

## Suggested workflow per stack

1. **Dry run**

   ```bash
   ./migrate_one_stack.sh --stack /path/to/stack --old-root /mnt/nas/DockerServices --dry
   ```

2. **Stop stack manually** (optional but recommended for DB consistency)

   ```bash
   cd /path/to/stack
   docker compose down
   ```

3. **Run migration**

   ```bash
   ./migrate_one_stack.sh --stack /path/to/stack --old-root /mnt/nas/DockerServices --new-root /srv/appdata
   ```

4. **Start stack**

   ```bash
   cd /path/to/stack
   docker compose up -d
   ```

5. **Verify service works**

   * logs, UI, DB present, etc.

6. Only after verification: consider archiving old NAS folders.

---

## Common gotchas

### Permissions / ownership

Data copied from NAS may preserve numeric IDs, but the service may still fail if ownership is wrong.
Typical fix:

```bash
chown -R 1000:1000 /srv/appdata/<stack>
```

DB images may use different UIDs (e.g., Postgres often uses 999).

---

## Flags reference

* `--stack <dir>`: path to folder containing compose file (required)
* `--new-root <dir>`: destination root (default `/srv/appdata`)
* `--old-root <dir>`: source root if `.env` lacks `DOCKER_VOLUME_STORAGE`
* `--dry`: print actions only
* `--restart`: restart stack after migration

---

If you want, I can also add:

* `--rollback` (restore most recent `.bak.*`)
* `--match-literal` (also migrate hardcoded `/mnt/nas/DockerServices` even when the compose doesn’t use `${DOCKER_VOLUME_STORAGE}`)
