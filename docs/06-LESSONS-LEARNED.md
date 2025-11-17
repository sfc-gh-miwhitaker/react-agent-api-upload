# Lessons Learned - Snowflake Document Intelligence Setup

**Last Updated:** 2024-11-14  
**Status:** Reference Implementation

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

## Overview

This document captures key learnings from implementing and debugging the Snowflake Cortex Document Intelligence application. These lessons are incorporated into `setup_snowflake.sql` and should help avoid common pitfalls.

---

## Critical Issues & Solutions

### 1. Role Grant Missing (CRITICAL)

**Issue:**  
Backend fails with: `JWT token is invalid` or `Role 'SFE_REACT_AGENT_ROLE' is not granted to this user`

**Root Cause:**  
The `GRANT ROLE SFE_REACT_AGENT_ROLE TO USER SFE_REACT_AGENT_USER;` statement must run as `ACCOUNTADMIN`, not `SECURITYADMIN`. Many users don't have `SECURITYADMIN` access.

**Solution:**
```sql
USE ROLE ACCOUNTADMIN;  -- Not SECURITYADMIN!
GRANT ROLE SFE_REACT_AGENT_ROLE TO USER SFE_REACT_AGENT_USER;
```

**Prevention:**
- Always use `ACCOUNTADMIN` for security setup in demo projects
- Add verification step immediately after setup to catch this early
- Document explicitly in NEXT STEPS section

---

### 2. RSA Public Key Not Registered (CRITICAL)

**Issue:**  
Backend fails with: `JWT token is invalid` immediately after successful Snowflake connection

**Root Cause:**  
The setup script creates the user with `RSA_PUBLIC_KEY = 'PLACEHOLDER'`, but the actual public key must be manually registered.

**Solution:**
```bash
# Get the public key (without headers)
sed -e '/-----BEGIN/d' -e '/-----END/d' config/keys/rsa_key.pub | tr -d '\n'
```

```sql
USE ROLE ACCOUNTADMIN;
ALTER USER SFE_REACT_AGENT_USER SET RSA_PUBLIC_KEY='<paste_key_here>';

-- Verify
DESC USER SFE_REACT_AGENT_USER;
-- Check that RSA_PUBLIC_KEY_FP shows a fingerprint value
```

**Prevention:**
- Highlight this as **CRITICAL** in setup documentation
- Add verification check for `RSA_PUBLIC_KEY_FP` in verify script
- Consider automating this in setup script (requires external tool execution)

---

### 3. Picking the Right PARSE_DOCUMENT Variant

**Issue:**  
Code referenced multiple versions of the document parsing function inconsistently.

**Root Cause:**  
Snowflake has two flavours: the original `SNOWFLAKE.CORTEX.PARSE_DOCUMENT` and the newer `AI_PARSE_DOCUMENT`. Our account only exposes the Cortex version, so attempts to call the newer function failed with “expected 2 arguments, got 3”.

**Solution:**
```sql
-- ✅ Compatible across accounts
SNOWFLAKE.CORTEX.PARSE_DOCUMENT('@stage', 'file.pdf', {'mode': 'LAYOUT'}):content::STRING
```

**Prevention:**
- Standardise on `SNOWFLAKE.CORTEX.PARSE_DOCUMENT` unless you’ve confirmed `AI_PARSE_DOCUMENT` is available.
- Wrap the logic so you can fall back gracefully if only one variant exists.
- Update comments and docs to note which variant the project uses.

---

### 4. SQL Task Syntax Error (ON CONFLICT not supported)

**Issue:**  
Task creation fails with: `syntax error line 41 at position 2 unexpected 'ON'`

**Root Cause:**  
Snowflake tasks don't support `INSERT ... ON CONFLICT`. Must use `MERGE` statement instead.

**Solution:**
```sql
-- ❌ WRONG (doesn't work in tasks)
INSERT INTO DOCUMENT_METADATA (...)
SELECT ... FROM NEW_DOCUMENTS_STREAM
ON CONFLICT (FILE_PATH) DO NOTHING;

-- ✅ CORRECT (Snowflake way)
MERGE INTO DOCUMENT_METADATA AS target
USING (
  SELECT ...
  FROM NEW_DOCUMENTS_STREAM
  WHERE METADATA$ACTION = 'INSERT'
) AS source
ON target.FILE_PATH = source.RELATIVE_PATH
WHEN NOT MATCHED THEN
  INSERT (...) VALUES (...);
```

**Prevention:**
- Always use `MERGE` for upsert operations in tasks
- Test task creation separately before integrating into larger scripts
- Document this Snowflake-specific behavior

---

### 5. Missing Node.js Exports

**Issue:**  
Backend fails to start: `does not provide an export named 'parseDocumentFromStage'`

**Root Cause:**  
Functions added to `snowflakeClient.js` but forgot to add `export` keyword

**Solution:**
```javascript
// ❌ WRONG
async function parseDocumentFromStage(stagePath) { ... }

// ✅ CORRECT
export async function parseDocumentFromStage(stagePath) { ... }
```

**Prevention:**
- Always add `export` when creating utility functions that will be imported
- Use linter rules to catch missing exports
- Test imports immediately after adding new functions

---

### 6. Directory Table Not Automatically Refreshed

**Issue:**  
`DIRECTORY(@stage)` returns 0 files even though files exist in stage

**Root Cause:**  
For internal stages, directory table needs manual refresh after first file upload

**Solution:**
```sql
-- Refresh directory table manually
ALTER STAGE DOCUMENTS_STAGE REFRESH;

-- Verify
SELECT COUNT(*) FROM DIRECTORY(@DOCUMENTS_STAGE);
```

**Auto-Refresh (for external stages only):**
```sql
CREATE STAGE my_stage
  URL = 's3://bucket/path'
  DIRECTORY = (
    ENABLE = TRUE,
    AUTO_REFRESH = TRUE  -- Only works for external stages
  );
```

**Prevention:**
- Document that internal stages require manual refresh
- Task will handle auto-processing after first manual refresh
- Add verification step to check directory table population

---

## Architecture Decisions

### Event-Driven Processing Pattern

**Choice:** Directory Tables + Streams + Tasks  
**Why:** Fully serverless, auto-scaling, native Snowflake CDC pattern

```
Upload → Stage → Directory Table → Stream → Task (1 min) → Metadata Table → Agent
```

**Benefits:**
- Zero maintenance - no polling or cron jobs
- Automatic failover and retry
- Scales to millions of documents
- Audit trail built-in (stream captures all changes)

**Tradeoffs:**
- 1-minute delay for processing (task schedule)
- More complex debugging than synchronous processing
- Stream and task management adds operational overhead

---

### Using ACCOUNTADMIN for Setup

**Choice:** All setup commands use `ACCOUNTADMIN` role  
**Why:** Broadest compatibility - most demo users have ACCOUNTADMIN, fewer have SECURITYADMIN

**Tradeoffs:**
- Less secure (ACCOUNTADMIN has full privileges)
- Not recommended for production
- Good for demos where simplicity > security

**Production Recommendation:**
Use principle of least privilege:
```sql
-- Grant only what's needed
GRANT CREATE ROLE ON ACCOUNT TO ROLE SETUP_ROLE;
GRANT CREATE USER ON ACCOUNT TO ROLE SETUP_ROLE;
GRANT USAGE ON WAREHOUSE ... TO ROLE SETUP_ROLE;
```

---

### Key-Pair Authentication

**Choice:** RSA key-pair authentication (not password)  
**Why:** More secure, tokens expire automatically, no password in code

**Implementation:**
1. Generate RSA key pair (2048-bit minimum)
2. Store private key securely (`config/keys/` - gitignored)
3. Register public key with Snowflake user
4. Backend generates JWT tokens on-demand

**Security Benefits:**
- Tokens auto-expire (55 min default, 60 min max)
- No credential rotation needed
- Works with CI/CD pipelines
- Follows Snowflake best practices

---

## Verification Best Practices

### Always Include Verification Steps

**What We Learned:**  
Silent failures are hard to debug. Setup scripts should verify every critical component immediately after creation.

**Verification Checklist:**
```sql
-- ✅ Verify role grant
SHOW GRANTS TO USER SFE_REACT_AGENT_USER;

-- ✅ Verify task state
SHOW TASKS LIKE 'EXTRACT_DOCUMENT_TEXT_TASK';

-- ✅ Verify directory table enabled
DESC STAGE DOCUMENTS_STAGE;

-- ✅ Verify public key registered
DESC USER SFE_REACT_AGENT_USER;
-- Check RSA_PUBLIC_KEY_FP column

-- ✅ Test directory table access
SELECT COUNT(*) FROM DIRECTORY(@DOCUMENTS_STAGE);
```

### Standalone Verification Script

**Created:** `sql/verify_setup.sql`  
**Purpose:** Independent diagnostic tool to check setup without re-running full setup

**When to Use:**
- After initial setup to verify correctness
- When debugging backend connection issues
- After making manual changes to Snowflake objects
- Before opening support tickets (include verification output)

---

## Troubleshooting Workflow

### 1. Check Backend Logs First
```bash
tail -50 .pids/backend.log
```

**Common Patterns:**
- `JWT token is invalid` → Public key or role grant issue
- `does not provide an export` → Missing `export` keyword in Node.js
- `Role 'X' is not granted` → Missing role grant

### 2. Run Verification Script
```sql
-- In Snowsight
USE ROLE ACCOUNTADMIN;
-- Run sql/verify_setup.sql
```

### 3. Check Snowflake Object State
```sql
-- Task suspended?
SHOW TASKS;

-- Stream has data?
SELECT SYSTEM$STREAM_HAS_DATA('NEW_DOCUMENTS_STREAM');

-- Files in stage?
SELECT COUNT(*) FROM DIRECTORY(@DOCUMENTS_STAGE);
```

### 4. Test Components Individually
```sql
-- Test SNOWFLAKE.CORTEX.PARSE_DOCUMENT directly
SELECT SNOWFLAKE.CORTEX.PARSE_DOCUMENT('@DOCUMENTS_STAGE', 'test.pdf', {'mode': 'LAYOUT'}):content::STRING;

-- Test agent tool directly
CALL ANSWER_DOCUMENT_QUESTION('How many documents do I have?');
```

---

## Documentation Updates Made

### Files Updated

1. **`sql/setup_snowflake.sql`**
   - Changed `SECURITYADMIN` → `ACCOUNTADMIN`
   - Added critical comment about role grant
   - Added comprehensive verification section
   - Standardised on `SNOWFLAKE.CORTEX.PARSE_DOCUMENT`
   - Fixed task to use `MERGE` instead of `INSERT ... ON CONFLICT`
   - Added troubleshooting guide

2. **`sql/99_cleanup/teardown_all.sql`**
   - Changed to use `ACCOUNTADMIN` consistently
   - Added explanatory comments

3. **`server/src/snowflakeClient.js`**
   - Added missing `export` keywords
   - Standardised on `SNOWFLAKE.CORTEX.PARSE_DOCUMENT`
   - Added `listFilesFromStage()` function
   - Added `parseDocumentFromStage()` function with proper export

4. **`sql/verify_setup.sql`** (NEW)
   - Standalone verification script
   - Checks all 12 critical components
   - Provides actionable error messages

5. **`docs/06-LESSONS-LEARNED.md`** (THIS FILE)
   - Comprehensive documentation of all learnings
   - Troubleshooting workflow
   - Architecture decisions and tradeoffs

---

## Future Improvements

### Short Term
- [ ] Automate public key registration in setup script
- [ ] Add health check endpoint that verifies Snowflake connectivity
- [ ] Create diagnostic CLI command (`./tools/diagnose.sh`)
- [ ] Add retry logic for task execution failures

### Medium Term
- [ ] Support for external stages (S3, Azure, GCS) with auto-refresh
- [ ] Parallel processing (multiple tasks for faster ingestion)
- [ ] Document classification using Cortex AI
- [ ] Enhanced error reporting in UI

### Long Term
- [ ] Production-grade secret management (Vault, AWS Secrets Manager)
- [ ] Multi-tenant support (different roles per customer)
- [ ] Advanced RAG with Cortex Search integration
- [ ] Document versioning and change tracking

---

## References

- [Snowflake PARSE_DOCUMENT Documentation](https://docs.snowflake.com/en/sql-reference/functions/parse_document)
- [Directory Tables](https://docs.snowflake.com/en/user-guide/data-load-dirtables)
- [Streams and Tasks](https://docs.snowflake.com/en/user-guide/streams-intro)
- [Key-Pair Authentication](https://docs.snowflake.com/en/user-guide/key-pair-auth)
- [Cortex Agent API](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agent)

---

## Change History

See `.cursor/DIAGRAM_CHANGELOG.md` for version history.

