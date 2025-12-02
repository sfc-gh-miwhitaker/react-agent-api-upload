/*******************************************************************************
 * DEMO PROJECT: react-agent-api-upload
 * Script: teardown_all.sql
 *
 * ⚠️ NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 *
 * PURPOSE:
 *   Remove all Snowflake objects provisioned for the React Cortex Agent chat
 *   demo while retaining the SNOWFLAKE_EXAMPLE database per cleanup standards.
 *
 * OBJECTS REMOVED:
 *   Account-Level:
 *   - SFE_REACT_AGENT_WH (warehouse)
 *   - SFE_REACT_AGENT_USER (user)
 *   - SFE_REACT_AGENT_ROLE (role)
 *   - SFE_REACT_AGENT_GIT_INTEGRATION (API integration)
 *   - SFE_REACT_AGENT_REPO (Git repository clone)
 *
 *   Database-Level (in SNOWFLAKE_EXAMPLE.REACT_AGENT_STAGE):
 *   - DoctorChris (agent)
 *   - SFE_EXTRACT_TEXT_TASK (task)
 *   - SFE_DOCUMENTS_STREAM (stream)
 *   - DOCUMENT_SEARCH_SERVICE (Cortex Search)
 *   - ANSWER_DOCUMENT_QUESTION (procedure)
 *   - TRANSLATE_DOCUMENT (procedure)
 *   - SFE_PROCESS_DOCUMENTS (procedure)
 *   - SFE_AVAILABLE_DOCUMENTS (view)
 *   - SFE_DOCUMENT_METADATA (table)
 *   - SFE_DOCUMENTS_STAGE (stage)
 *   - REACT_AGENT_STAGE (schema)
 *
 * PRESERVED:
 *   - SNOWFLAKE_EXAMPLE database (per cleanup rule)
 *   - SNOWFLAKE_EXAMPLE.TOOLS schema (shared infrastructure)
 ******************************************************************************/

-- =============================================================================
-- STEP 1: Remove database objects (requires ACCOUNTADMIN/SYSADMIN)
-- =============================================================================
USE ROLE ACCOUNTADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA REACT_AGENT_STAGE;

-- Drop the Cortex Agent first
DROP AGENT IF EXISTS DoctorChris;

-- Drop automated processing objects (must be done before schema drop)
-- Suspend and drop task
ALTER TASK IF EXISTS SFE_EXTRACT_TEXT_TASK SUSPEND;
DROP TASK IF EXISTS SFE_EXTRACT_TEXT_TASK;

-- Drop stream
DROP STREAM IF EXISTS SFE_DOCUMENTS_STREAM;

-- Drop Cortex Search service
DROP CORTEX SEARCH SERVICE IF EXISTS DOCUMENT_SEARCH_SERVICE;

-- Drop procedures (agent tools)
DROP PROCEDURE IF EXISTS ANSWER_DOCUMENT_QUESTION(STRING);
DROP PROCEDURE IF EXISTS TRANSLATE_DOCUMENT(STRING, STRING);
DROP PROCEDURE IF EXISTS SFE_PROCESS_DOCUMENTS();

-- Drop views
DROP VIEW IF EXISTS SFE_AVAILABLE_DOCUMENTS;

-- Drop table
DROP TABLE IF EXISTS SFE_DOCUMENT_METADATA;

-- Drop stage
DROP STAGE IF EXISTS SFE_DOCUMENTS_STAGE;

-- Now drop schemas (should be empty now)
DROP SCHEMA IF EXISTS REACT_AGENT_ANALYTICS CASCADE;
DROP SCHEMA IF EXISTS REACT_AGENT_STAGE CASCADE;
DROP SCHEMA IF EXISTS REACT_AGENT_RAW CASCADE;

-- Drop dedicated warehouse
DROP WAREHOUSE IF EXISTS SFE_REACT_AGENT_WH;

-- =============================================================================
-- STEP 2: Remove security objects (requires ACCOUNTADMIN)
-- =============================================================================
-- Note: Using ACCOUNTADMIN (not SECURITYADMIN) for broader compatibility
USE ROLE ACCOUNTADMIN;

-- Drop service user and role
DROP USER IF EXISTS SFE_REACT_AGENT_USER;
DROP ROLE IF EXISTS SFE_REACT_AGENT_ROLE;

-- =============================================================================
-- STEP 3: Remove Git integration objects (requires ACCOUNTADMIN)
-- =============================================================================
-- Drop Git repository clone first (depends on integration)
DROP GIT REPOSITORY IF EXISTS SNOWFLAKE_EXAMPLE.TOOLS.SFE_REACT_AGENT_REPO;

-- Drop project-specific API integration
DROP INTEGRATION IF EXISTS SFE_REACT_AGENT_GIT_INTEGRATION;

-- Note: SNOWFLAKE_EXAMPLE database retained per cleanup standards.
-- Note: SNOWFLAKE_EXAMPLE.TOOLS schema retained for shared infrastructure.

-- Validation: confirm cleanup complete
SELECT 'Cleanup complete' AS status;
