# Pocket ID

Pocket ID is a simple and easy-to-use OIDC (OpenID Connect) provider that enables passwordless authentication using passkeys (WebAuthn) for your self-hosted services.

## Features

- **Passwordless Authentication**: Uses passkeys (WebAuthn) for secure, password-free login
- **OIDC Provider**: Standard OpenID Connect support for integration with various applications
- **LDAP Support**: User and group synchronization via LDAP
- **Multiple Passkeys**: Support for multiple passkeys per user account
- **User & Group Management**: Create and manage users and groups for granular access control
- **Privacy-Focused**: Self-hosted solution with no external dependencies

## Quick Start

### 1. Prerequisites

- Docker and Docker Compose installed on 192.168.68.91
- Traefik reverse proxy configured and running on the `proxy` network
- Domain configured in DNS (e.g., `pocket-id.slavik.tech`)
- HTTPS is **required** (Pocket ID uses WebAuthn which requires secure context)

### 2. Configuration

1. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```

2. Generate an encryption key:
   ```bash
   openssl rand -base64 32
   ```

3. Edit `.env` and configure:
   - `APP_URL`: Set to your public HTTPS URL (e.g., `https://pocket-id.slavik.tech`)
   - `ENCRYPTION_KEY`: Paste the generated key from step 2
   - `POCKET_ID_DOMAIN`: Update if using a different domain
   - Other optional settings as needed

   **IMPORTANT**: Keep your `ENCRYPTION_KEY` secure and backed up! Losing it means losing access to all encrypted data.

### 3. Deploy

Deploy the service using Docker Compose:

```bash
docker compose up -d
```

Or use the rebuild script for a fresh deployment:

```bash
docker compose down && docker image prune -a -f && docker compose build && docker compose up -d
```

### 4. Initial Setup

1. Access the setup page at: `https://pocket-id.slavik.tech/setup`
2. Create your admin account using a passkey
3. Configure your passkey using:
   - System password manager (Windows Hello, macOS Touch ID, etc.)
   - Hardware security key (YubiKey, etc.)
   - Password manager (1Password, Bitwarden, etc.)

**Note**: After initial setup, the `/setup` endpoint becomes inaccessible. Only users with valid passkeys can log in.

### 5. Add Backup Passkeys (Recommended)

1. Log in to Pocket ID
2. Go to Settings → Account
3. Click "Add Passkey"
4. Register at least one backup passkey to avoid lockouts

## Integration with Services

### Creating OIDC Clients

1. Log in to Pocket ID
2. Navigate to the "OIDC Clients" tab
3. Click "Add OIDC Client"
4. Configure:
   - **Name**: Your application name
   - **Callback URLs**: Your app's OAuth callback URL(s)
   - **Logo**: Optional logo for the client
5. Save and note the **Client ID** and **Client Secret**

### Example OIDC Configuration

For services that support OIDC, use these endpoints:

```
Issuer URL: https://pocket-id.slavik.tech
Authorization URL: https://pocket-id.slavik.tech/authorize
Token URL: https://pocket-id.slavik.tech/api/oidc/token
UserInfo URL: https://pocket-id.slavik.tech/api/oidc/userinfo
Scopes: openid email profile groups
```

### Using with OAuth2-Proxy

To protect services that don't have native OIDC support, use OAuth2-Proxy:

1. Deploy OAuth2-Proxy with your application
2. Configure it to use Pocket ID as the OIDC provider
3. Point traffic through OAuth2-Proxy before reaching your application

## Access Control

### User Groups

1. Navigate to "User Groups" tab
2. Create groups for different access levels (e.g., `admins`, `users`, `readonly`)
3. Assign users to groups
4. Configure OIDC clients to require specific groups

### Group-Based Access

In your OIDC client configuration, you can restrict access to specific groups:
- Users not in the required group will be redirected to an unauthorized page
- Use the `groups` scope to receive group membership in the OIDC token

## Maintenance

### Update Service

```bash
docker compose pull
docker compose up -d
```

### View Logs

```bash
docker compose logs -f pocket-id
```

### Backup

Important files to backup:
- `.env` file (contains encryption key)
- `/mnt/nas/DockerServices/pocket-id/data/` (contains database and configuration)

### Rotate Encryption Key

If you need to rotate the encryption key:

```bash
# Generate new key
NEW_KEY=$(openssl rand -base64 32)

# Rotate using the built-in command
docker compose exec pocket-id ./pocket-id encryption-key-rotate --new-key "$NEW_KEY"

# Update .env file with new key
# Restart the service
docker compose restart
```

## Troubleshooting

### Passkey Not Working

- Ensure you're accessing via HTTPS (passkeys require secure context)
- Check browser compatibility (modern browsers required)
- Verify your passkey device is working
- Try a different passkey method (e.g., hardware key vs. password manager)

### Can't Access After Initial Setup

- Ensure your passkey is properly registered
- Try alternative passkey if configured
- Check browser console for errors
- For account recovery, see [documentation](https://pocket-id.org/docs/troubleshooting/account-recovery)

### Service Not Accessible

- Check Traefik logs for routing issues
- Verify DNS is pointing to the correct IP
- Ensure the `proxy` network exists
- Check SSL certificate status in Traefik

## Resources

- **Official Documentation**: https://pocket-id.org/docs
- **GitHub Repository**: https://github.com/pocket-id/pocket-id
- **Docker Image**: ghcr.io/pocket-id/pocket-id
- **Discord Community**: https://pocket-id.org/community/discord

## Security Notes

- **HTTPS Required**: Pocket ID will not work over HTTP due to WebAuthn requirements
- **Encryption Key**: Store securely and never commit to version control
- **Rate Limiting**: Built-in rate limiting enabled by default (can be disabled if using Traefik's rate limiting)
- **Trust Proxy**: Enabled to work correctly behind Traefik reverse proxy
- **Backup Passkeys**: Always configure multiple passkeys to avoid lockouts

## Architecture

Pocket ID runs as a single container service:
- **Port**: 1411 (internal)
- **Network**: Connected to `proxy` network for Traefik integration
- **Storage**: Persistent data in `/mnt/nas/DockerServices/pocket-id/data`
- **Database**: SQLite by default (PostgreSQL optional)
- **Auto-updates**: Enabled via Watchtower with `admin` scope
