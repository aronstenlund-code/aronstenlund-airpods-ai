import { defineConfig } from 'vitest/config';

// A156 (D249): the web beta is served from earmind.vercel.app/beta. Kelly's site has `trailingSlash: false`, so the
// page is /beta (no slash) and relative asset paths would point at the site's root: the base is absolute.
// The build goes straight into site/beta/, which is what Vercel serves (no build step there).
export default defineConfig({
  base: '/beta/',
  build: {
    outDir: '../site/beta',
    emptyOutDir: true,
    target: 'es2020',
    assetsInlineLimit: 0,
    rollupOptions: {
      output: {
        // Stable names: the folder is committed, and a rebuild of the same source should give the same files.
        entryFileNames: 'assets/app.js',
        chunkFileNames: 'assets/[name].js',
        assetFileNames: 'assets/[name][extname]',
      },
    },
  },
  test: {
    include: ['tests/**/*.test.ts'],
    environment: 'node',
  },
});
