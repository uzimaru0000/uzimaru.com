/**
 * SharedArrayBuffer を使った stdout バッファ
 *
 * Worker からメインスレッドへ stdout データをリアルタイムでストリーミングするために使用。
 * Worker 側は write() でデータを書き込み、Atomics.notify() で通知。
 * メインスレッド側は Atomics.wait() でブロッキング読み取り、または poll で非ブロッキング読み取り。
 *
 * メモリレイアウト:
 * - [0-3]: write_index (Int32) - 次に書き込む位置
 * - [4-7]: read_index (Int32) - 次に読み取る位置
 * - [8-11]: status (Int32)
 *   - 0: running (実行中)
 *   - 1: completed (完了)
 * - [12-]: ring buffer (Uint8Array)
 */

export const STDOUT_STATUS = {
  RUNNING: 0,
  COMPLETED: 1,
} as const;

const HEADER_SIZE = 12;

/**
 * Worker 側で使用する stdout バッファ
 * データの書き込みを行う
 */
export class WorkerStdoutBuffer {
  private writeIndex: Int32Array;
  private readIndex: Int32Array;
  private status: Int32Array;
  private data: Uint8Array;
  private ringSize: number;

  constructor(buffer: SharedArrayBuffer) {
    this.writeIndex = new Int32Array(buffer, 0, 1);
    this.readIndex = new Int32Array(buffer, 4, 1);
    this.status = new Int32Array(buffer, 8, 1);
    this.data = new Uint8Array(buffer, HEADER_SIZE);
    this.ringSize = this.data.length;
  }

  /**
   * データを書き込んでメインスレッドに通知
   */
  write(bytes: Uint8Array): void {
    for (let i = 0; i < bytes.length; i++) {
      // リングバッファが満杯の場合は待機
      let writeIdx = Atomics.load(this.writeIndex, 0);
      let readIdx = Atomics.load(this.readIndex, 0);

      while ((writeIdx + 1) % this.ringSize === readIdx % this.ringSize) {
        // バッファが満杯、少し待つ
        Atomics.wait(this.readIndex, 0, readIdx, 1);
        readIdx = Atomics.load(this.readIndex, 0);
      }

      // データを書き込む
      this.data[writeIdx % this.ringSize] = bytes[i];
      Atomics.store(this.writeIndex, 0, (writeIdx + 1) % this.ringSize);
    }

    // メインスレッドに通知
    Atomics.notify(this.writeIndex, 0);
  }

  /**
   * 完了を通知
   */
  complete(): void {
    Atomics.store(this.status, 0, STDOUT_STATUS.COMPLETED);
    Atomics.notify(this.writeIndex, 0);
    Atomics.notify(this.status, 0);
  }
}

/**
 * メインスレッド側で使用する stdout バッファ
 * データの読み取りを行う
 */
export class MainThreadStdoutBuffer {
  private buffer: SharedArrayBuffer;
  private writeIndex: Int32Array;
  private readIndex: Int32Array;
  private status: Int32Array;
  private data: Uint8Array;
  private ringSize: number;

  constructor(size = 65536) {
    this.buffer = new SharedArrayBuffer(size + HEADER_SIZE);
    this.writeIndex = new Int32Array(this.buffer, 0, 1);
    this.readIndex = new Int32Array(this.buffer, 4, 1);
    this.status = new Int32Array(this.buffer, 8, 1);
    this.data = new Uint8Array(this.buffer, HEADER_SIZE);
    this.ringSize = this.data.length;

    // 初期化
    Atomics.store(this.writeIndex, 0, 0);
    Atomics.store(this.readIndex, 0, 0);
    Atomics.store(this.status, 0, STDOUT_STATUS.RUNNING);
  }

  /**
   * SharedArrayBuffer を取得（Worker に渡すため）
   */
  getBuffer(): SharedArrayBuffer {
    return this.buffer;
  }

  /**
   * データが利用可能かチェック
   */
  hasData(): boolean {
    const writeIdx = Atomics.load(this.writeIndex, 0);
    const readIdx = Atomics.load(this.readIndex, 0);
    return writeIdx !== readIdx;
  }

  /**
   * 完了したかチェック
   */
  isCompleted(): boolean {
    return Atomics.load(this.status, 0) === STDOUT_STATUS.COMPLETED;
  }

  /**
   * 利用可能なデータを全て読み取る（非ブロッキング）
   */
  read(): Uint8Array {
    const writeIdx = Atomics.load(this.writeIndex, 0);
    let readIdx = Atomics.load(this.readIndex, 0);

    if (writeIdx === readIdx) {
      return new Uint8Array(0);
    }

    const result: number[] = [];

    while (readIdx !== writeIdx) {
      result.push(this.data[readIdx]);
      readIdx = (readIdx + 1) % this.ringSize;
    }

    Atomics.store(this.readIndex, 0, readIdx);
    Atomics.notify(this.readIndex, 0);

    return new Uint8Array(result);
  }

  /**
   * 文字列として読み取る（非ブロッキング）
   */
  readString(): string {
    const bytes = this.read();
    if (bytes.length === 0) {
      return '';
    }
    return new TextDecoder().decode(bytes);
  }
}
