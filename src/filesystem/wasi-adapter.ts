/**
 * WASI preview2 filesystem adapter
 * VirtualFileSystem を WASI インターフェースに適合させる
 */

import { getFileSystem, VirtualFileSystem } from './index';

// Types
export type Filesize = bigint;
export type LinkCount = bigint;

export type DescriptorType =
  | 'unknown'
  | 'block-device'
  | 'character-device'
  | 'directory'
  | 'fifo'
  | 'symbolic-link'
  | 'regular-file'
  | 'socket';

export type ErrorCode =
  | 'access'
  | 'would-block'
  | 'already'
  | 'bad-descriptor'
  | 'busy'
  | 'deadlock'
  | 'quota'
  | 'exist'
  | 'file-too-large'
  | 'illegal-byte-sequence'
  | 'in-progress'
  | 'interrupted'
  | 'invalid'
  | 'io'
  | 'is-directory'
  | 'loop'
  | 'too-many-links'
  | 'message-size'
  | 'name-too-long'
  | 'no-device'
  | 'no-entry'
  | 'no-lock'
  | 'insufficient-memory'
  | 'insufficient-space'
  | 'not-directory'
  | 'not-empty'
  | 'not-recoverable'
  | 'unsupported'
  | 'no-tty'
  | 'no-such-device'
  | 'overflow'
  | 'not-permitted'
  | 'pipe'
  | 'read-only'
  | 'invalid-seek'
  | 'text-file-busy'
  | 'cross-device';

export interface Datetime {
  seconds: bigint;
  nanoseconds: number;
}

export interface DescriptorStat {
  type: DescriptorType;
  linkCount: LinkCount;
  size: Filesize;
  dataAccessTimestamp?: Datetime;
  dataModificationTimestamp?: Datetime;
  statusChangeTimestamp?: Datetime;
}

export interface DirectoryEntry {
  type: DescriptorType;
  name: string;
}

export interface DescriptorFlags {
  read?: boolean;
  write?: boolean;
  fileIntegritySync?: boolean;
  dataIntegritySync?: boolean;
  requestedWriteSync?: boolean;
  mutateDirectory?: boolean;
}

export interface PathFlags {
  symlinkFollow?: boolean;
}

export interface OpenFlags {
  create?: boolean;
  directory?: boolean;
  exclusive?: boolean;
  truncate?: boolean;
}

// Error class for filesystem errors
class FilesystemError extends Error {
  constructor(public code: ErrorCode) {
    super(`Filesystem error: ${code}`);
    this.name = 'FilesystemError';
  }
}

// DirectoryEntryStream implementation
export class DirectoryEntryStream {
  private entries: DirectoryEntry[];
  private index: number = 0;

  constructor(entries: DirectoryEntry[]) {
    this.entries = entries;
  }

  readDirectoryEntry(): DirectoryEntry | undefined {
    if (this.index >= this.entries.length) {
      return undefined;
    }
    return this.entries[this.index++];
  }
}

// Dummy InputStream/OutputStream for now
export class InputStream {
  private data: Uint8Array;
  private offset: number;

  constructor(data: Uint8Array, offset: number = 0) {
    this.data = data;
    this.offset = offset;
  }

  read(len: bigint): Uint8Array {
    const length = Number(len);
    const result = this.data.slice(this.offset, this.offset + length);
    this.offset += result.length;
    return result;
  }

  blockingRead(len: bigint): Uint8Array {
    return this.read(len);
  }
}

export class OutputStream {
  private fs: VirtualFileSystem;
  private path: string;
  private offset: number;

  constructor(fs: VirtualFileSystem, path: string, offset: number = 0) {
    this.fs = fs;
    this.path = path;
    this.offset = offset;
  }

  write(data: Uint8Array): bigint {
    const result = this.fs.readFile(this.path);
    let content: Uint8Array;

    if (result.tag === 'ok') {
      // Append or overwrite
      const existing = result.val;
      const newSize = Math.max(existing.length, this.offset + data.length);
      content = new Uint8Array(newSize);
      content.set(existing);
      content.set(data, this.offset);
    } else {
      content = data;
    }

    this.fs.writeFile(this.path, content);
    this.offset += data.length;
    return BigInt(data.length);
  }

  blockingWriteAndFlush(data: Uint8Array): void {
    this.write(data);
  }

  blockingFlush(): void {
    // No-op for virtual filesystem
  }
}

// Descriptor implementation
export class Descriptor {
  private fs: VirtualFileSystem;
  private path: string;
  private flags: DescriptorFlags;

  constructor(fs: VirtualFileSystem, path: string, flags: DescriptorFlags = { read: true }) {
    this.fs = fs;
    this.path = path;
    this.flags = flags;
  }

  private resolvePath(relativePath: string): string {
    if (relativePath.startsWith('/')) {
      return relativePath;
    }
    if (this.path === '/') {
      return '/' + relativePath;
    }
    return this.path + '/' + relativePath;
  }

  readViaStream(offset: Filesize): InputStream {
    const result = this.fs.readFile(this.path);
    if (result.tag === 'err') {
      throw new FilesystemError('no-entry');
    }
    return new InputStream(result.val, Number(offset));
  }

  writeViaStream(offset: Filesize): OutputStream {
    return new OutputStream(this.fs, this.path, Number(offset));
  }

  appendViaStream(): OutputStream {
    const result = this.fs.readFile(this.path);
    const offset = result.tag === 'ok' ? result.val.length : 0;
    return new OutputStream(this.fs, this.path, offset);
  }

  advise(): void {
    // No-op
  }

  syncData(): void {
      }

  getFlags(): DescriptorFlags {
    return this.flags;
  }

  getType(): DescriptorType {
    const result = this.fs.stat(this.path);
    if (result.tag === 'err') {
      return 'unknown';
    }
    return result.val.isDir ? 'directory' : 'regular-file';
  }

  setSize(_size: Filesize): void {
    // Not fully implemented
  }

  setTimes(): void {
    // Not implemented
  }

  read(length: Filesize, offset: Filesize): [Uint8Array, boolean] {
    const result = this.fs.readFile(this.path);
    if (result.tag === 'err') {
      throw new FilesystemError('no-entry');
    }

    const data = result.val;
    const start = Number(offset);
    const end = Math.min(start + Number(length), data.length);
    const chunk = data.slice(start, end);
    const eof = end >= data.length;

    return [chunk, eof];
  }

  write(buffer: Uint8Array, offset: Filesize): Filesize {
    const result = this.fs.readFile(this.path);
    let content: Uint8Array;
    const off = Number(offset);

    if (result.tag === 'ok') {
      const existing = result.val;
      const newSize = Math.max(existing.length, off + buffer.length);
      content = new Uint8Array(newSize);
      content.set(existing);
      content.set(buffer, off);
    } else {
      content = new Uint8Array(off + buffer.length);
      content.set(buffer, off);
    }

    this.fs.writeFile(this.path, content);
    return BigInt(buffer.length);
  }

  readDirectory(): DirectoryEntryStream {
    const result = this.fs.listDir(this.path);
    if (result.tag === 'err') {
      throw new FilesystemError('no-entry');
    }

    const entries: DirectoryEntry[] = result.val.map((entry) => ({
      type: entry.isDir ? 'directory' : 'regular-file',
      name: entry.name,
    }));

    return new DirectoryEntryStream(entries);
  }

  sync(): void {
      }

  createDirectoryAt(path: string): void {
    const fullPath = this.resolvePath(path);
    const result = this.fs.mkdir(fullPath);
    if (result.tag === 'err') {
      throw new FilesystemError('no-entry');
    }
      }

  stat(): DescriptorStat {
    const result = this.fs.stat(this.path);
    if (result.tag === 'err') {
      throw new FilesystemError('no-entry');
    }

    const now: Datetime = {
      seconds: BigInt(Math.floor(Date.now() / 1000)),
      nanoseconds: (Date.now() % 1000) * 1000000,
    };

    return {
      type: result.val.isDir ? 'directory' : 'regular-file',
      linkCount: 1n,
      size: result.val.size,
      dataAccessTimestamp: now,
      dataModificationTimestamp: now,
      statusChangeTimestamp: now,
    };
  }

  statAt(_pathFlags: PathFlags, path: string): DescriptorStat {
    const fullPath = this.resolvePath(path);
    const result = this.fs.stat(fullPath);
    if (result.tag === 'err') {
      throw new FilesystemError('no-entry');
    }

    const now: Datetime = {
      seconds: BigInt(Math.floor(Date.now() / 1000)),
      nanoseconds: (Date.now() % 1000) * 1000000,
    };

    return {
      type: result.val.isDir ? 'directory' : 'regular-file',
      linkCount: 1n,
      size: result.val.size,
      dataAccessTimestamp: now,
      dataModificationTimestamp: now,
      statusChangeTimestamp: now,
    };
  }

  setTimesAt(): void {
    // Not implemented
  }

  linkAt(): void {
    throw new FilesystemError('unsupported');
  }

  openAt(
    _pathFlags: PathFlags,
    path: string,
    openFlags: OpenFlags,
    flags: DescriptorFlags
  ): Descriptor {
    const fullPath = this.resolvePath(path);

    if (openFlags.create) {
      if (!this.fs.exists(fullPath)) {
        this.fs.writeFile(fullPath, new Uint8Array());
              }
    }

    if (!this.fs.exists(fullPath)) {
      throw new FilesystemError('no-entry');
    }

    if (openFlags.truncate) {
      this.fs.writeFile(fullPath, new Uint8Array());
          }

    return new Descriptor(this.fs, fullPath, flags);
  }

  readlinkAt(): string {
    throw new FilesystemError('unsupported');
  }

  removeDirectoryAt(path: string): void {
    const fullPath = this.resolvePath(path);
    const result = this.fs.remove(fullPath);
    if (result.tag === 'err') {
      throw new FilesystemError('no-entry');
    }
      }

  renameAt(): void {
    throw new FilesystemError('unsupported');
  }

  symlinkAt(): void {
    throw new FilesystemError('unsupported');
  }

  unlinkFileAt(path: string): void {
    const fullPath = this.resolvePath(path);
    const result = this.fs.remove(fullPath);
    if (result.tag === 'err') {
      throw new FilesystemError('no-entry');
    }
      }

  isSameObject(other: Descriptor): boolean {
    return this.path === other.path;
  }

  metadataHash(): { lower: bigint; upper: bigint } {
    // Simple hash based on path
    let hash = 0n;
    for (let i = 0; i < this.path.length; i++) {
      hash = (hash * 31n + BigInt(this.path.charCodeAt(i))) % (2n ** 64n);
    }
    return { lower: hash, upper: 0n };
  }

  metadataHashAt(_pathFlags: PathFlags, path: string): { lower: bigint; upper: bigint } {
    const fullPath = this.resolvePath(path);
    let hash = 0n;
    for (let i = 0; i < fullPath.length; i++) {
      hash = (hash * 31n + BigInt(fullPath.charCodeAt(i))) % (2n ** 64n);
    }
    return { lower: hash, upper: 0n };
  }
}

// preopens module
export const preopens = {
  getDirectories(): Array<[Descriptor, string]> {
    const fs = getFileSystem();
    const rootDescriptor = new Descriptor(fs, '/', { read: true, write: true, mutateDirectory: true });
    return [[rootDescriptor, '/']];
  },
};

// types module
export const types = {
  Descriptor,
  DirectoryEntryStream,
  filesystemErrorCode(err: Error): ErrorCode | undefined {
    if (err instanceof FilesystemError) {
      return err.code;
    }
    return undefined;
  },
};

// Default export for jco mapping
export default {
  preopens,
  types,
};
