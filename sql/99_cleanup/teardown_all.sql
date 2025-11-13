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
-- STEP 1: Remove database objects (requires SYSADMIN)
-- =============================================================================
USE ROLE SYSADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;

-- Drop the Cortex Agent
DROP AGENT IF EXISTS DoctorChris;

-- Drop schemas with CASCADE to remove all contained objects
-- (includes tasks, streams, stages, secrets, file formats, procedures)
DROP SCHEMA IF EXISTS REACT_AGENT_ANALYTICS CASCADE;
DROP SCHEMA IF EXISTS REACT_AGENT_STAGE CASCADE;
DROP SCHEMA IF EXISTS REACT_AGENT_RAW CASCADE;

-- Drop dedicated warehouse
DROP WAREHOUSE IF EXISTS SFE_REACT_AGENT_WH;

-- =============================================================================
-- STEP 2: Remove security objects (requires SECURITYADMIN)
-- =============================================================================
USE ROLE SECURITYADMIN;

-- Drop service user and role
DROP USER IF EXISTS SFE_REACT_AGENT_USER;
DROP ROLE IF EXISTS SFE_REACT_AGENT_ROLE;

-- Note: SNOWFLAKE_EXAMPLE database retained per cleanup standards.
-- Note: SFE_* API integrations retained per shared resource rule.
