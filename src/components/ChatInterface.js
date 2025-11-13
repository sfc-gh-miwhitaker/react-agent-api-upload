import React, { useEffect, useRef, useState } from 'react';
import MessageList from './MessageList';
import MessageInput from './MessageInput';
import { streamMessageToAgent } from '../services/snowflakeApi';
import './ChatInterface.css';

const createAssistantGreeting = (agentName) => ({
  id: 1,
  role: 'assistant',
  content: `Hello! I'm your Snowflake Cortex Agent (${agentName}). How can I help you today?`,
  timestamp: new Date(),
});

const ChatInterface = ({ config }) => {
  const [messages, setMessages] = useState([createAssistantGreeting(config.agentName)]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState(null);
  const [threadId, setThreadId] = useState(null);
  const [parentMessageId, setParentMessageId] = useState(0);
  const messagesEndRef = useRef(null);

  const databaseLabel = config.database || 'DATABASE';
  const schemaLabel = config.schema || 'SCHEMA';

  useEffect(() => {
    setMessages([createAssistantGreeting(config.agentName)]);
    setThreadId(null);
    setParentMessageId(0);
  }, [config.agentName]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const addMessage = (message) => {
    setMessages((prev) => [...prev, message]);
  };

  const updateMessageContent = (id, content) => {
    setMessages((prev) =>
      prev.map((msg) =>
        msg.id === id
          ? {
              ...msg,
              content,
            }
          : msg,
      ),
    );
  };

  const handleSendMessage = async (rawContent) => {
    const content = rawContent.trim();
    if (!content) {
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
    setError(null);

    let thinkingText = '';
    let responseText = '';
    let assistantMessageId = null;
    let streamThreadId = threadId;

    try {
      await streamMessageToAgent(content, threadId, parentMessageId, (event) => {
        console.log('[Frontend] Received event:', event.type, event);
        if (event.type === 'thread_created') {
          streamThreadId = event.thread_id;
        } else if (event.type === 'status') {
          // Only show status if we haven't started receiving response text yet
          if (!responseText) {
            const statusText = `💭 ${event.status}...`;
            setMessages((prev) =>
              prev.map((msg) =>
                msg.id === assistantPlaceholderId
                  ? { ...msg, content: statusText }
                  : msg,
              ),
            );
          }
        } else if (event.type === 'thinking_delta') {
          // Thinking phase - accumulate thinking text
          // Only show thinking if we haven't started receiving response text yet
          if (!responseText) {
            thinkingText += event.text;
            setMessages((prev) =>
              prev.map((msg) =>
                msg.id === assistantPlaceholderId
                  ? { ...msg, content: `💭 ${thinkingText}` }
                  : msg,
              ),
            );
          }
        } else if (event.type === 'text_delta' || event.type === 'text') {
          // Response phase - accumulate response text
          responseText += event.text;
          // Show response (thinking is now hidden)
          setMessages((prev) =>
            prev.map((msg) =>
              msg.id === assistantPlaceholderId
                ? { ...msg, content: responseText }
                : msg,
            ),
          );
        } else if (event.type === 'metadata') {
          assistantMessageId = event.data?.message_id;
        } else if (event.type === 'complete') {
          streamThreadId = event.thread_id;
        } else if (event.type === 'error') {
          throw new Error(event.error);
        }
      });

      // Update thread context for next message
      if (streamThreadId) {
        setThreadId(streamThreadId);
      }
      if (assistantMessageId) {
        setParentMessageId(assistantMessageId);
      }

      // If no content was received, show a message
      if (!responseText && !thinkingText) {
        updateMessageContent(assistantPlaceholderId, 'I could not generate a response.');
      }
    } catch (err) {
      console.error('Error sending message:', err);
      const message = err.message || 'Failed to send message to the agent.';
      updateMessageContent(
        assistantPlaceholderId,
        `I'm sorry, I encountered an error: ${message}\n\nTip: Check the backend logs for detailed error information.`,
      );
      setError(message);
    } finally {
      setIsLoading(false);
    }
  };

  const clearChat = () => {
    setMessages([createAssistantGreeting(config.agentName)]);
    setError(null);
    setThreadId(null);
    setParentMessageId(0);
  };

  return (
    <div className="chat-interface">
      <div className="chat-header">
        <div className="agent-info">
          <h3>{config.agentName}</h3>
          <span className="connection-status">
            Connected to {databaseLabel}.{schemaLabel}
          </span>
        </div>
        <button className="clear-button" onClick={clearChat}>
          Clear Chat
        </button>
      </div>

      <div className="chat-container">
        <MessageList messages={messages} isLoading={isLoading} />
        <div ref={messagesEndRef} />
      </div>

      {error && (
        <div className="error-banner">
          <span>Warning: {error}</span>
          <button type="button" onClick={() => setError(null)}>
            Close
          </button>
        </div>
      )}

      <MessageInput onSendMessage={handleSendMessage} isLoading={isLoading} />
    </div>
  );
};

export default ChatInterface;
