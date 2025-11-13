const BACKEND_URL = process.env.REACT_APP_BACKEND_URL || 'http://localhost:4000';

const jsonHeaders = {
  Accept: 'application/json',
};

export async function uploadDocument(file) {
  const formData = new FormData();
  formData.append('document', file);

  const response = await fetch(`${BACKEND_URL}/api/upload`, {
    method: 'POST',
    body: formData,
  });

  if (!response.ok) {
    const error = await safeJson(response);
    throw new Error(error?.error || `Upload failed with status ${response.status}`);
  }

  return response.json();
}

export async function summarizeDocument({ stagePath, prompt, content }) {
  const response = await fetch(`${BACKEND_URL}/api/summarize`, {
    method: 'POST',
    headers: {
      ...jsonHeaders,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ stagePath, prompt, content }),
  });

  if (!response.ok) {
    const error = await safeJson(response);
    throw new Error(error?.error || `Summarization failed with status ${response.status}`);
  }

  return response.json();
}

async function safeJson(response) {
  try {
    return await response.json();
  } catch {
    return null;
  }
}

export function getBackendUrl() {
  return BACKEND_URL;
}



