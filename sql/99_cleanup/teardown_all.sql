/*******************************************************************************
 * DEMO PROJECT: react-agent-api-upload
 * Script: teardown_all.sql
 *
 * NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 *
 * PURPOSE:
 *   Remove all Snowflake objects provisioned for the React Cortex Agent chat
 *   demo while retaining the SNOWFLAKE_EXAMPLE database per cleanup standards.
 *
 * OBJECTS REMOVED:
 *   Account-Level:
 *   - SFE_REACT_AGENT_WH (warehouse)
 *
 *   Database-Level (in SNOWFLAKE_EXAMPLE):
 *   - REACT_AGENT_RAW (schema + all objects)
 *   - REACT_AGENT_STAGE (schema + all objects)
 *   - REACT_AGENT_ANALYTICS (schema + all objects)
 *   - DoctorChris (agent)
 *
 *   Security Objects:
 *   - SFE_REACT_AGENT_USER (user)
 *   - SFE_REACT_AGENT_ROLE (role)
 *
 * PRESERVED:
 *   - SNOWFLAKE_EXAMPLE database (per cleanup rule)
 *   - SFE_* API integrations (per shared resource rule)
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
ALTER TASK IF EXISTS EXTRACT_DOCUMENT_TEXT_TASK SUSPEND;
DROP TASK IF EXISTS EXTRACT_DOCUMENT_TEXT_TASK;

-- Drop stream
DROP STREAM IF EXISTS NEW_DOCUMENTS_STREAM;

-- Drop Cortex Search service
DROP CORTEX SEARCH SERVICE IF EXISTS DOCUMENT_SEARCH_SERVICE;

-- Drop procedures (agent tools)
DROP PROCEDURE IF EXISTS ANSWER_DOCUMENT_QUESTION(STRING);
DROP PROCEDURE IF EXISTS TRANSLATE_DOCUMENT(STRING, STRING);

-- Drop views
DROP VIEW IF EXISTS AVAILABLE_DOCUMENTS;

-- Drop table
DROP TABLE IF EXISTS DOCUMENT_METADATA;

-- Drop stage
DROP STAGE IF EXISTS DOCUMENTS_STAGE;

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

-- Note: SNOWFLAKE_EXAMPLE database retained per cleanup standards.
-- Note: Leave SFE_* API integrations in place—they are shared across demos.

-- Validation: confirm shared SFE_* integrations still exist (should return rows)
SHOW INTEGRATIONS LIKE 'SFE_%';
