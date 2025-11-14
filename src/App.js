import React, { useEffect, useState } from 'react';
import DocumentIntelligence from './components/DocumentIntelligence';
import { fetchAgentConfig } from './services/snowflakeApi';
import './App.css';

function App() {
  const [agentConfig, setAgentConfig] = useState(null);
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
      {loadingConfig && (
        <div className="app-loading">
          <div className="loading-card">
            <h2>🔄 Loading Document Intelligence...</h2>
            <p>Connecting to Snowflake Cortex Agent</p>
          </div>
        </div>
      )}

      {!loadingConfig && configError && (
        <div className="app-error">
          <div className="error-card">
            <h2>⚠️ Configuration Error</h2>
            <p>{configError}</p>
            <p>
              Ensure the backend service is running and key-pair variables such as `SNOWFLAKE_AGENT_NAME` and
              `SNOWFLAKE_PRIVATE_KEY_PATH` are populated in `config/.env`.
            </p>
          </div>
        </div>
      )}

      {!loadingConfig && !configError && agentConfig && (
        <DocumentIntelligence config={agentConfig} />
      )}
    </div>
  );
}

export default App;
