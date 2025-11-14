import React, { useState, useEffect, useRef } from 'react';
import { 
  uploadDocument, 
  listDocuments, 
  generateDocumentSummary,
  streamMessageToAgent 
} from '../services/snowflakeApi';
import MessageList from './MessageList';
import MessageInput from './MessageInput';
import './DocumentIntelligence.css';

// Orchestration budget modes
const ORCHESTRATION_MODES = {
  standard: { seconds: 30, tokens: 8000 },
  research: { seconds: 120, tokens: 32000 },
};

const createWelcomeMessage = () => ({
  id: 1,
  role: 'assistant',
  content: `Hello! I'm Dr. Chris, your document intelligence assistant. 

**To get started:**
1. Upload a document using the panel on the left
2. Ask me questions about your documents
3. Enable Research Mode for thorough analysis

I can help you understand, summarize, translate, and extract information from your documents.`,
  timestamp: new Date(),
});

const DocumentIntelligence = ({ config }) => {
  // Document state
  const [documents, setDocuments] = useState([]);
  const [selectedFile, setSelectedFile] = useState(null);
  const [uploading, setUploading] = useState(false);
  const [loadingDocs, setLoadingDocs] = useState(false);
  const [docError, setDocError] = useState('');
  const [summaryStyle, setSummaryStyle] = useState('Summarize this document concisely');

  // Chat state
  const [messages, setMessages] = useState([createWelcomeMessage()]);
  const [isLoading, setIsLoading] = useState(false);
  const [chatError, setChatError] = useState(null);
  const [threadId, setThreadId] = useState(null);
  const [parentMessageId, setParentMessageId] = useState(0);
  const [researchMode, setResearchMode] = useState(false);
  
  const messagesEndRef = useRef(null);
  const fileInputRef = useRef(null);

  useEffect(() => {
    loadDocuments();
  }, []);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const loadDocuments = async () => {
    setLoadingDocs(true);
    setDocError('');
    try {
      const docs = await listDocuments();
      setDocuments(docs);
    } catch (err) {
      console.error('Error loading documents:', err);
      setDocError(err.message || 'Failed to load documents');
    } finally {
      setLoadingDocs(false);
    }
  };

  const handleFileSelect = (event) => {
    const file = event.target.files?.[0];
    if (file) {
      setSelectedFile(file);
    }
  };

  const handleUpload = async () => {
    if (!selectedFile) {
      setDocError('Please select a file first');
      return;
    }

    setUploading(true);
    setDocError('');
    try {
      const result = await uploadDocument(selectedFile);
      console.log('Upload successful:', result);
      setSelectedFile(null);
      if (fileInputRef.current) {
        fileInputRef.current.value = '';
      }
      await loadDocuments();
      
      // Add success message to chat
      addMessage({
        id: Date.now(),
        role: 'assistant',
        content: `✅ **Document uploaded successfully!**\n\nFile: ${selectedFile.name}\n\nYou can now ask me questions about this document.`,
        timestamp: new Date(),
      });
    } catch (err) {
      console.error('Upload error:', err);
      setDocError(err.message || 'Failed to upload document');
    } finally {
      setUploading(false);
    }
  };

  const handleGenerateSummary = async (doc) => {
    const summaryMessageId = Date.now();
    addMessage({
      id: summaryMessageId,
      role: 'assistant',
      content: '🔄 Generating summary...',
      timestamp: new Date(),
    });

    try {
      const summary = await generateDocumentSummary(doc.name, summaryStyle);
      updateMessageContent(summaryMessageId, `**Summary of ${doc.name}:**\n\n${summary}`);
    } catch (err) {
      console.error('Error generating summary:', err);
      updateMessageContent(
        summaryMessageId,
        `❌ Error generating summary: ${err.message}`
      );
    }
  };

  const addMessage = (message) => {
    setMessages((prev) => [...prev, message]);
  };

  const updateMessageContent = (id, content) => {
    setMessages((prev) =>
      prev.map((msg) => (msg.id === id ? { ...msg, content } : msg))
    );
  };

  const handleSendMessage = async (rawContent) => {
    const content = rawContent.trim();
    if (!content) return;

    // Add context about available documents
    let contextualMessage = content;
    if (documents.length === 0) {
      setChatError('Please upload a document first before asking questions.');
      return;
    }

    const userMessage = {
      id: Date.now(),
      role: 'user',
      content,
      timestamp: new Date(),
    };

    const assistantPlaceholderId = userMessage.id + 1;

    addMessage(userMessage);
    addMessage({
      id: assistantPlaceholderId,
      role: 'assistant',
      content: '',
      timestamp: new Date(),
    });

    setIsLoading(true);
    setChatError(null);

    let thinkingText = '';
    let responseText = '';
    let assistantMessageId = null;
    let streamThreadId = threadId;

    try {
      const orchestrationBudget = researchMode
        ? ORCHESTRATION_MODES.research
        : ORCHESTRATION_MODES.standard;

      await streamMessageToAgent(
        contextualMessage,
        threadId,
        parentMessageId,
        orchestrationBudget,
        (event) => {
          if (event.type === 'thread_created') {
            streamThreadId = event.thread_id;
          } else if (event.type === 'status') {
            if (!responseText) {
              const statusText = `💭 ${event.status}...`;
              setMessages((prev) =>
                prev.map((msg) =>
                  msg.id === assistantPlaceholderId
                    ? { ...msg, content: statusText }
                    : msg
                )
              );
            }
          } else if (event.type === 'thinking_delta') {
            if (!responseText) {
              thinkingText += event.text;
              setMessages((prev) =>
                prev.map((msg) =>
                  msg.id === assistantPlaceholderId
                    ? { ...msg, content: `💭 ${thinkingText}` }
                    : msg
                )
              );
            }
          } else if (event.type === 'text_delta' || event.type === 'text') {
            responseText += event.text;
            setMessages((prev) =>
              prev.map((msg) =>
                msg.id === assistantPlaceholderId
                  ? { ...msg, content: responseText }
                  : msg
              )
            );
          } else if (event.type === 'metadata') {
            assistantMessageId = event.data?.message_id;
          } else if (event.type === 'complete') {
            streamThreadId = event.thread_id;
          } else if (event.type === 'error') {
            throw new Error(event.error);
          }
        }
      );

      if (streamThreadId) {
        setThreadId(streamThreadId);
      }
      if (assistantMessageId) {
        setParentMessageId(assistantMessageId);
      }

      if (!responseText && !thinkingText) {
        updateMessageContent(
          assistantPlaceholderId,
          'I could not generate a response. Please try rephrasing your question.'
        );
      }
    } catch (err) {
      console.error('Error sending message:', err);
      const message = err.message || 'Failed to send message';
      updateMessageContent(
        assistantPlaceholderId,
        `I'm sorry, I encountered an error: ${message}\n\nTip: Check that your documents are properly uploaded.`
      );
      setChatError(message);
    } finally {
      setIsLoading(false);
    }
  };

  const clearChat = () => {
    setMessages([createWelcomeMessage()]);
    setChatError(null);
    setThreadId(null);
    setParentMessageId(0);
  };

  return (
    <div className="doc-intelligence-container">
      {/* Left Panel - Document Library */}
      <div className="doc-panel">
        <div className="doc-panel-header">
          <h3>📁 Document Library</h3>
          <button 
            onClick={loadDocuments} 
            className="refresh-button"
            disabled={loadingDocs}
          >
            {loadingDocs ? '⟳' : '↻'}
          </button>
        </div>

        {/* Upload Section */}
        <div className="upload-section">
          <label className="file-input-label">
            <input
              ref={fileInputRef}
              type="file"
              onChange={handleFileSelect}
              accept=".pdf,.docx,.doc,.pptx,.txt,.html,.xml,.json,.csv"
              className="file-input"
            />
            <span className="file-input-button">
              {selectedFile ? `📄 ${selectedFile.name}` : '📎 Select Document'}
            </span>
          </label>
          <button
            onClick={handleUpload}
            disabled={!selectedFile || uploading}
            className="upload-button"
          >
            {uploading ? 'Uploading...' : 'Upload'}
          </button>
        </div>

        {docError && (
          <div className="doc-error">{docError}</div>
        )}

        {/* Documents List */}
        <div className="docs-list">
          <h4>Uploaded Documents ({documents.length})</h4>
          {loadingDocs ? (
            <p className="loading-text">Loading documents...</p>
          ) : documents.length === 0 ? (
            <p className="empty-text">No documents uploaded yet</p>
          ) : (
            <ul className="doc-items">
              {documents.map((doc, idx) => (
                <li key={idx} className="doc-item">
                  <div className="doc-item-info">
                    <span className="doc-icon">📄</span>
                    <div className="doc-details">
                      <span className="doc-name">{doc.name}</span>
                      <span className="doc-size">{doc.size || 'Unknown size'}</span>
                    </div>
                  </div>
                  <button
                    onClick={() => handleGenerateSummary(doc)}
                    className="doc-action-button"
                    title="Generate summary"
                  >
                    📝
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>

        {/* Summary Style */}
        {documents.length > 0 && (
          <div className="summary-style-section">
            <label htmlFor="summaryStyle">Summary Prompt:</label>
            <textarea
              id="summaryStyle"
              value={summaryStyle}
              onChange={(e) => setSummaryStyle(e.target.value)}
              placeholder="e.g., Summarize in bullet points, Translate to Spanish, Extract key dates"
              rows={3}
            />
          </div>
        )}
      </div>

      {/* Right Panel - Chat */}
      <div className="chat-panel">
        <div className="chat-panel-header">
          <div className="chat-header-info">
            <h3>💬 Ask About Your Documents</h3>
            <span className="doc-count">
              {documents.length} document{documents.length !== 1 ? 's' : ''} available
            </span>
          </div>
          <div className="chat-header-controls">
            <button
              className={`research-mode-toggle ${researchMode ? 'active' : ''}`}
              onClick={() => setResearchMode(!researchMode)}
              title={
                researchMode
                  ? 'Research Mode ON - Deep analysis'
                  : 'Research Mode OFF - Fast responses'
              }
            >
              <span className="toggle-icon">🔬</span>
              Research
            </button>
            <button className="clear-chat-button" onClick={clearChat}>
              Clear
            </button>
          </div>
        </div>

        <div className="chat-messages-container">
          <MessageList messages={messages} isLoading={isLoading} />
          <div ref={messagesEndRef} />
        </div>

        {chatError && (
          <div className="chat-error-banner">
            <span>{chatError}</span>
            <button onClick={() => setChatError(null)}>×</button>
          </div>
        )}

        <MessageInput 
          onSendMessage={handleSendMessage} 
          isLoading={isLoading}
          placeholder={
            documents.length === 0
              ? 'Upload a document first...'
              : 'Ask about your documents...'
          }
        />
      </div>
    </div>
  );
};

export default DocumentIntelligence;

