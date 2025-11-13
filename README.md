# Snowflake Cortex Agent Chat Application

⚠️ **DEMO PROJECT - NOT FOR PRODUCTION USE**

This is a reference implementation for educational purposes only.

**Database:** All artifacts created in `SNOWFLAKE_EXAMPLE` database  
**Isolation:** Uses `SFE_` prefix for account-level objects

---

## 🚀 Quick Commands (For Demo Control)

Already set up? Use these commands to control the demo:

### macOS/Linux
```bash
./tools/02_start.sh    # Start backend + frontend
./tools/03_status.sh   # Check what's running
./tools/04_stop.sh     # Stop all services
```

### Windows
```cmd
tools\02_start.bat    # Start backend + frontend
tools\03_status.bat   # Check what's running
tools\04_stop.bat     # Stop all services
```

**Access the app:** http://localhost:3002  
**Backend API:** http://localhost:4000

---

## 👋 First time here? Follow these steps in order:

1. **Create Snowflake objects** (5 minutes)  
   Open `sql/setup_snowflake.sql` in Snowsight and run the entire script

2. **Configure authentication** (2 minutes)  
   ```bash
   # macOS/Linux
   ./tools/01_setup_keypair_auth.sh --account YOUR_ACCOUNT_ID
   
   # Windows
   tools\01_setup_keypair_auth.bat --account YOUR_ACCOUNT_ID
   ```
   This automatically creates `config/.env` with all settings!

3. **Run SQL in Snowsight** (1 minute)  
   Copy the `ALTER USER` SQL from step 2 output and run it

4. **Start the application** (1 minute)  
   ```bash
   # macOS/Linux
   ./tools/02_start.sh
   
   # Windows
   tools\02_start.bat
   ```
   Then open http://localhost:3002 in your browser

**Total setup time: ~10 minutes** (5 minutes faster!)

---

## Overview

This repository delivers a React-based chat interface for interacting with Snowflake Cortex Agents over the documented REST API. The application focuses on a secure configuration experience, streaming message delivery, and operational tooling that aligns with Snowflake demo governance standards.

**📚 Documentation:**
- `README.md` (this file) - Quick start guide
- `docs/01-KEYPAIR-AUTH.md` - Secure authentication setup
- `diagrams/` - Architecture diagrams (data flow, network, auth)
- `sql/setup_snowflake.sql` - Complete Snowflake provisioning
- `sql/99_cleanup/teardown_all.sql` - Complete cleanup script

## Prerequisites

-   Node.js 18+ and npm
-   Snowflake account with access to a Cortex Agent
-   A Snowflake user and role with permissions to execute the setup SQL.

## Detailed Installation Steps

### Step 1: Install Dependencies

Install Node.js dependencies for both frontend and backend:

```bash
# Install all dependencies
npm install
cd server && npm install && cd ..
```

### Step 2: Provision Snowflake Objects

All required Snowflake objects are defined in a single SQL script.

1. Connect to your Snowflake account with a user that has `SYSADMIN` privileges (and `ACCOUNTADMIN` if creating a new warehouse)
2. Open `sql/setup_snowflake.sql` in Snowsight
3. Execute the entire script

This creates:
- `SNOWFLAKE_EXAMPLE` database
- Three schemas: `REACT_AGENT_RAW`, `REACT_AGENT_STAGE`, `REACT_AGENT_ANALYTICS`
- `SFE_REACT_AGENT_WH` warehouse (AUTO_SUSPEND: 60s for cost optimization)
- `DOCUMENTS_STAGE` with auto-refreshing directory table
- Two Python stored procedures (runtime: Python 3.11) for document Q&A and translation
- `DoctorChris` Cortex Agent (orchestration model: claude-4-sonnet)
- Service user and role for API access

### Step 3: Configure Key-Pair Authentication

Run the automated setup tool with your Snowflake account identifier:

```bash
# macOS/Linux
./tools/01_setup_keypair_auth.sh --account ORGNAME-ACCOUNTNAME

# Windows
tools\01_setup_keypair_auth.bat --account ORGNAME-ACCOUNTNAME
```

This single command will:
1. ✅ Generate RSA key pair in `config/keys/`
2. ✅ Create `config/.env` with all configuration
3. ✅ Update Node.js client code
4. ✅ Output SQL to assign the public key

Then copy the `ALTER USER` SQL from the output and run it in Snowsight.

### Step 4: Launch the Application

**macOS / Linux:**
```bash
./tools/02_start.sh
```

**Windows:**
```batch
tools\02_start.bat
```

The script will:
- Start the backend server (Express) on port 4000
- Start the frontend server (React) on port 3002
- Display status and access URLs

**Check status:**
```bash
./tools/03_status.sh    # macOS/Linux
tools\03_status.bat     # Windows
```

**Stop services:**
```bash
./tools/04_stop.sh      # macOS/Linux
tools\04_stop.bat       # Windows
```

To stop the application, press `Ctrl+C` in your terminal.

## Security Considerations

-   The `.env` file contains your secrets and is ignored by Git. **Never commit this file to version control.**
-   The setup script now provisions a dedicated service role/user (`SFE_REACT_AGENT_ROLE` / `SFE_REACT_AGENT_USER`) for exporting agent specifications.
-   **Key-Pair Authentication (Recommended):** Run the automated setup tool:
    ```bash
    # macOS/Linux
    ./tools/01_setup_keypair_auth.sh --account YOUR_ACCOUNT_ID
    
    # Windows
    tools\01_setup_keypair_auth.bat --account YOUR_ACCOUNT_ID
    ```
    This will:
    - Generate RSA keys
    - Show you the SQL to run in Snowsight
    - Automatically update the Node.js client code
    - Guide you through .env configuration
-   The Programmatic Access Token (PAT) used by the backend should be scoped to the narrowest possible role and rotated regularly. Prefer short-lived JWTs signed with the service user's key when integrating with the REST API.

## Complete Cleanup

When you are finished with the demo, remove all Snowflake objects:

1. Open `sql/99_cleanup/teardown_all.sql` in Snowsight
2. Execute the entire script

This will remove:
- ✅ All three schemas and their objects (tables, stages, procedures, agents)
- ✅ `SFE_REACT_AGENT_WH` warehouse
- ✅ `SFE_REACT_AGENT_USER` and `SFE_REACT_AGENT_ROLE`
- ✅ All tasks, streams, and secrets

**Preserved:**
- ✅ `SNOWFLAKE_EXAMPLE` database (per cleanup standards)
- ✅ Any `SFE_*` API integrations (per shared resource rule)

**Time:** < 1 minute