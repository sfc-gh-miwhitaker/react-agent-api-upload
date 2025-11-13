# Key-Pair Authentication Setup

⚠️ **This guide has been superseded by an automated workflow.**

## Quick Setup (Recommended)

Run the automated setup tool:

**macOS / Linux:**
```bash
./tools/01_setup_keypair_auth.sh --account YOUR_ACCOUNT_ID
```

**Windows:**
```cmd
tools\01_setup_keypair_auth.bat --account YOUR_ACCOUNT_ID
```

The tool will:
1. ✅ Generate RSA keys (or use existing)
2. ✅ Extract public key in Snowflake format
3. ✅ Output SQL to assign key to user
4. ✅ Automatically update Node.js client code
5. ✅ Provide .env configuration guidance

**Total time:** ~2 minutes

---

## What It Does

The automated tool replaces these manual steps:

### 1. Generate Keys
Creates a 2048-bit RSA key pair in `config/keys/`:
- `rsa_key.p8` - Private key (PKCS#8 format, unencrypted)
- `rsa_key.pub` - Public key (PEM format)

### 2. Output SQL
Provides the exact SQL command to run in Snowsight:

```sql
USE ROLE SECURITYADMIN;
ALTER USER SFE_REACT_AGENT_USER
  SET RSA_PUBLIC_KEY = '<base64-encoded-key>';
```

### 3. Update Application Code
Automatically updates `server/src/snowflakeClient.js` to support both authentication methods:
- Password authentication (default, backward compatible)
- Key-pair authentication (when `SNOWFLAKE_AUTH_TYPE=keypair`)

### 4. Configure Environment
Shows you exactly what to add to your `.env` file:

```bash
SNOWFLAKE_AUTH_TYPE=keypair
SNOWFLAKE_PRIVATE_KEY_PATH=/path/to/config/keys/rsa_key.p8
SNOWFLAKE_USER=SFE_REACT_AGENT_USER
# SNOWFLAKE_PASSWORD not needed when using keypair
```

---

## Verification

After running the SQL in Snowsight, verify the key assignment:

```sql
DESC USER SFE_REACT_AGENT_USER;
```

Look for:
- `RSA_PUBLIC_KEY_FP` - Should show `SHA256:...` fingerprint
- `RSA_PUBLIC_KEY_LAST_SET_TIME` - Should show recent timestamp

---

## Testing Connection

### With Snow CLI
```bash
snow connection test \
  --account YOUR_ACCOUNT_ID \
  --user SFE_REACT_AGENT_USER \
  --private-key-path config/keys/rsa_key.p8
```

### With Application
1. Update `.env` with settings from tool output
2. Start server: `./tools/02_start.sh` (or `.bat` on Windows)
3. Check status: `./tools/03_status.sh` (or `.bat` on Windows)
4. Verify connection in console logs

---

## Security Notes

- 🔒 Keys saved to `config/keys/` (in `.gitignore`)
- 🔒 Private key generated without passphrase for ease of automation
- 🔒 Service user has minimal privileges (follows least privilege principle)
- ⚠️ For production: Use external secret management (AWS KMS, Azure Key Vault, etc.)

---

## Troubleshooting

### Error: "JWT token is invalid"
**Cause:** Public key not assigned in Snowflake  
**Fix:** Run the SQL command output by the tool

### Error: "Private key not found"
**Cause:** Keys not generated yet  
**Fix:** Run `./tools/01_setup_keypair_auth.sh` first

### Error: "Missing environment variable: SNOWFLAKE_PRIVATE_KEY_PATH"
**Cause:** .env not configured for key-pair auth  
**Fix:** Add `SNOWFLAKE_AUTH_TYPE=keypair` and `SNOWFLAKE_PRIVATE_KEY_PATH` to `.env`

### Want to switch back to password auth?
Simply remove or comment out `SNOWFLAKE_AUTH_TYPE` in your `.env` file. The code defaults to password authentication.

---

## Advanced: Manual Setup (Not Recommended)

If you need to manually generate keys (e.g., with encryption, custom paths):

### Generate Private Key
```bash
openssl genrsa 2048 | openssl pkcs8 -topk8 -v2 aes256 -out config/keys/custom_key.p8
```

### Extract Public Key
```bash
openssl rsa -pubin -in config/keys/custom_key.p8 -outform DER \
  | openssl base64 -A > config/keys/custom_key.pub.b64
```

### Assign to User
```sql
ALTER USER SFE_REACT_AGENT_USER
  SET RSA_PUBLIC_KEY = '<contents of custom_key.pub.b64>';
```

### Update .env
```bash
SNOWFLAKE_AUTH_TYPE=keypair
SNOWFLAKE_PRIVATE_KEY_PATH=/path/to/config/keys/custom_key.p8
```

---

## Related Documentation

- **Previous guide:** `README.md` - Main project setup
- **Architecture:** `diagrams/auth-flow.md` - Authentication flow diagram
- **Cleanup:** `sql/99_cleanup/teardown_all.sql` - Remove all demo objects
