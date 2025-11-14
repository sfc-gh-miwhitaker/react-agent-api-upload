const BACKEND_URL = process.env.REACT_APP_BACKEND_URL || 'http://localhost:4000';

const ensureResponseOk = async (response) => {
  if (response.ok) {
    return;
  }

  const body = await response.text();
  throw new Error(`Backend error ${response.status}: ${body || response.statusText}`);
};

export const fetchAgentConfig = async () => {
  const response = await fetch(`${BACKEND_URL}/api/config`, {
    method: 'GET',
    headers: {
      Accept: 'application/json',
    },
  });

  await ensureResponseOk(response);
  return response.json();
};

export const sendMessageToAgent = async (message, threadId = null, parentMessageId = 0) => {
  const trimmed = message?.trim();
  if (!trimmed) {
    throw new Error('Cannot send an empty message to the Cortex Agent.');
  }

  const response = await fetch(`${BACKEND_URL}/api/chat`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify({
      message: trimmed,
      thread_id: threadId,
      parent_message_id: parentMessageId,
    }),
  });

  await ensureResponseOk(response);
  return response.json();
};

export const describeAgent = async () => {
  const response = await fetch(`${BACKEND_URL}/api/config`, {
    method: 'GET',
    headers: {
      Accept: 'application/json',
    },
  });

  await ensureResponseOk(response);
  return response.json();
};

/**
 * Stream messages with real-time thinking and response updates
 * @param {string} message - User message
 * @param {string|null} threadId - Thread ID
 * @param {number} parentMessageId - Parent message ID
 * @param {object|null} orchestrationBudget - Budget config for research mode
 * @param {function} onChunk - Callback for each chunk: (event) => void
 */
export const streamMessageToAgent = async (message, threadId = null, parentMessageId = 0, orchestrationBudget = null, onChunk) => {
  const trimmed = message?.trim();
  if (!trimmed) {
    throw new Error('Cannot send an empty message to the Cortex Agent.');
  }

  const requestBody = {
    message: trimmed,
    thread_id: threadId,
    parent_message_id: parentMessageId,
  };

  // Add orchestration budget if provided (for research mode)
  if (orchestrationBudget) {
    requestBody.orchestration_budget = orchestrationBudget;
  }

  const response = await fetch(`${BACKEND_URL}/api/chat/stream`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(requestBody),
  });

  await ensureResponseOk(response);

  // Read the stream
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';

  try {
    while (true) {
      const { done, value } = await reader.read();
      
      if (done) break;

      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split('\n');
      buffer = lines.pop() || '';

      for (const line of lines) {
        if (line.startsWith('data: ')) {
          const dataStr = line.substring(6);
          if (dataStr.trim() === '') continue;

          try {
            const event = JSON.parse(dataStr);
            onChunk(event);
            
            if (event.type === 'done' || event.type === 'complete') {
              return;
            }
          } catch (err) {
            console.error('Failed to parse SSE data:', err, dataStr);
          }
        }
      }
    }
  } finally {
    reader.releaseLock();
  }
};

/**
 * Upload a document to Snowflake stage
 * @param {File} file - The file to upload
 * @returns {Promise<object>} Upload result with stagePath, originalName, size, etc.
 */
export const uploadDocument = async (file) => {
  if (!file) {
    throw new Error('No file provided');
  }

  const formData = new FormData();
  formData.append('document', file);

  const response = await fetch(`${BACKEND_URL}/api/upload`, {
    method: 'POST',
    body: formData,
  });

  await ensureResponseOk(response);
  return response.json();
};

/**
 * List all documents from Snowflake stage
 * @returns {Promise<Array>} Array of document objects with name, size, lastModified
 */
export const listDocuments = async () => {
  const response = await fetch(`${BACKEND_URL}/api/documents`, {
    method: 'GET',
    headers: {
      Accept: 'application/json',
    },
  });

  await ensureResponseOk(response);
  return response.json();
};

/**
 * Generate a summary of a document using Cortex AI
 * @param {string} stagePath - The path to the document in the stage
 * @param {string} prompt - Optional custom prompt for summarization
 * @returns {Promise<object>} Summary result with summary text and bytesProcessed
 */
export const generateDocumentSummary = async (stagePath, prompt = null) => {
  if (!stagePath) {
    throw new Error('stagePath is required');
  }

  const requestBody = { stagePath };
  if (prompt) {
    requestBody.prompt = prompt;
  }

  const response = await fetch(`${BACKEND_URL}/api/summarize`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify(requestBody),
  });

  await ensureResponseOk(response);
  const result = await response.json();
  return result.summary; // Return just the summary text
};
