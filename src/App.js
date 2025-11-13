import React, { useEffect, useState } from 'react';
import ChatInterface from './components/ChatInterface';
import DocumentSummaryPanel from './components/DocumentSummaryPanel';
import { fetchAgentConfig } from './services/snowflakeApi';
import './App.css';

function App() {
  const [agentConfig, setAgentConfig] = useState(null);
  const [activeView, setActiveView] = useState('chat');
  const [loadingConfig, setLoadingConfig] = useState(true);
  const [configError, setConfigError] = useState('');

  useEffect(() => {
    let isMounted = true;

    const loadConfig = async () => {
      try {
        const response = await fetchAgentConfig();
        if (isMounted) {
          setAgentConfig(response);
          setConfigError('');
        }
      } catch (error) {
        if (isMounted) {
          setConfigError(error.message || 'Unable to load Cortex Agent configuration.');
        }
      } finally {
        if (isMounted) {
          setLoadingConfig(false);
        }
      }
    };

    loadConfig();

    return () => {
      isMounted = false;
    };
  }, []);

  return (
    <div className="App">
      <header className="app-header">
        <h1>Snowflake Cortex Agent Chat</h1>
        <div className="header-actions">
          {!loadingConfig && !configError && agentConfig && (
            <div className="view-toggle">
              <button
                type="button"
                className={activeView === 'chat' ? 'toggle-button active' : 'toggle-button'}
                onClick={() => setActiveView('chat')}
              >
                Chat
              </button>
              <button
                type="button"
                className={activeView === 'summary' ? 'toggle-button active' : 'toggle-button'}
                onClick={() => setActiveView('summary')}
              >
                Document Summary
              </button>
            </div>
          )}
        </div>
      </header>

      <main className="app-main">
        {loadingConfig && (
          <div className="status-card">
            <p>Loading Cortex Agent configuration...</p>
          </div>
        )}

        {!loadingConfig && configError && (
          <div className="status-card error">
            <h2>Configuration Error</h2>
            <p>{configError}</p>
            <p>
              Ensure the backend service is running and key-pair variables such as `SNOWFLAKE_AGENT_NAME` and
              `SNOWFLAKE_PRIVATE_KEY_PATH` are populated in `config/.env`.
            </p>
          </div>
        )}

        {!loadingConfig && !configError && agentConfig && (
          <>
            {activeView === 'chat' ? (
              <ChatInterface config={agentConfig} />
            ) : (
              <DocumentSummaryPanel />
            )}
          </>
        )}
      </main>
    </div>
  );
}

export default App;
