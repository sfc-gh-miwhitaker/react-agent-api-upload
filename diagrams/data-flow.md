# Data Flow - React Agent API Upload

**Author:** SE Community  
**Last Updated:** 2025-11-25  
**Expires:** 2025-12-25  
**Status:** Reference Implementation

---

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

**Reference Implementation:** This code demonstrates production-grade architectural patterns and best practices. Review and customize security, networking, and business logic for your organization's specific requirements before deployment.

---

## Overview

This diagram shows how document data flows through the React Cortex Agent chat application, from user upload through Snowflake storage to AI-powered analysis and response generation using native Snowflake document intelligence.

---

## Diagram

```mermaid
graph TB
    subgraph "User Browser"
        User[End User]
        UI[React Frontend<br/>Port 3002]
    end
    
    subgraph "Local Backend"
        Express[Express Server<br/>Port 4000]
        Multer[Multer File Handler]
        SFClient[Snowflake Client SDK]
        JWT[JWT Generator]
    end
    
    subgraph "Snowflake Cloud - SNOWFLAKE_EXAMPLE.REACT_AGENT_STAGE"
        subgraph "Storage Layer"
            Stage[SFE_DOCUMENTS_STAGE<br/>Internal Stage]
            DirTable[Directory Table<br/>Auto-tracks files]
        end
        
        subgraph "Event-Driven Processing"
            Stream[SFE_DOCUMENTS_STREAM<br/>CDC Stream]
            Task[SFE_EXTRACT_TEXT_TASK<br/>1-minute schedule]
            Metadata[(SFE_DOCUMENT_METADATA<br/>Extracted content)]
        end
        
        subgraph "AI Services"
            ParseDoc[CORTEX.PARSE_DOCUMENT<br/>Text extraction]
            Search[DOCUMENT_SEARCH_SERVICE<br/>Cortex Search]
            Agent[DoctorChris<br/>Cortex Agent]
            Complete[CORTEX.COMPLETE<br/>mistral-large2]
            Translate[CORTEX.TRANSLATE]
        end
        
        subgraph "Agent Tools"
            QATool[ANSWER_DOCUMENT_QUESTION<br/>Document Q&A]
            TransTool[TRANSLATE_DOCUMENT<br/>Translation]
        end
        
        subgraph "Compute"
            WH[SFE_REACT_AGENT_WH<br/>XSMALL Warehouse]
        end
    end
    
    User -->|1. Upload PDF| UI
    UI -->|2. POST /api/upload| Express
    Express -->|3. Parse multipart| Multer
    Multer -->|4. Temp file| Express
    Express -->|5. Connect| SFClient
    SFClient -->|6. PUT file| Stage
    Stage -->|7. Track file| DirTable
    DirTable -->|8. CDC event| Stream
    Stream -->|9. Has data?| Task
    Task -->|10. PARSE_DOCUMENT| ParseDoc
    ParseDoc -->|11. Extract text| Metadata
    
    User -->|12. Ask question| UI
    UI -->|13. POST /api/chat| Express
    Express -->|14. Generate JWT| JWT
    JWT -->|15. REST API| Agent
    Agent -->|16. Select tool| QATool
    QATool -->|17. Query docs| Metadata
    QATool -->|18. Generate answer| Complete
    Complete -->|19. Structured JSON| QATool
    QATool -->|20. Return results| Agent
    Agent -->|21. Format response| Express
    Express -->|22. SSE stream| UI
    UI -->|23. Display answer| User
    
    Task -.->|Runs on| WH
    QATool -.->|Runs on| WH
    TransTool -.->|Runs on| WH
    
    style User fill:#e3f2fd
    style Stage fill:#fff3e0
    style Agent fill:#f3e5f5
    style Complete fill:#e8f5e9
    style Metadata fill:#e1f5fe
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
- **Dependencies:** Snowflake account, environment variables (.secrets/.env)
- **Port:** 4000

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

### SFE_DOCUMENTS_STAGE (Internal Stage)
- **Purpose:** Storage for uploaded PDF documents with directory table
- **Technology:** Snowflake Internal Stage with DIRECTORY enabled
- **Location:** `SNOWFLAKE_EXAMPLE.REACT_AGENT_STAGE.SFE_DOCUMENTS_STAGE`
- **Dependencies:** SFE_REACT_AGENT_WH warehouse

### SFE_DOCUMENTS_STREAM
- **Purpose:** CDC stream tracking new file uploads
- **Technology:** Snowflake Stream on Stage
- **Location:** `SNOWFLAKE_EXAMPLE.REACT_AGENT_STAGE.SFE_DOCUMENTS_STREAM`
- **Dependencies:** Directory table on stage

### SFE_EXTRACT_TEXT_TASK
- **Purpose:** Event-driven task that processes new documents every minute
- **Technology:** Snowflake Serverless Task
- **Location:** `SNOWFLAKE_EXAMPLE.REACT_AGENT_STAGE.SFE_EXTRACT_TEXT_TASK`
- **Dependencies:** Stream, warehouse, PARSE_DOCUMENT function

### SFE_DOCUMENT_METADATA
- **Purpose:** Stores extracted text and metadata for all processed documents
- **Technology:** Snowflake Table
- **Location:** `SNOWFLAKE_EXAMPLE.REACT_AGENT_STAGE.SFE_DOCUMENT_METADATA`
- **Dependencies:** Task populates via MERGE

### DoctorChris Cortex Agent
- **Purpose:** Orchestrates AI-powered document Q&A and translation
- **Technology:** Snowflake Cortex Agent with custom tools
- **Location:** `SNOWFLAKE_EXAMPLE.REACT_AGENT_STAGE.DoctorChris`
- **Dependencies:** claude-4-sonnet orchestration model, stored procedures, warehouse

### ANSWER_DOCUMENT_QUESTION
- **Purpose:** Agent tool that queries documents and generates structured answers
- **Technology:** SQL Stored Procedure using CORTEX.COMPLETE
- **Location:** `sql/setup_snowflake.sql`
- **Dependencies:** SFE_DOCUMENT_METADATA table, mistral-large2 model

### TRANSLATE_DOCUMENT
- **Purpose:** Agent tool that translates document content
- **Technology:** SQL Stored Procedure using CORTEX.TRANSLATE
- **Location:** `sql/setup_snowflake.sql`
- **Dependencies:** SFE_DOCUMENT_METADATA table

### SFE_REACT_AGENT_WH
- **Purpose:** Dedicated compute warehouse for all agent operations
- **Technology:** Snowflake Virtual Warehouse (XSMALL, AUTO_SUSPEND=60s)
- **Location:** Account-level warehouse
- **Dependencies:** Warehouse grants to SFE_REACT_AGENT_ROLE

---

## Data Transformations

| Stage | Input Format | Transformation | Output Format |
|-------|--------------|----------------|---------------|
| Upload | PDF (binary) | multipart/form-data parsing | Temp file |
| Stage | Temp file | PUT to internal stage | Staged file |
| Directory | Staged file | Auto-track in directory table | File metadata |
| Stream | Directory change | CDC capture | Change record |
| Task | Change record | CORTEX.PARSE_DOCUMENT | Extracted text |
| Metadata | Extracted text | MERGE into table | Searchable document |
| Q&A | User question + docs | CORTEX.COMPLETE | Structured JSON |
| Response | Tool output JSON | Agent formatting | User-friendly text |

---

## Change History

See `.cursor/DIAGRAM_CHANGELOG.md` for version history.
