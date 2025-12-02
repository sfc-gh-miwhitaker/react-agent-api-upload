/*******************************************************************************
 * DEMO PROJECT: react-agent-api-upload
 * Script: deploy_all.sql
 *
 * ⚠️ NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 *
 * PURPOSE:
 *   Single-execution deployment script for the React Cortex Agent document
 *   intelligence demo. Copy this entire script into Snowsight and click 
 *   "Run All" to provision all required objects.
 *
 * EXPIRES: 2025-12-25 (30 days from creation)
 * Author: SE Community
 *
 * HOW TO USE:
 *   1. Open Snowsight and connect to your Snowflake account
 *   2. Ensure you have ACCOUNTADMIN role (or SYSADMIN + security privileges)
 *   3. Copy this ENTIRE script into a new worksheet
 *   4. Click "Run All" - no manual intervention required
 *   5. Follow the NEXT STEPS section at the end for key-pair setup
 *
 * OBJECTS CREATED:
 *   See sql/setup_snowflake.sql for full object list
 *
 * CLEANUP:
 *   Run sql/99_cleanup/teardown_all.sql to remove all objects
 ******************************************************************************/

-- =============================================================================
-- DEPLOY: Include setup script
-- =============================================================================
-- NOTE: This is a wrapper that references the main setup script.
-- For the complete, self-contained version, use sql/setup_snowflake.sql directly.

-- The following is the complete setup script inlined for single-execution:

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
-- To use after expiration:
--   1. Fork the repository
--   2. Update expiration_date in this file
--   3. Review/update for latest Snowflake syntax and features

-- =============================================================================
-- DEPLOY: Begin Infrastructure Setup
-- =============================================================================

USE ROLE SYSADMIN;

-- =============================================================================
-- Step 1: Compute & Database
-- =============================================================================

CREATE WAREHOUSE IF NOT EXISTS SFE_REACT_AGENT_WH
  WITH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'DEMO: react-agent-api-upload - Dedicated warehouse for agent and backend (Expires: 2025-12-25)';

USE WAREHOUSE SFE_REACT_AGENT_WH;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
  COMMENT = 'DEMO: Repository for example/demo projects - NOT FOR PRODUCTION';

USE DATABASE SNOWFLAKE_EXAMPLE;

CREATE SCHEMA IF NOT EXISTS REACT_AGENT_STAGE
  COMMENT = 'DEMO: react-agent-api-upload - Document processing and agent tools (Expires: 2025-12-25)';

USE SCHEMA REACT_AGENT_STAGE;

-- =============================================================================
-- Step 2: Document Storage with Auto-Refresh Directory Table
-- =============================================================================

CREATE OR REPLACE STAGE SFE_DOCUMENTS_STAGE
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
  DIRECTORY = (ENABLE = TRUE)
  COMMENT = 'DEMO: react-agent-api-upload - Document storage with directory table (Expires: 2025-12-25)';

-- =============================================================================
-- Step 3: Document Metadata Table
-- =============================================================================

CREATE OR REPLACE TABLE SFE_DOCUMENT_METADATA (
    FILE_PATH STRING PRIMARY KEY,
    FILE_NAME STRING,
    FILE_SIZE INTEGER,
    LAST_MODIFIED TIMESTAMP_NTZ,
    EXTRACTED_TEXT STRING,
    EXTRACTED_JSON VARIANT,
    PAGE_COUNT INTEGER,
    EXTRACTION_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PROCESSING_TIME_MS INTEGER
)
COMMENT = 'DEMO: react-agent-api-upload - Document metadata with Cortex text extraction (Expires: 2025-12-25)';

-- =============================================================================
-- Step 4: Stream for Event-Driven Processing
-- =============================================================================

CREATE OR REPLACE STREAM SFE_DOCUMENTS_STREAM 
ON STAGE SFE_DOCUMENTS_STAGE
COMMENT = 'DEMO: react-agent-api-upload - Tracks new file uploads for auto-processing (Expires: 2025-12-25)';

-- =============================================================================
-- Step 5: Document Processing Procedure + Task
-- =============================================================================

CREATE OR REPLACE PROCEDURE SFE_PROCESS_DOCUMENTS()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
  rows_upserted INTEGER DEFAULT 0;
BEGIN
  MERGE INTO SFE_DOCUMENT_METADATA AS target
  USING (
    WITH pending AS (
      SELECT
        RELATIVE_PATH,
        SUBSTR(RELATIVE_PATH, REGEXP_INSTR(RELATIVE_PATH, '[^/]+$')) AS FILE_NAME,
        SIZE,
        CAST(LAST_MODIFIED AS TIMESTAMP_NTZ) AS LAST_MODIFIED,
        AI_PARSE_DOCUMENT(
          '@SFE_DOCUMENTS_STAGE',
          RELATIVE_PATH,
          {'mode': 'LAYOUT'}
        ) AS parsed
      FROM SFE_DOCUMENTS_STREAM
WHERE METADATA$ACTION = 'INSERT'
  AND METADATA$ISUPDATE = FALSE
    )
    SELECT
      RELATIVE_PATH,
      FILE_NAME,
      SIZE,
      LAST_MODIFIED,
      parsed:content::STRING AS EXTRACTED_TEXT,
      parsed:metadata:pageCount::INT AS PAGE_COUNT
    FROM pending
  ) AS source
  ON target.FILE_PATH = source.RELATIVE_PATH
WHEN MATCHED THEN
  UPDATE SET
    FILE_NAME = source.FILE_NAME,
    FILE_SIZE = source.SIZE,
    LAST_MODIFIED = source.LAST_MODIFIED,
    EXTRACTED_TEXT = source.EXTRACTED_TEXT,
    PAGE_COUNT = COALESCE(source.PAGE_COUNT, target.PAGE_COUNT),
    EXTRACTION_TIMESTAMP = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
  INSERT (FILE_PATH, FILE_NAME, FILE_SIZE, LAST_MODIFIED, EXTRACTED_TEXT, PAGE_COUNT, EXTRACTION_TIMESTAMP)
  VALUES (source.RELATIVE_PATH, source.FILE_NAME, source.SIZE, source.LAST_MODIFIED, source.EXTRACTED_TEXT, source.PAGE_COUNT, CURRENT_TIMESTAMP());

  rows_upserted := SQLROWCOUNT;
  RETURN 'Processed ' || rows_upserted || ' document(s)';
END;
$$;

CREATE OR REPLACE TASK SFE_EXTRACT_TEXT_TASK
  WAREHOUSE = SFE_REACT_AGENT_WH
  SCHEDULE = '1 MINUTE'
WHEN
  SYSTEM$STREAM_HAS_DATA('SFE_DOCUMENTS_STREAM')
AS
  CALL SFE_PROCESS_DOCUMENTS();

ALTER TASK SFE_EXTRACT_TEXT_TASK RESUME;

CALL SFE_PROCESS_DOCUMENTS();

-- =============================================================================
-- Step 6: Cortex Search Service
-- =============================================================================

CREATE OR REPLACE CORTEX SEARCH SERVICE DOCUMENT_SEARCH_SERVICE
ON EXTRACTED_TEXT
ATTRIBUTES FILE_NAME, FILE_PATH, LAST_MODIFIED, PAGE_COUNT
WAREHOUSE = SFE_REACT_AGENT_WH
TARGET_LAG = '1 minute'
COMMENT = 'DEMO: react-agent-api-upload - Hybrid vector/keyword semantic search (Expires: 2025-12-25)'
AS (
  SELECT FILE_PATH, FILE_NAME, EXTRACTED_TEXT, LAST_MODIFIED, PAGE_COUNT
  FROM SFE_DOCUMENT_METADATA
  WHERE EXTRACTED_TEXT IS NOT NULL
);

-- =============================================================================
-- Step 7: Agent Tools
-- =============================================================================

CREATE OR REPLACE VIEW SFE_AVAILABLE_DOCUMENTS AS
SELECT FILE_PATH, FILE_NAME, PAGE_COUNT, LAST_MODIFIED, EXTRACTION_TIMESTAMP, LENGTH(EXTRACTED_TEXT) AS text_length_chars
FROM SFE_DOCUMENT_METADATA
ORDER BY LAST_MODIFIED DESC;

CREATE OR REPLACE PROCEDURE ANSWER_DOCUMENT_QUESTION(question STRING)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
  doc_context STRING;
  answer STRING;
  doc_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO doc_count FROM SFE_DOCUMENT_METADATA;
  
  IF (doc_count = 0) THEN
    RETURN '{"error": "No documents have been uploaded yet. Please upload a PDF document first."}';
  END IF;
  
  doc_context := (
    SELECT LISTAGG('FILE: ' || FILE_NAME || '\n' || 'CONTENT: ' || SUBSTR(EXTRACTED_TEXT, 1, 2000), '\n\n---\n\n') WITHIN GROUP (ORDER BY LAST_MODIFIED DESC)
    FROM SFE_DOCUMENT_METADATA WHERE EXTRACTED_TEXT IS NOT NULL LIMIT 5
  );
  
  IF (doc_context IS NULL OR doc_context = '') THEN
    RETURN '{"error": "Documents are still being processed. Please wait ~1 minute and try again."}';
  END IF;
  
  answer := (
    SELECT AI_COMPLETE('mistral-large2',
      'You are an expert analyst. Answer the following question based on the provided document excerpts.

QUESTION: ' || :question || '

AVAILABLE DOCUMENTS:
' || doc_context || '

Provide a structured JSON response with these keys:
1. "summary": A concise, one-paragraph answer to the question.
2. "key_points": A JSON array of 3-5 supporting bullet points from the documents.
3. "confidence_score": A float between 0.0 and 1.0 indicating confidence in the answer.

JSON RESPONSE:')
  );
  
  RETURN answer;
END;
$$;

CREATE OR REPLACE PROCEDURE TRANSLATE_DOCUMENT(file_path STRING, target_language STRING)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
  doc_text STRING;
  translated_text STRING;
BEGIN
  doc_text := (SELECT EXTRACTED_TEXT FROM SFE_DOCUMENT_METADATA WHERE FILE_PATH = :file_path);
  
  IF (doc_text IS NULL) THEN
    RETURN '{"error": "Document not found or not yet processed."}';
  END IF;
  
  translated_text := (SELECT AI_TRANSLATE(:doc_text, '', :target_language));
  
  RETURN translated_text;
END;
$$;

-- =============================================================================
-- Step 8: Cortex Agent (DoctorChris)
-- =============================================================================

CREATE OR REPLACE AGENT DoctorChris
  COMMENT = 'DEMO: react-agent-api-upload - Cortex agent powered by native document intelligence (Expires: 2025-12-25)'
  FROM SPECIFICATION
  $$
  models:
    orchestration: claude-4-sonnet

  orchestration:
    budget:
      seconds: 45
      tokens: 16000

  instructions:
    system: |
      You are Dr. Chris, an empathetic documentation specialist who helps users understand staged documents.
      You use Snowflake's native document intelligence (CORTEX.PARSE_DOCUMENT) for fast, accurate responses.
      Always ground your answers in the tool outputs - never fabricate information.
      
    orchestration: |
      When a user asks about document contents:
      1. Call document_qa_tool with the question
      2. The tool automatically searches relevant docs and returns structured JSON
      3. Base your response on the JSON payload (summary, key_points, confidence_score)
      
      When a user asks for translation:
      1. Call document_translation_tool with the file path and language code
      2. Return the translated text with proper attribution
      
    response: |
      Start with a friendly greeting, then:
      - Summarize key findings in plain language
      - List important bullet points from key_points
      - Reference the confidence score to set expectations
      - Close with actionable guidance or follow-up questions
      
    sample_questions:
      - question: "What are the main findings in the uploaded report?"
        answer: "I'll search the documents and summarize the key findings."

  tools:
    - tool_spec:
        type: generic
        name: document_qa_tool
        description: Answers questions about documents in the stage.
        input_schema:
          type: object
          properties:
            question:
              type: string
              description: The user's question about document contents
          required:
            - question

    - tool_spec:
        type: generic
        name: document_translation_tool
        description: Translates a specific document to the requested language.
        input_schema:
          type: object
          properties:
            file_path:
              type: string
              description: The relative path to the file in SFE_DOCUMENTS_STAGE
            target_language:
              type: string
              description: ISO 639-1 language code (e.g., 'es', 'fr', 'de')
          required:
            - file_path
            - target_language
  
  tool_resources:
    document_qa_tool:
      type: procedure
      identifier: SNOWFLAKE_EXAMPLE.REACT_AGENT_STAGE.ANSWER_DOCUMENT_QUESTION
      execution_environment:
        type: warehouse
        warehouse: SFE_REACT_AGENT_WH
        query_timeout: 60
    document_translation_tool:
      type: procedure
      identifier: SNOWFLAKE_EXAMPLE.REACT_AGENT_STAGE.TRANSLATE_DOCUMENT
      execution_environment:
        type: warehouse
        warehouse: SFE_REACT_AGENT_WH
        query_timeout: 60
  $$;

-- =============================================================================
-- Step 9: Security - Roles and Users
-- =============================================================================

USE ROLE ACCOUNTADMIN;

CREATE ROLE IF NOT EXISTS SFE_REACT_AGENT_ROLE
  COMMENT = 'DEMO: react-agent-api-upload - Service role for backend API (Expires: 2025-12-25)';

GRANT USAGE ON WAREHOUSE SFE_REACT_AGENT_WH TO ROLE SFE_REACT_AGENT_ROLE;
GRANT OPERATE ON WAREHOUSE SFE_REACT_AGENT_WH TO ROLE SFE_REACT_AGENT_ROLE;
GRANT EXECUTE TASK ON ACCOUNT TO ROLE SFE_REACT_AGENT_ROLE;
GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO ROLE SFE_REACT_AGENT_ROLE;
GRANT USAGE ON SCHEMA SNOWFLAKE_EXAMPLE.REACT_AGENT_STAGE TO ROLE SFE_REACT_AGENT_ROLE;
GRANT READ, WRITE ON STAGE SNOWFLAKE_EXAMPLE.REACT_AGENT_STAGE.SFE_DOCUMENTS_STAGE TO ROLE SFE_REACT_AGENT_ROLE;
GRANT SELECT ON TABLE SNOWFLAKE_EXAMPLE.REACT_AGENT_STAGE.SFE_DOCUMENT_METADATA TO ROLE SFE_REACT_AGENT_ROLE;
GRANT SELECT ON VIEW SNOWFLAKE_EXAMPLE.REACT_AGENT_STAGE.SFE_AVAILABLE_DOCUMENTS TO ROLE SFE_REACT_AGENT_ROLE;
GRANT USAGE ON PROCEDURE SNOWFLAKE_EXAMPLE.REACT_AGENT_STAGE.ANSWER_DOCUMENT_QUESTION(STRING) TO ROLE SFE_REACT_AGENT_ROLE;
GRANT USAGE ON PROCEDURE SNOWFLAKE_EXAMPLE.REACT_AGENT_STAGE.TRANSLATE_DOCUMENT(STRING, STRING) TO ROLE SFE_REACT_AGENT_ROLE;
GRANT USAGE ON PROCEDURE SNOWFLAKE_EXAMPLE.REACT_AGENT_STAGE.SFE_PROCESS_DOCUMENTS() TO ROLE SFE_REACT_AGENT_ROLE;
GRANT USAGE ON CORTEX SEARCH SERVICE SNOWFLAKE_EXAMPLE.REACT_AGENT_STAGE.DOCUMENT_SEARCH_SERVICE TO ROLE SFE_REACT_AGENT_ROLE;
GRANT USAGE ON AGENT DoctorChris TO ROLE SFE_REACT_AGENT_ROLE;
GRANT MONITOR ON AGENT DoctorChris TO ROLE SFE_REACT_AGENT_ROLE;

CREATE USER IF NOT EXISTS SFE_REACT_AGENT_USER
  DEFAULT_ROLE = SFE_REACT_AGENT_ROLE
  DEFAULT_WAREHOUSE = SFE_REACT_AGENT_WH
  DEFAULT_NAMESPACE = SNOWFLAKE_EXAMPLE.REACT_AGENT_STAGE
  MUST_CHANGE_PASSWORD = FALSE
  DISABLED = FALSE
  DISPLAY_NAME = 'React Agent Service User'
  COMMENT = 'DEMO: react-agent-api-upload - Service principal for key-pair authentication (Expires: 2025-12-25)';

GRANT ROLE SFE_REACT_AGENT_ROLE TO USER SFE_REACT_AGENT_USER;

-- =============================================================================
-- SETUP COMPLETE!
-- =============================================================================
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
-- =============================================================================

