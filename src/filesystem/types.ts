export interface FileEntry {
  name: string;
  isDir: boolean;
}

export interface FileStat {
  name: string;
  isDir: boolean;
  size: bigint;
}

export type FsError =
  | { tag: 'not-found' }
  | { tag: 'permission-denied' }
  | { tag: 'is-directory' }
  | { tag: 'is-file' };

export type Result<T, E> =
  | { tag: 'ok'; val: T }
  | { tag: 'err'; val: E };

export interface FileSystemNode {
  name: string;
  type: 'file' | 'directory';
  content?: Uint8Array;
  children?: Map<string, FileSystemNode>;
}

export interface FileSystem {
  listDir(path: string): Result<FileEntry[], FsError>;
  readFile(path: string): Result<Uint8Array, FsError>;
  writeFile(path: string, data: Uint8Array): Result<void, FsError>;
  mkdir(path: string): Result<void, FsError>;
  remove(path: string): Result<void, FsError>;
  stat(path: string): Result<FileStat, FsError>;
  exists(path: string): boolean;
}
