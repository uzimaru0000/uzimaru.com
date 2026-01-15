import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { App } from './App';
import { ensureInitialized } from './filesystem/init';
import './index.css';

// WASM バイナリを初期化してからアプリをレンダリング
ensureInitialized().then(() => {
  createRoot(document.getElementById('root')!).render(
    <StrictMode>
      <App />
    </StrictMode>
  );
});
