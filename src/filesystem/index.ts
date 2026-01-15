import type { FileEntry, FileStat, FsError, Result, FileSystemNode, FileSystem } from './types';
import { getContentFiles, getDirectoryPaths } from './content-loader';

function ok<T>(val: T): Result<T, FsError> {
  return { tag: 'ok', val };
}

function err<T>(val: FsError): Result<T, FsError> {
  return { tag: 'err', val };
}

function normalizePath(path: string): string[] {
  const parts = path.split('/').filter((p) => p !== '' && p !== '.');
  const result: string[] = [];
  for (const part of parts) {
    if (part === '..') {
      result.pop();
    } else {
      result.push(part);
    }
  }
  return result;
}

function createDirectory(name: string): FileSystemNode {
  return { name, type: 'directory', children: new Map() };
}

function createFile(name: string, content: Uint8Array = new Uint8Array()): FileSystemNode {
  return { name, type: 'file', content };
}

export class VirtualFileSystem implements FileSystem {
  private root: FileSystemNode;

  constructor() {
    this.root = createDirectory('/');
    this.initDefaultStructure();
  }

  private initDefaultStructure(): void {
    // Create system directories (not part of content)
    this.mkdirInternal(['bin']);
    this.mkdirInternal(['etc']);
    this.mkdirInternal(['tmp']);

    // Load content files from src/content/
    const contentFiles = getContentFiles();

    // First, create all necessary directories
    const directories = getDirectoryPaths(contentFiles);
    for (const dir of directories) {
      const parts = dir.split('/').filter(Boolean);
      this.mkdirInternal(parts);
    }

    // Then, create all files
    for (const file of contentFiles) {
      const parts = file.path.split('/').filter(Boolean);
      const content = new TextEncoder().encode(file.content);
      this.writeFileInternal(parts, content);
    }
  }

  private mkdirInternal(pathParts: string[]): void {
    let current = this.root;
    for (const part of pathParts) {
      if (!current.children) {
        current.children = new Map();
      }
      if (!current.children.has(part)) {
        current.children.set(part, createDirectory(part));
      }
      current = current.children.get(part)!;
    }
  }

  private writeFileInternal(pathParts: string[], content: Uint8Array): void {
    if (pathParts.length === 0) return;

    const dirParts = pathParts.slice(0, -1);
    const fileName = pathParts[pathParts.length - 1];

    let current = this.root;
    for (const part of dirParts) {
      if (!current.children?.has(part)) return;
      current = current.children.get(part)!;
    }

    if (!current.children) {
      current.children = new Map();
    }
    current.children.set(fileName, createFile(fileName, content));
  }

  private resolve(pathParts: string[]): FileSystemNode | null {
    let current = this.root;
    for (const part of pathParts) {
      if (current.type !== 'directory' || !current.children?.has(part)) {
        return null;
      }
      current = current.children.get(part)!;
    }
    return current;
  }

  listDir(path: string): Result<FileEntry[], FsError> {
    const parts = normalizePath(path);
    const node = this.resolve(parts);

    if (!node) {
      return err({ tag: 'not-found' });
    }
    if (node.type !== 'directory') {
      return err({ tag: 'is-file' });
    }

    const entries: FileEntry[] = [];
    if (node.children) {
      for (const [name, child] of node.children) {
        entries.push({ name, isDir: child.type === 'directory' });
      }
    }
    return ok(entries);
  }

  readFile(path: string): Result<Uint8Array, FsError> {
    const parts = normalizePath(path);
    const node = this.resolve(parts);

    if (!node) {
      return err({ tag: 'not-found' });
    }
    if (node.type !== 'file') {
      return err({ tag: 'is-directory' });
    }

    return ok(node.content ?? new Uint8Array());
  }

  writeFile(path: string, data: Uint8Array): Result<void, FsError> {
    const parts = normalizePath(path);
    if (parts.length === 0) {
      return err({ tag: 'permission-denied' });
    }

    const dirParts = parts.slice(0, -1);
    const fileName = parts[parts.length - 1];
    const parent = this.resolve(dirParts);

    if (!parent) {
      return err({ tag: 'not-found' });
    }
    if (parent.type !== 'directory') {
      return err({ tag: 'is-file' });
    }

    const existing = parent.children?.get(fileName);
    if (existing && existing.type === 'directory') {
      return err({ tag: 'is-directory' });
    }

    if (!parent.children) {
      parent.children = new Map();
    }
    parent.children.set(fileName, createFile(fileName, data));
    return ok(undefined);
  }

  mkdir(path: string): Result<void, FsError> {
    const parts = normalizePath(path);
    if (parts.length === 0) {
      return err({ tag: 'permission-denied' });
    }

    const dirParts = parts.slice(0, -1);
    const dirName = parts[parts.length - 1];
    const parent = this.resolve(dirParts);

    if (!parent) {
      return err({ tag: 'not-found' });
    }
    if (parent.type !== 'directory') {
      return err({ tag: 'is-file' });
    }
    if (parent.children?.has(dirName)) {
      return err({ tag: 'permission-denied' });
    }

    if (!parent.children) {
      parent.children = new Map();
    }
    parent.children.set(dirName, createDirectory(dirName));
    return ok(undefined);
  }

  remove(path: string): Result<void, FsError> {
    const parts = normalizePath(path);
    if (parts.length === 0) {
      return err({ tag: 'permission-denied' });
    }

    const dirParts = parts.slice(0, -1);
    const name = parts[parts.length - 1];
    const parent = this.resolve(dirParts);

    if (!parent) {
      return err({ tag: 'not-found' });
    }
    if (parent.type !== 'directory' || !parent.children?.has(name)) {
      return err({ tag: 'not-found' });
    }

    parent.children.delete(name);
    return ok(undefined);
  }

  stat(path: string): Result<FileStat, FsError> {
    const parts = normalizePath(path);
    const node = this.resolve(parts);

    if (!node) {
      return err({ tag: 'not-found' });
    }

    const size = node.type === 'file' ? BigInt(node.content?.length ?? 0) : 0n;
    return ok({
      name: node.name,
      isDir: node.type === 'directory',
      size,
    });
  }

  exists(path: string): boolean {
    const parts = normalizePath(path);
    return this.resolve(parts) !== null;
  }
}

// Singleton instance
let fsInstance: VirtualFileSystem | null = null;

export function getFileSystem(): VirtualFileSystem {
  if (!fsInstance) {
    fsInstance = new VirtualFileSystem();
  }
  return fsInstance;
}
