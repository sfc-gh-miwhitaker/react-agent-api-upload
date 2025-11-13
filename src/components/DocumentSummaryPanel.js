import React, { useState } from 'react';
import './DocumentSummaryPanel.css';
import { uploadDocument, summarizeDocument, getBackendUrl } from '../services/documentService';

const INITIAL_STATE = {
  stagePath: '',
  originalName: '',
  preview: '',
  summary: '',
};

const MAX_PREVIEW_CHARS = 1000;

const DocumentSummaryPanel = () => {
  const [status, setStatus] = useState('idle');
  const [error, setError] = useState('');
  const [documentState, setDocumentState] = useState(INITIAL_STATE);
  const [prompt, setPrompt] = useState(
    'Provide a detailed analysis of this document, highlighting key insights, risks, and recommended actions.',
  );

  const handleUpload = async (event) => {
    const [file] = event.target.files || [];
    if (!file) {
      return;
    }

    setError('');
    setStatus('uploading');
    setDocumentState(INITIAL_STATE);

    try {
      const result = await uploadDocument(file);
      setDocumentState({
        stagePath: result.stagePath,
        originalName: result.originalName,
        preview: result.preview.slice(0, MAX_PREVIEW_CHARS),
        summary: '',
      });
      setStatus('uploaded');
    } catch (err) {
      setError(err.message);
      setStatus('idle');
    } finally {
      event.target.value = '';
    }
  };

  const handleSummarize = async () => {
    if (!documentState.stagePath) {
      setError('Upload a document before requesting a summary.');
      return;
    }

    setStatus('summarizing');
    setError('');

    try {
      const response = await summarizeDocument({
        stagePath: documentState.stagePath,
        prompt,
      });
      setDocumentState((prev) => ({
        ...prev,
        summary: response.summary,
      }));
      setStatus('summarized');
    } catch (err) {
      setError(err.message);
      setStatus('uploaded');
    }
  };

  const resetDocument = () => {
    setDocumentState(INITIAL_STATE);
    setError('');
    setStatus('idle');
  };

  return (
    <div className="document-summary-panel">
      <section className="document-actions">
        <h2>Document Upload &amp; Summary</h2>
        <p>
          Upload a document (PDF, TXT, MD, CSV, JSON, etc.) to the Snowflake stage. The AI agent will summarize the content using Snowflake Cortex. Backend: <code>{getBackendUrl()}</code>.
        </p>

        <div className="upload-controls">
          <label className="file-input">
            <span>Select document</span>
            <input type="file" accept=".pdf,.txt,.md,.csv,.log,.json,.html,.xml,.doc,.docx" onChange={handleUpload} disabled={status === 'uploading'} />
          </label>
          <button
            className="secondary-button"
            type="button"
            onClick={resetDocument}
            disabled={status === 'uploading'}
          >
            Clear
          </button>
        </div>

        <label className="prompt-field">
          <span>Instructions for AI</span>
          <textarea
            value={prompt}
            onChange={(event) => setPrompt(event.target.value)}
            rows={4}
            placeholder="Examples: 'Summarize key points', 'Translate to Spanish', 'Extract all dates and deadlines', 'List action items'"
          />
        </label>

        <button
          type="button"
          className="primary-button"
          onClick={handleSummarize}
          disabled={status === 'uploading' || !documentState.stagePath}
        >
          {status === 'summarizing' ? 'Summarizing...' : 'Generate Summary'}
        </button>
      </section>

      <section className="document-results">
        <div className="status-line">
          <strong>Status:</strong> {status}
        </div>

        {error && (
          <div className="error-notice">
            <strong>Error:</strong> {error}
          </div>
        )}

        {documentState.stagePath && (
          <div className="stage-details">
            <h3>Stage Reference</h3>
            <dl>
              <div>
                <dt>Original Name</dt>
                <dd>{documentState.originalName}</dd>
              </div>
              <div>
                <dt>Stage Path</dt>
                <dd>{documentState.stagePath}</dd>
              </div>
            </dl>
          </div>
        )}

        {documentState.preview && (
          <div className="preview-card">
            <h3>Preview</h3>
            <pre>{documentState.preview}</pre>
          </div>
        )}

        {documentState.summary && (
          <div className="summary-card">
            <h3>AI Analysis</h3>
            <p>{documentState.summary}</p>
          </div>
        )}
      </section>
    </div>
  );
};

export default DocumentSummaryPanel;



