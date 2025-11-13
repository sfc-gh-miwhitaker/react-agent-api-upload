# Configuration Directory

This directory contains configuration files for the Snowflake Cortex Agent Chat Application.

## Structure

```
config/
├── .gitkeep          # Keeps directory in git
├── README.md         # This file
└── keys/             # RSA key-pair storage (GITIGNORED)
    ├── sfe_react_agent_key.p8      # Private key (NEVER COMMIT)
    └── sfe_react_agent_key.pub.b64 # Public key Base64 (NEVER COMMIT)
```

## Security Notes

⚠️ **CRITICAL SECURITY REQUIREMENTS:**

1. **Never commit private keys** - The `keys/` directory is gitignored
2. **Never commit `.env` files** - Store secrets in environment variables
3. **Use key-pair authentication** - Preferred over password auth for production

## Key Generation

Follow the instructions in `docs/03-KEYPAIR-AUTH.md` to generate RSA key pairs for secure authentication.

## Files That May Exist Here

- `agent.yaml` - Exported agent specification (can be committed if no secrets)
- `.env.example` - Template for environment variables (can be committed)
- `.env` - Actual secrets (NEVER commit - already gitignored)
