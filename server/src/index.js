/**
 * Express Backend Server for Snowflake Cortex Agent
 * 
 * Provides REST API endpoints for:
 * - Document upload to Snowflake stage
 * - Chat with Cortex Agent (streaming and non-streaming)
 * - Document listing and summarization
 */

import express from 'express';
import cors from 'cors';
import multer from 'multer';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { v4 as uuidv4 } from 'uuid';
import dotenv from 'dotenv';

// Load environment variables from .secrets/.env
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(__dirname, '../..');
const envPath = path.join(projectRoot, '.secrets', '.env');

if (fs.existsSync(envPath)) {
  dotenv.config({ path: envPath });
  console.log(`Loaded environment from ${envPath}`);
} else {
  console.warn(`Warning: Environment file not found at ${envPath}`);
}

import { execute, uploadFileToStage, getSnowflakeConnection } from './snowflakeClient.js';

const app = express();
const PORT = process.env.PORT || 4000;

// Middleware
app.use(cors());
app.use(express.json());

// Configure multer for file uploads
const uploadDir = path.join(projectRoot, '.uploads');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: uploadDir,
  filename: (req, file, cb) => {
    const uniqueName = `${Date.now()}-${uuidv4()}${path.extname(file.originalname)}`;
    cb(null, uniqueName);
  },
});
const upload = multer({ storage });

// =============================================================================
// Health Check
// =============================================================================

app.get('/health', async (req, res) => {
  try {
    await getSnowflakeConnection();
    res.json({ status: 'healthy', snowflake: 'connected' });
  } catch (error) {
    res.status(503).json({ status: 'unhealthy', error: error.message });
  }
});

// =============================================================================
// Agent Configuration
// =============================================================================

app.get('/api/config', async (req, res) => {
  try {
    const agentName = process.env.SNOWFLAKE_AGENT_NAME || 'DoctorChris';
    const database = process.env.SNOWFLAKE_DATABASE;
    const schema = process.env.SNOWFLAKE_SCHEMA;
    
    // Describe the agent to get its configuration
    const sql = `DESCRIBE AGENT ${database}.${schema}.${agentName}`;
    const rows = await execute(sql);
    
    res.json({
      name: agentName,
      database,
      schema,
      description: rows,
    });
  } catch (error) {
    console.error('Error fetching agent config:', error);
    res.status(500).json({ error: error.message });
  }
});

// =============================================================================
// Chat Endpoints
// =============================================================================

app.post('/api/chat', async (req, res) => {
  try {
    const { message, thread_id, parent_message_id } = req.body;
    
    if (!message?.trim()) {
      return res.status(400).json({ error: 'Message is required' });
    }

    const agentName = process.env.SNOWFLAKE_AGENT_NAME || 'DoctorChris';
    const database = process.env.SNOWFLAKE_DATABASE;
    const schema = process.env.SNOWFLAKE_SCHEMA;
    
    // Build the agent call SQL
    const escapedMessage = message.replace(/'/g, "''");
    let sql = `
      SELECT SNOWFLAKE.CORTEX.AGENT(
        '${database}.${schema}.${agentName}',
        '${escapedMessage}'
      ) AS response
    `;
    
    const rows = await execute(sql);
    const response = rows?.[0]?.RESPONSE;
    
    res.json({
      response: response,
      thread_id: thread_id || uuidv4(),
      message_id: (parent_message_id || 0) + 1,
    });
  } catch (error) {
    console.error('Error in chat:', error);
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/chat/stream', async (req, res) => {
  try {
    const { message, thread_id, parent_message_id, orchestration_budget } = req.body;
    
    if (!message?.trim()) {
      return res.status(400).json({ error: 'Message is required' });
    }

    // Set SSE headers
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');

    const agentName = process.env.SNOWFLAKE_AGENT_NAME || 'DoctorChris';
    const database = process.env.SNOWFLAKE_DATABASE;
    const schema = process.env.SNOWFLAKE_SCHEMA;
    
    // Send thinking event
    res.write(`data: ${JSON.stringify({ type: 'thinking', content: 'Processing your request...' })}\n\n`);
    
    // Execute agent call
    const escapedMessage = message.replace(/'/g, "''");
    let sql = `
      SELECT SNOWFLAKE.CORTEX.AGENT(
        '${database}.${schema}.${agentName}',
        '${escapedMessage}'
      ) AS response
    `;
    
    const rows = await execute(sql);
    const response = rows?.[0]?.RESPONSE;
    
    // Parse and send response
    let parsedResponse;
    try {
      parsedResponse = typeof response === 'string' ? JSON.parse(response) : response;
    } catch {
      parsedResponse = { content: response };
    }
    
    // Send response chunks
    const content = parsedResponse?.content || parsedResponse?.message || String(response);
    
    res.write(`data: ${JSON.stringify({ type: 'response', content })}\n\n`);
    res.write(`data: ${JSON.stringify({ 
      type: 'done', 
      thread_id: thread_id || uuidv4(),
      message_id: (parent_message_id || 0) + 1 
    })}\n\n`);
    
    res.end();
  } catch (error) {
    console.error('Error in streaming chat:', error);
    res.write(`data: ${JSON.stringify({ type: 'error', content: error.message })}\n\n`);
    res.end();
  }
});

// =============================================================================
// Document Management
// =============================================================================

app.post('/api/upload', upload.single('document'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    const localPath = req.file.path;
    const originalName = req.file.originalname;
    const stagePath = originalName;
    
    // Upload to Snowflake stage
    await uploadFileToStage(localPath, stagePath);
    
    // Refresh directory table
    const stage = process.env.SNOWFLAKE_STAGE || 'SFE_DOCUMENTS_STAGE';
    await execute(`ALTER STAGE ${stage} REFRESH`);
    
    // Clean up local file
    fs.unlinkSync(localPath);
    
    res.json({
      success: true,
      stagePath,
      originalName,
      size: req.file.size,
      message: 'File uploaded successfully. Processing will begin automatically within 1 minute.',
    });
  } catch (error) {
    console.error('Error uploading file:', error);
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/documents', async (req, res) => {
  try {
    const sql = `
      SELECT 
        FILE_PATH,
        FILE_NAME,
        FILE_SIZE,
        LAST_MODIFIED,
        PAGE_COUNT,
        EXTRACTION_TIMESTAMP,
        LENGTH(EXTRACTED_TEXT) AS TEXT_LENGTH
      FROM SFE_DOCUMENT_METADATA
      ORDER BY LAST_MODIFIED DESC
    `;
    
    const rows = await execute(sql);
    
    res.json(rows.map(row => ({
      path: row.FILE_PATH,
      name: row.FILE_NAME,
      size: row.FILE_SIZE,
      lastModified: row.LAST_MODIFIED,
      pageCount: row.PAGE_COUNT,
      extractedAt: row.EXTRACTION_TIMESTAMP,
      textLength: row.TEXT_LENGTH,
    })));
  } catch (error) {
    console.error('Error listing documents:', error);
    res.status(500).json({ error: error.message });
  }
});

// =============================================================================
// Document Summarization
// =============================================================================

app.post('/api/summarize', async (req, res) => {
  try {
    const { stagePath, prompt, content } = req.body;
    
    let textToSummarize = content;
    
    // If stagePath provided, fetch content from metadata table
    if (stagePath && !content) {
      const escapedPath = stagePath.replace(/'/g, "''");
      const sql = `
        SELECT EXTRACTED_TEXT 
        FROM SFE_DOCUMENT_METADATA 
        WHERE FILE_PATH = '${escapedPath}'
      `;
      const rows = await execute(sql);
      textToSummarize = rows?.[0]?.EXTRACTED_TEXT;
      
      if (!textToSummarize) {
        return res.status(404).json({ 
          error: 'Document not found or not yet processed. Wait ~1 minute after upload.' 
        });
      }
    }
    
    if (!textToSummarize) {
      return res.status(400).json({ error: 'Either stagePath or content is required' });
    }

    // Use Cortex to summarize
    const summaryPrompt = prompt || 
      'Provide a concise executive summary of the following document focusing on key findings, main points, and any recommended actions.';
    
    const escapedText = textToSummarize.substring(0, 30000).replace(/'/g, "''");
    const escapedPrompt = summaryPrompt.replace(/'/g, "''");
    
    const sql = `
      SELECT AI_COMPLETE(
        'mistral-large2',
        '${escapedPrompt}

Document:
${escapedText}'
      ) AS summary
    `;
    
    const rows = await execute(sql);
    const summary = rows?.[0]?.SUMMARY;
    
    res.json({ summary });
  } catch (error) {
    console.error('Error summarizing document:', error);
    res.status(500).json({ error: error.message });
  }
});

// =============================================================================
// Start Server
// =============================================================================

app.listen(PORT, () => {
  console.log(`
================================================================================
  Snowflake Cortex Agent Backend Server
================================================================================

  Server running on: http://localhost:${PORT}

  Endpoints:
    GET  /health          - Health check
    GET  /api/config      - Agent configuration
    POST /api/chat        - Send message to agent
    POST /api/chat/stream - Stream message to agent (SSE)
    POST /api/upload      - Upload document to stage
    GET  /api/documents   - List processed documents
    POST /api/summarize   - Summarize document content

================================================================================
`);
});

