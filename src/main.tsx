import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { Amplify } from 'aws-amplify';
import { resolveAmplifyOutputs } from './amplifyConfig';
import App from './App';

Amplify.configure(resolveAmplifyOutputs());

createRoot(document.getElementById('root') as HTMLElement).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
