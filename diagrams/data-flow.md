# Data Flow - React Agent API Upload

**Author:** Michael Whitaker  
**Last Updated:** 2025-11-12  
**Status:** ⚠️ **DEMO/NON-PRODUCTION**

---

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

⚠️ **WARNING: This is a demonstration project. NOT FOR PRODUCTION USE.**

---

## Overview

This diagram shows how document data flows through the React Cortex Agent chat application, from user upload through Snowflake storage to AI-powered analysis and response generation.

---

## Diagram

```mermaid
graph TB
    subgraph "User Browser"
        User[End User]
        UI[React Frontend<br/>Port 3000]
    end
    
    subgraph "Local Backend"
        Express[Express Server<br/>Port 3001]
        Multer[Multer File Handler]
        SFClient[Snowflake Client SDK]
    end
    
    subgraph "Snowflake Cloud - SNOWFLAKE_EXAMPLE"
        subgraph "Storage"
            Stage[DOCUMENTS_STAGE<br/>Internal Stage]
        end
        
        subgraph "Processing"
            Agent[DoctorChris<br/>Cortex Agent]
            SP1[EXTRACT_STRUCTURED_INSIGHTS_SP<br/>Python Stored Procedure]
            SP2[TRANSLATE_DOCUMENT_SP<br/>Python Stored Procedure]
        end
        
        subgraph "AI Services"
            Orchestrator[Claude 3.5 Sonnet<br/>Orchestration Model]
            Complete[CORTEX.COMPLETE<br/>snowflake-arctic]
            Translate[CORTEX.TRANSLATE]
        end
        
        subgraph "Compute"
            WH[SFE_REACT_AGENT_WH<br/>XSMALL Warehouse]
        end
    end
    
    User -->|1. Upload PDF| UI
    UI -->|2. POST /upload| Express
    Express -->|3. Parse multipart| Multer
    Multer -->|4. Temp file| Express
    Express -->|5. Connect| SFClient
    SFClient -->|6. PUT file| Stage
    Stage -->|7. Confirmation| SFClient
    SFClient -->|8. Success response| Express
    Express -->|9. {filename}| UI
    UI -->|10. Display confirmation| User
    
    User -->|11. Ask question| UI
    UI -->|12. POST /chat| Express
    Express -->|13. REST API| Agent
    Agent -->|14. Analyze intent| Orchestrator
    Orchestrator -->|15. Call tool| SP1
    SP1 -->|16. Read file| Stage
    SP1 -->|17. Extract text + prompt| Complete
    Complete -->|18. AI insights JSON| SP1
    SP1 -->|19. Return results| Agent
    Agent -->|20. Format response| Orchestrator
    Orchestrator -->|21. SSE stream| Express
    Express -->|22. Stream chunks| UI
    UI -->|23. Display answer| User
    
    SP1 -.->|Runs on| WH
    SP2 -.->|Runs on| WH
    
    style User fill:#e3f2fd
    style Stage fill:#fff3e0
    style Agent fill:#f3e5f5
    style Complete fill:#e8f5e9
```

---

## Component Descriptions

### User Browser
- **Purpose:** Client-side interface for document upload and AI chat
- **Technology:** React 18, CSS Modules, Fetch API
- **Location:** `src/App.js`, `src/components/`
- **Dependencies:** Express backend API

### Express Server
- **Purpose:** Backend API server handling uploads and agent communication
- **Technology:** Node.js, Express.js, multer, snowflake-sdk
- **Location:** `server/src/app.js`, `server/src/routes/`
- **Dependencies:** Snowflake account, environment variables (.env)

### Multer File Handler
- **Purpose:** Parses multipart/form-data for PDF uploads
- **Technology:** multer npm package
- **Location:** `server/src/routes/upload.js`
- **Dependencies:** Express middleware

### Snowflake Client SDK
- **Purpose:** Connects to Snowflake and executes file operations
- **Technology:** snowflake-sdk npm package
- **Location:** `server/src/snowflakeClient.js`
- **Dependencies:** Snowflake credentials, network access

### DOCUMENTS_STAGE
- **Purpose:** Internal stage for storing uploaded PDF documents
- **Technology:** Snowflake Internal Stage with directory enabled
- **Location:** `SNOWFLAKE_EXAMPLE.REACT_AGENT_STAGE.DOCUMENTS_STAGE`
- **Dependencies:** SFE_REACT_AGENT_WH warehouse

### DoctorChris Cortex Agent
- **Purpose:** Orchestrates AI-powered document Q&A and translation
- **Technology:** Snowflake Cortex Agent with custom tools
- **Location:** `SNOWFLAKE_EXAMPLE.REACT_AGENT_STAGE.DoctorChris`
- **Dependencies:** Claude 3.5 Sonnet, stored procedures, warehouse

### EXTRACT_STRUCTURED_INSIGHTS_SP
- **Purpose:** Reads PDF from stage, extracts text, generates AI insights
- **Technology:** Python (Snowpark), pypdf, CORTEX.COMPLETE
- **Location:** `sql/setup_snowflake.sql` (lines 49-123)
- **Dependencies:** DOCUMENTS_STAGE, CORTEX.COMPLETE, snowflake-arctic model

### TRANSLATE_DOCUMENT_SP
- **Purpose:** Reads PDF from stage and translates to target language
- **Technology:** Python (Snowpark), pypdf, CORTEX.TRANSLATE
- **Location:** `sql/setup_snowflake.sql` (lines 125-180)
- **Dependencies:** DOCUMENTS_STAGE, CORTEX.TRANSLATE

### Claude 3.5 Sonnet (Orchestration Model)
- **Purpose:** AI orchestration layer that determines tool usage
- **Technology:** Anthropic Claude model via Cortex
- **Location:** External Cortex service
- **Dependencies:** Snowflake Cortex service availability

### CORTEX.COMPLETE
- **Purpose:** Generates structured insights from document text
- **Technology:** Snowflake Cortex LLM function (snowflake-arctic)
- **Location:** Snowflake system function
- **Dependencies:** Cortex service, appropriate grants

### CORTEX.TRANSLATE
- **Purpose:** Translates document text to target language
- **Technology:** Snowflake Cortex translation service
- **Location:** Snowflake system function
- **Dependencies:** Cortex service, appropriate grants

### SFE_REACT_AGENT_WH
- **Purpose:** Dedicated compute warehouse for all agent operations
- **Technology:** Snowflake Virtual Warehouse (XSMALL)
- **Location:** Account-level warehouse
- **Dependencies:** Warehouse grants to SFE_REACT_AGENT_ROLE

---

## Data Transformations

| Stage | Input Format | Transformation | Output Format |
|-------|--------------|----------------|---------------|
| Upload | PDF (binary) | multipart/form-data parsing | Temp file |
| Stage | Temp file | PUT to internal stage | Staged file |
| Extract | Staged PDF | pypdf text extraction | Plain text string |
| Insights | Text + question | CORTEX.COMPLETE prompt | JSON (summary, key_points, confidence) |
| Response | Tool output JSON | Claude orchestrator formatting | User-friendly markdown |

---

## Change History

See `.cursornotes/DIAGRAM_CHANGELOG.md` for version history.
