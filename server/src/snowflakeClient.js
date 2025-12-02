/**
 * Snowflake Client - Connection and utility functions
 * 
 * Supports both password and key-pair authentication.
 * Key-pair auth is recommended for production use.
 */

import fs from 'fs';
import path from 'path';
import snowflake from 'snowflake-sdk';

let connectionPromise;

function getRequiredEnv(name) {
  const rawValue = process.env[name];
  const value = rawValue?.trim();
  if (!value) {
    throw new Error(`Missing environment variable: ${name}`);
  }
  return value;
}

function getOptionalEnv(name) {
  const value = process.env[name];
  return value && value.trim() ? value.trim() : undefined;
}

export function getSnowflakeConnection() {
  if (connectionPromise) {
    return connectionPromise;
  }

  const account = getRequiredEnv('SNOWFLAKE_ACCOUNT');
  const username = getRequiredEnv('SNOWFLAKE_USER');
  const database = getRequiredEnv('SNOWFLAKE_DATABASE');
  const schema = getRequiredEnv('SNOWFLAKE_SCHEMA');
  const role = getOptionalEnv('SNOWFLAKE_ROLE');
  const warehouse = getOptionalEnv('SNOWFLAKE_WAREHOUSE');
  const region = getOptionalEnv('SNOWFLAKE_REGION');
  const authType = getOptionalEnv('SNOWFLAKE_AUTH_TYPE') || 'password';

  const connectionConfig = {
    account,
    username,
    database,
    schema,
  };

  // Configure authentication
  if (authType === 'keypair') {
    const privateKeyPath = getRequiredEnv('SNOWFLAKE_PRIVATE_KEY_PATH');
    const privateKeyData = fs.readFileSync(privateKeyPath, 'utf8');
    connectionConfig.authenticator = 'SNOWFLAKE_JWT';
    connectionConfig.privateKey = privateKeyData;
  } else {
    // Default to password authentication
    const password = getRequiredEnv('SNOWFLAKE_PASSWORD');
    connectionConfig.password = password;
  }

  if (role) {
    connectionConfig.role = role;
  }
  if (warehouse) {
    connectionConfig.warehouse = warehouse;
  }
  if (region) {
    connectionConfig.region = region;
  }

  const connection = snowflake.createConnection(connectionConfig);

  connectionPromise = new Promise((resolve, reject) => {
    connection.connect((err) => {
      if (err) {
        reject(err);
      } else {
        resolve(connection);
      }
    });
  });

  return connectionPromise;
}

export async function execute(sqlText, binds = []) {
  const connection = await getSnowflakeConnection();
  return new Promise((resolve, reject) => {
    connection.execute({
      sqlText,
      binds,
      complete: (err, _stmt, rows) => {
        if (err) {
          reject(err);
        } else {
          resolve(rows);
        }
      },
    });
  });
}

export async function uploadFileToStage(localPath, stagePath) {
  const stage = getRequiredEnv('SNOWFLAKE_STAGE');
  const absolutePath = path.resolve(localPath);
  if (!fs.existsSync(absolutePath)) {
    throw new Error(`Local file does not exist: ${absolutePath}`);
  }
  const sql = `PUT file://${absolutePath} @${stage}/${stagePath} AUTO_COMPRESS=FALSE OVERWRITE=TRUE`;
  await execute(sql);
  return { stage, path: stagePath };
}

export async function downloadFileFromStage(stagePath, targetDir) {
  const stage = getRequiredEnv('SNOWFLAKE_STAGE');
  await fs.promises.mkdir(targetDir, { recursive: true });
  const sql = `GET @${stage}/${stagePath} file://${targetDir} OVERWRITE=TRUE`;
  const rows = await execute(sql);
  const fileName = rows?.[0]?.file || stagePath;
  const downloadedPath = path.join(targetDir, path.basename(fileName));
  if (!fs.existsSync(downloadedPath)) {
    throw new Error(`Failed to download file from stage to ${downloadedPath}`);
  }
  return downloadedPath;
}

export async function summarizeText(content, { prompt } = {}) {
  const basePrompt =
    prompt ||
    'Provide a concise executive summary of the following document focusing on key findings and next actions.';

  const sql = `
    SELECT AI_COMPLETE('mistral-large2', CONCAT(?, '\\n\\nDocument:\\n', ?)) AS summary
  `;

  const rows = await execute(sql, [basePrompt, content]);
  return rows?.[0]?.SUMMARY || '';
}

