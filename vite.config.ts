/// <reference types="vitest" />
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  plugins: [react(), tailwindcss()],
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: './src/test/setup.ts',
  },
  optimizeDeps: {
    exclude: ['@bytecodealliance/preview2-shim', '@bytecodealliance/jco'],
  },
  build: {
    target: 'esnext',
  },
  assetsInclude: ['**/*.wasm'],
  server: {
    fs: {
      // node_modules 内の WASM ファイルへのアクセスを許可
      allow: ['..'],
    },
  },
});
