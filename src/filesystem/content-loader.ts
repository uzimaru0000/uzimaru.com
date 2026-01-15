/**
 * Content file structure loaded via import.meta.glob
 */
export interface ContentFile {
  /** Virtual filesystem path (e.g., /home/uzimaru0000/profile) */
  path: string;
  /** File content as string */
  content: string;
}

/**
 * Binary file structure for WASM files
 */
export interface BinaryFile {
  /** Virtual filesystem path (e.g., /bin/echo.wasm) */
  path: string;
  /** URL to fetch the binary content */
  url: string;
}

// Use eager loading for small content files
// Pattern includes regular files (excluding .wasm)
const textModules = import.meta.glob<string>('/src/content/**/!(*.wasm)', {
  eager: true,
  query: '?raw',
  import: 'default',
});

// Also load dotfiles (hidden files starting with .)
const dotfileModules = import.meta.glob<string>('/src/content/**/.*', {
  eager: true,
  query: '?raw',
  import: 'default',
});

// Load WASM files as URLs
const wasmModules = import.meta.glob<string>('/src/content/**/*.wasm', {
  eager: true,
  query: '?url',
  import: 'default',
});

/**
 * Transform the glob path to a virtual filesystem path
 * e.g., "/src/content/home/uzimaru0000/profile" -> "/home/uzimaru0000/profile"
 */
function transformPath(globPath: string): string {
  const PREFIX = '/src/content';
  if (globPath.startsWith(PREFIX)) {
    return globPath.slice(PREFIX.length) || '/';
  }
  return globPath;
}

/**
 * Get all content files from the src/content directory
 */
export function getContentFiles(): ContentFile[] {
  const files: ContentFile[] = [];

  // Process regular files
  for (const [globPath, content] of Object.entries(textModules)) {
    files.push({
      path: transformPath(globPath),
      content: content as string,
    });
  }

  // Process dotfiles
  for (const [globPath, content] of Object.entries(dotfileModules)) {
    files.push({
      path: transformPath(globPath),
      content: content as string,
    });
  }

  return files;
}

/**
 * Get all WASM binary files from the src/content directory
 */
export function getBinaryFiles(): BinaryFile[] {
  const files: BinaryFile[] = [];

  for (const [globPath, url] of Object.entries(wasmModules)) {
    files.push({
      path: transformPath(globPath),
      url: url as string,
    });
  }

  return files;
}

/**
 * Extract unique directory paths from content files
 * Returns paths in creation order (parents before children)
 */
export function getDirectoryPaths(files: ContentFile[]): string[] {
  const dirs = new Set<string>();

  for (const file of files) {
    const parts = file.path.split('/').filter(Boolean);
    // Build directory paths incrementally
    let currentPath = '';
    for (let i = 0; i < parts.length - 1; i++) {
      currentPath += '/' + parts[i];
      dirs.add(currentPath);
    }
  }

  // Sort to ensure parent directories come before children
  return Array.from(dirs).sort((a, b) => {
    const depthA = a.split('/').length;
    const depthB = b.split('/').length;
    return depthA - depthB;
  });
}
