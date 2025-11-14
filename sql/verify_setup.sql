/*******************************************************************************
 * SETUP VERIFICATION SCRIPT
 * 
 * Run this script to verify that all Snowflake objects are correctly configured.
 * This helps diagnose common setup issues before attempting to start the application.
 * 
 * Usage: Run this entire script in Snowsight as ACCOUNTADMIN
 ******************************************************************************/

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE SFE_REACT_AGENT_WH;
USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA REACT_AGENT_STAGE;

SELECT '═══════════════════════════════════════════════════════════' AS divider;
SELECT '🔍 SNOWFLAKE SETUP VERIFICATION' AS title;
SELECT '═══════════════════════════════════════════════════════════' AS divider;

-- =============================================================================
-- Check 1: Warehouse
-- =============================================================================
SELECT '' AS spacer;
SELECT '1️⃣  Checking Warehouse...' AS test;
SHOW WAREHOUSES LIKE 'SFE_REACT_AGENT_WH';
SELECT CASE 
  WHEN COUNT(*) = 1 THEN '✅ PASS: Warehouse exists'
  ELSE '❌ FAIL: Warehouse not found'
END AS result
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- =============================================================================
-- Check 2: Database and Schema
-- =============================================================================
SELECT '' AS spacer;
SELECT '2️⃣  Checking Database and Schema...' AS test;
SHOW DATABASES LIKE 'SNOWFLAKE_EXAMPLE';
SELECT CASE 
  WHEN COUNT(*) = 1 THEN '✅ PASS: Database exists'
  ELSE '❌ FAIL: Database not found'
END AS result
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

SHOW SCHEMAS LIKE 'REACT_AGENT_STAGE' IN DATABASE SNOWFLAKE_EXAMPLE;
SELECT CASE 
  WHEN COUNT(*) = 1 THEN '✅ PASS: Schema exists'
  ELSE '❌ FAIL: Schema not found'
END AS result
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- =============================================================================
-- Check 3: Stage with Directory Table
-- =============================================================================
SELECT '' AS spacer;
SELECT '3️⃣  Checking Stage...' AS test;
SHOW STAGES LIKE 'DOCUMENTS_STAGE';
SELECT CASE 
  WHEN COUNT(*) = 1 THEN '✅ PASS: Stage exists'
  ELSE '❌ FAIL: Stage not found'
END AS result
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- Check directory table is enabled
DESC STAGE DOCUMENTS_STAGE;
SELECT CASE 
  WHEN (SELECT "property_value" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())) WHERE "property" = 'DIRECTORY_ENABLED') = 'true' 
  THEN '✅ PASS: Directory table is enabled'
  ELSE '❌ FAIL: Directory table is NOT enabled (required for auto-processing)'
END AS result;

-- Check encryption
SELECT CASE 
  WHEN (SELECT "property_value" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID(-1))) WHERE "property" = 'ENCRYPTION_TYPE') = 'SNOWFLAKE_SSE' 
  THEN '✅ PASS: Stage has server-side encryption (required for AI_PARSE_DOCUMENT)'
  ELSE '❌ FAIL: Stage missing SNOWFLAKE_SSE encryption'
END AS result;

-- =============================================================================
-- Check 4: Stream
-- =============================================================================
SELECT '' AS spacer;
SELECT '4️⃣  Checking Stream...' AS test;
SHOW STREAMS LIKE 'NEW_DOCUMENTS_STREAM';
SELECT CASE 
  WHEN COUNT(*) = 1 THEN '✅ PASS: Stream exists'
  ELSE '❌ FAIL: Stream not found'
END AS result
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- =============================================================================
-- Check 5: Task
-- =============================================================================
SELECT '' AS spacer;
SELECT '5️⃣  Checking Task...' AS test;
SHOW TASKS LIKE 'EXTRACT_DOCUMENT_TEXT_TASK';
SELECT CASE 
  WHEN COUNT(*) = 1 THEN '✅ PASS: Task exists'
  ELSE '❌ FAIL: Task not found'
END AS result
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- Check task state
SELECT CASE 
  WHEN (SELECT "state" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID(-1))) WHERE "name" = 'EXTRACT_DOCUMENT_TEXT_TASK') = 'started' 
  THEN '✅ PASS: Task is STARTED (will process new files)'
  ELSE '⚠️  WARNING: Task is SUSPENDED (run: ALTER TASK EXTRACT_DOCUMENT_TEXT_TASK RESUME;)'
END AS result;

-- =============================================================================
-- Check 6: Document Metadata Table
-- =============================================================================
SELECT '' AS spacer;
SELECT '6️⃣  Checking Document Metadata Table...' AS test;
SHOW TABLES LIKE 'DOCUMENT_METADATA';
SELECT CASE 
  WHEN COUNT(*) = 1 THEN '✅ PASS: Table exists'
  ELSE '❌ FAIL: Table not found'
END AS result
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- =============================================================================
-- Check 7: Agent
-- =============================================================================
SELECT '' AS spacer;
SELECT '7️⃣  Checking Cortex Agent...' AS test;
SHOW AGENTS LIKE 'DoctorChris';
SELECT CASE 
  WHEN COUNT(*) = 1 THEN '✅ PASS: Agent exists'
  ELSE '❌ FAIL: Agent not found'
END AS result
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- =============================================================================
-- Check 8: Procedures (Agent Tools)
-- =============================================================================
SELECT '' AS spacer;
SELECT '8️⃣  Checking Agent Tool Procedures...' AS test;
SHOW PROCEDURES LIKE 'ANSWER_DOCUMENT_QUESTION';
SELECT CASE 
  WHEN COUNT(*) >= 1 THEN '✅ PASS: ANSWER_DOCUMENT_QUESTION exists'
  ELSE '❌ FAIL: ANSWER_DOCUMENT_QUESTION not found'
END AS result
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

SHOW PROCEDURES LIKE 'TRANSLATE_DOCUMENT';
SELECT CASE 
  WHEN COUNT(*) >= 1 THEN '✅ PASS: TRANSLATE_DOCUMENT exists'
  ELSE '❌ FAIL: TRANSLATE_DOCUMENT not found'
END AS result
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- =============================================================================
-- Check 9: Role
-- =============================================================================
SELECT '' AS spacer;
SELECT '9️⃣  Checking Service Role...' AS test;
SHOW ROLES LIKE 'SFE_REACT_AGENT_ROLE';
SELECT CASE 
  WHEN COUNT(*) = 1 THEN '✅ PASS: Role exists'
  ELSE '❌ FAIL: Role not found'
END AS result
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- =============================================================================
-- Check 10: User (CRITICAL)
-- =============================================================================
SELECT '' AS spacer;
SELECT '🔟 Checking Service User (CRITICAL)...' AS test;
SHOW USERS LIKE 'SFE_REACT_AGENT_USER';
SELECT CASE 
  WHEN COUNT(*) = 1 THEN '✅ PASS: User exists'
  ELSE '❌ FAIL: User not found'
END AS result
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- Check if role is granted to user
SHOW GRANTS TO USER SFE_REACT_AGENT_USER;
SELECT CASE 
  WHEN COUNT(*) >= 1 THEN '✅ PASS: Role is granted to user'
  ELSE '❌ FAIL: Role NOT granted to user (CRITICAL - backend will fail!)'
END AS result
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- Check if public key is registered
DESC USER SFE_REACT_AGENT_USER;
SELECT CASE 
  WHEN (SELECT "value" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())) WHERE "property" = 'RSA_PUBLIC_KEY_FP') IS NOT NULL 
  THEN '✅ PASS: RSA public key is registered'
  ELSE '❌ FAIL: RSA public key NOT registered (CRITICAL - JWT auth will fail!)'
END AS result;

-- =============================================================================
-- Check 11: Role Grants
-- =============================================================================
SELECT '' AS spacer;
SELECT '1️⃣1️⃣  Checking Role Permissions...' AS test;
SHOW GRANTS TO ROLE SFE_REACT_AGENT_ROLE;
SELECT COUNT(*) AS grant_count, 
  CASE 
    WHEN COUNT(*) >= 8 THEN '✅ PASS: Role has multiple grants'
    ELSE '⚠️  WARNING: Role may be missing some grants (expected 8+)'
  END AS result
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- =============================================================================
-- Check 12: Test Directory Table Query
-- =============================================================================
SELECT '' AS spacer;
SELECT '1️⃣2️⃣  Testing Directory Table Access...' AS test;
SELECT COUNT(*) AS file_count FROM DIRECTORY(@DOCUMENTS_STAGE);
SELECT '✅ PASS: Directory table is queryable' AS result;
SELECT '   Current file count: ' || (SELECT COUNT(*) FROM DIRECTORY(@DOCUMENTS_STAGE)) AS info;

-- =============================================================================
-- SUMMARY
-- =============================================================================
SELECT '' AS spacer;
SELECT '═══════════════════════════════════════════════════════════' AS divider;
SELECT '📊 VERIFICATION SUMMARY' AS title;
SELECT '═══════════════════════════════════════════════════════════' AS divider;
SELECT '' AS spacer;
SELECT 'Review the results above. All checks should show ✅ PASS.' AS guidance;
SELECT '' AS spacer;
SELECT 'Common Issues:' AS guidance;
SELECT '  ❌ "Role NOT granted to user" → Run: GRANT ROLE SFE_REACT_AGENT_ROLE TO USER SFE_REACT_AGENT_USER;' AS guidance;
SELECT '  ❌ "RSA public key NOT registered" → Follow NEXT STEPS in setup_snowflake.sql' AS guidance;
SELECT '  ⚠️  "Task is SUSPENDED" → Run: ALTER TASK EXTRACT_DOCUMENT_TEXT_TASK RESUME;' AS guidance;
SELECT '' AS spacer;
SELECT 'If all checks pass, you are ready to start the application!' AS guidance;
SELECT '  Run: ./tools/02_start.sh (macOS/Linux) or tools\\02_start.bat (Windows)' AS guidance;
SELECT '' AS spacer;
SELECT '═══════════════════════════════════════════════════════════' AS divider;

