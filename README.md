# Snowflake Cortex Document Intelligence

![Reference Implementation](https://img.shields.io/badge/Reference-Implementation-blue)
![Ready to Run](https://img.shields.io/badge/Ready%20to%20Run-Yes-green)
![Expires](https://img.shields.io/badge/Expires-2025--12--25-orange)
![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

> **DEMONSTRATION PROJECT - EXPIRES: 2025-12-25**  
> This demo uses Snowflake features current as of November 2025.  
> After expiration, this repository will be archived and made private.

**Author:** SE Community  
**Purpose:** Reference implementation for document intelligence with Cortex AI  
**Created:** 2025-11-25 | **Expires:** 2025-12-25 (30 days) | **Status:** ACTIVE

**A unified document intelligence platform powered by Snowflake Cortex AI that enables:**
- Document Upload & Management - Upload PDFs, Word docs, presentations, and more
- Conversational Document Q&A - Ask questions about your uploaded documents
- AI-Powered Summarization - Generate custom summaries with flexible prompts
- Research Mode - Deep analysis for complex document queries
- Translation & Extraction - Translate documents or extract specific information

**Reference Implementation:** This code demonstrates production-grade architectural patterns and best practices. Review and customize security, networking, and business logic for your organization's specific requirements before deployment.

**Database:** All artifacts created in `SNOWFLAKE_EXAMPLE` database  
**Isolation:** Uses `SFE_` prefix for demo objects

---

## Quick Commands (For Demo Control)

Already set up? Use these commands to control the demo:

### macOS/Linux
```bash
./tools/mac/02_start.sh    # Start backend + frontend
./tools/mac/03_status.sh   # Check what's running
./tools/mac/04_stop.sh     # Stop all services
```

### Windows
```cmd
tools\win\02_start.bat    # Start backend + frontend
tools\win\03_status.bat   # Check what's running
tools\win\04_stop.bat     # Stop all services
```

**Access the app:** http://localhost:3002  
**Backend API:** http://localhost:4000

---

## First time here? Follow these steps in order:

1. **Create Snowflake objects** (5 minutes)  
   Open `deploy_all.sql` in Snowsight and click "Run All"

2. **Configure authentication** (2 minutes)  
   ```bash
   # macOS/Linux
   ./tools/mac/01_setup_keypair_auth.sh --account YOUR_ACCOUNT_ID
   
   # Windows
   tools\win\01_setup_keypair_auth.bat --account YOUR_ACCOUNT_ID
   ```
   This automatically creates `.secrets/.env` with all settings!

3. **Run SQL in Snowsight** (1 minute)  
   Copy the `ALTER USER` SQL from step 2 output and run it

4. **Start the application** (1 minute)  
   ```bash
   # macOS/Linux
   ./tools/mac/02_start.sh
   
   # Windows
   tools\win\02_start.bat
   ```
   Then open http://localhost:3002 in your browser

**Total setup time: ~10 minutes**

---

## Overview

This repository delivers a **unified document intelligence platform** built on Snowflake Cortex AI. The application combines document management with conversational AI, allowing users to upload documents and interact with them through natural language queries.

**Key Architecture:**
- **Frontend:** React-based unified interface (document library + chat)
- **Backend:** Node.js Express API with Snowflake integration
- **AI Engine:** Snowflake Cortex Agent API with streaming support
- **Document Processing:** Snowflake's `PARSE_DOCUMENT` and `CORTEX.COMPLETE` functions
- **Security:** Key-pair authentication with JWT tokens

**Documentation:**
- `README.md` (this file) - Quick start guide
- `docs/01-KEYPAIR-AUTH.md` - Secure authentication setup
- `diagrams/` - Architecture diagrams (data flow, network, auth)
- `deploy_all.sql` - Single-execution Snowflake provisioning
- `sql/99_cleanup/01_teardown_all.sql` - Complete cleanup script

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
2. Open `deploy_all.sql` in Snowsight
3. Execute the entire script with "Run All"

This creates:
- `SNOWFLAKE_EXAMPLE` database
- `REACT_AGENT_STAGE` schema
- `SFE_REACT_AGENT_WH` warehouse (AUTO_SUSPEND: 60s for cost optimization)
- `SFE_DOCUMENTS_STAGE` with auto-refreshing directory table
- Stored procedures for document Q&A and translation
- `DoctorChris` Cortex Agent (orchestration model: claude-4-sonnet)
- Service user and role for API access

### Step 3: Configure Key-Pair Authentication

Run the automated setup tool with your Snowflake account identifier:

```bash
# macOS/Linux
./tools/mac/01_setup_keypair_auth.sh --account ORGNAME-ACCOUNTNAME

# Windows
tools\win\01_setup_keypair_auth.bat --account ORGNAME-ACCOUNTNAME
```

This single command will:
1. Generate RSA key pair in `.secrets/keys/`
2. Create `.secrets/.env` with all configuration
3. Update Node.js client code
4. Output SQL to assign the public key

Then copy the `ALTER USER` SQL from the output and run it in Snowsight.

### Step 4: Launch the Application

**macOS / Linux:**
```bash
./tools/mac/02_start.sh
```

**Windows:**
```batch
tools\win\02_start.bat
```

The script will:
- Start the backend server (Express) on port 4000
- Start the frontend server (React) on port 3002
- Display status and access URLs

**Check status:**
```bash
./tools/mac/03_status.sh    # macOS/Linux
tools\win\03_status.bat     # Windows
```

**Stop services:**
```bash
./tools/mac/04_stop.sh      # macOS/Linux
tools\win\04_stop.bat       # Windows
```

To stop the application, press `Ctrl+C` in your terminal.

## Security Considerations

-   The `.secrets/` folder contains your credentials and keys. This folder is excluded from Git via `.git/info/exclude`. **Never commit secrets to version control.**
-   The setup script provisions a dedicated service role/user (`SFE_REACT_AGENT_ROLE` / `SFE_REACT_AGENT_USER`) for API access.
-   **Key-Pair Authentication (Recommended):** Run the automated setup tool:
    ```bash
    # macOS/Linux
    ./tools/mac/01_setup_keypair_auth.sh --account YOUR_ACCOUNT_ID
    
    # Windows
    tools\win\01_setup_keypair_auth.bat --account YOUR_ACCOUNT_ID
    ```
    This will:
    - Generate RSA keys in `.secrets/keys/`
    - Show you the SQL to run in Snowsight
    - Automatically configure `.secrets/.env`
    - Update the Node.js client code

## Complete Cleanup

When you are finished with the demo, remove all Snowflake objects:

1. Open `sql/99_cleanup/01_teardown_all.sql` in Snowsight
2. Execute the entire script

This will remove:
- All schemas and their objects (tables, stages, procedures, agents)
- `SFE_REACT_AGENT_WH` warehouse
- `SFE_REACT_AGENT_USER` and `SFE_REACT_AGENT_ROLE`
- All tasks, streams, and secrets

**Preserved:**
- `SNOWFLAKE_EXAMPLE` database (per cleanup standards)
- Any `SFE_*` API integrations (per shared resource rule)

**Time:** < 1 minute
