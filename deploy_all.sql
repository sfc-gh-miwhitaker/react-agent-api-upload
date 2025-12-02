/*******************************************************************************
 * DEMO PROJECT: react-agent-api-upload
 * Script: deploy_all.sql
 *
 * ⚠️ NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 *
 * PURPOSE:
 *   Single-execution deployment script for the React Cortex Agent document
 *   intelligence demo. Uses EXECUTE IMMEDIATE FROM to run SQL files directly
 *   from the Git repository - no code duplication.
 *
 * EXPIRES: 2025-12-25 (30 days from creation)
 * Author: SE Community
 *
 * HOW TO USE:
 *   1. Open Snowsight and connect to your Snowflake account
 *   2. Ensure you have ACCOUNTADMIN role
 *   3. Copy this ENTIRE script into a new worksheet
 *   4. Click "Run All" - no manual intervention required
 *   5. Follow the NEXT STEPS section at the end for key-pair setup
 *
 * ARCHITECTURE:
 *   This script creates a Git repository clone, then uses EXECUTE IMMEDIATE FROM
 *   to run the actual SQL files. This ensures:
 *   - Single source of truth (no code duplication)
 *   - Easier maintenance
 *   - Git-versioned deployments
 *
 * CLEANUP:
 *   Run: EXECUTE IMMEDIATE FROM @SFE_REACT_AGENT_REPO/branches/main/sql/99_cleanup/01_teardown_all.sql;
 ******************************************************************************/

-- =============================================================================
-- EXPIRATION CHECK (MANDATORY)
-- =============================================================================
-- This demo expires 30 days after creation.
-- If expired, deployment should be halted and the repository forked with updated dates.

SELECT 
    '2025-12-25'::DATE AS expiration_date,
    CURRENT_DATE() AS current_date,
    DATEDIFF('day', CURRENT_DATE(), '2025-12-25'::DATE) AS days_remaining,
    CASE 
        WHEN DATEDIFF('day', CURRENT_DATE(), '2025-12-25'::DATE) < 0 
        THEN '🚫 EXPIRED - Do not deploy. Fork repository and update expiration date.'
        WHEN DATEDIFF('day', CURRENT_DATE(), '2025-12-25'::DATE) <= 7
        THEN '⚠️  EXPIRING SOON - ' || DATEDIFF('day', CURRENT_DATE(), '2025-12-25'::DATE) || ' days remaining'
        ELSE '✅ ACTIVE - ' || DATEDIFF('day', CURRENT_DATE(), '2025-12-25'::DATE) || ' days remaining'
    END AS demo_status;

-- ⚠️  MANUAL CHECK REQUIRED:
-- If the demo_status shows "EXPIRED", STOP HERE and do not proceed with deployment.
-- This demo uses Snowflake features current as of November 2025.

-- =============================================================================
-- STEP 1: Prerequisites - Database and Schema for Git Repository
-- =============================================================================

USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
  COMMENT = 'DEMO: Repository for example/demo projects - NOT FOR PRODUCTION';

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.TOOLS
  COMMENT = 'DEMO: Shared infrastructure for demo projects (Git repos, integrations)';

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA TOOLS;

-- =============================================================================
-- STEP 2: Git API Integration (Project-Specific)
-- =============================================================================
-- Creates an API integration specifically for this repository.
-- Using CREATE OR REPLACE ensures the integration has the correct prefixes.

CREATE OR REPLACE API INTEGRATION SFE_REACT_AGENT_GIT_INTEGRATION
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/miwhitaker/react-agent-api-upload')
  ENABLED = TRUE
  COMMENT = 'DEMO: react-agent-api-upload - Git API integration (Expires: 2025-12-25)';

-- =============================================================================
-- STEP 3: Git Repository Clone for this Project
-- =============================================================================
-- Creates a clone of this repository that Snowflake can read from.
-- Public repositories don't require GIT_CREDENTIALS.

CREATE OR REPLACE GIT REPOSITORY SFE_REACT_AGENT_REPO
  API_INTEGRATION = SFE_REACT_AGENT_GIT_INTEGRATION
  ORIGIN = 'https://github.com/miwhitaker/react-agent-api-upload.git'
  COMMENT = 'DEMO: react-agent-api-upload - Git repository for EXECUTE IMMEDIATE FROM (Expires: 2025-12-25)';

-- Fetch the latest from the repository
ALTER GIT REPOSITORY SFE_REACT_AGENT_REPO FETCH;

-- =============================================================================
-- STEP 4: Execute Setup Script from Git Repository
-- =============================================================================
-- This is the key step - instead of duplicating code, we execute directly from Git.
-- The setup script creates all infrastructure, tables, procedures, agent, and security.

EXECUTE IMMEDIATE FROM @SFE_REACT_AGENT_REPO/branches/main/sql/01_setup/01_setup_snowflake.sql;

-- =============================================================================
-- SETUP COMPLETE!
-- =============================================================================
--
-- WHAT WAS CREATED:
--   The setup script (sql/01_setup/01_setup_snowflake.sql) created:
--   - SFE_REACT_AGENT_WH (warehouse)
--   - SNOWFLAKE_EXAMPLE.REACT_AGENT_STAGE (schema)
--   - SFE_DOCUMENTS_STAGE (stage with directory table)
--   - SFE_DOCUMENT_METADATA (table)
--   - SFE_DOCUMENTS_STREAM (stream)
--   - SFE_EXTRACT_TEXT_TASK (task)
--   - SFE_PROCESS_DOCUMENTS (procedure)
--   - SFE_AVAILABLE_DOCUMENTS (view)
--   - DOCUMENT_SEARCH_SERVICE (Cortex Search)
--   - ANSWER_DOCUMENT_QUESTION (procedure)
--   - TRANSLATE_DOCUMENT (procedure)
--   - DoctorChris (Cortex Agent)
--   - SFE_REACT_AGENT_ROLE (role)
--   - SFE_REACT_AGENT_USER (user)
--
-- NEXT STEPS:
--
-- 1. Run the key-pair setup script:
--    macOS/Linux: ./tools/mac/01_setup_keypair_auth.sh --account YOUR_ACCOUNT_ID
--    Windows:     tools\win\01_setup_keypair_auth.bat --account YOUR_ACCOUNT_ID
--
-- 2. Copy the ALTER USER SQL from the script output and run it here
--
-- 3. Start the application:
--    macOS/Linux: ./tools/mac/02_start.sh
--    Windows:     tools\win\02_start.bat
--
-- 4. Open http://localhost:3002 in your browser
--
-- CLEANUP:
--   Run: EXECUTE IMMEDIATE FROM @SFE_REACT_AGENT_REPO/branches/main/sql/99_cleanup/01_teardown_all.sql;
--
-- VERIFY SETUP:
--   Run: EXECUTE IMMEDIATE FROM @SFE_REACT_AGENT_REPO/branches/main/sql/02_verify/01_verify_setup.sql;
--
-- =============================================================================
