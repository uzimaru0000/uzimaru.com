/**
 * SharedArrayBuffer を使った stdin バッファ
 *
 * Worker とメインスレッド間で stdin データをやり取りするために使用。
 * Worker 側は Atomics.wait() でブロッキング読み取りを行い、
 * メインスレッド側は Atomics.notify() でデータの到着を通知する。
 *
 * メモリレイアウト:
 * - [0-3]: status (Int32)
 *   - 0: waiting (データ待ち)
 *   - 1: data available (データあり)
 *   - 2: EOF
 * - [4-7]: data length (Int32)
 * - [8-]: data bytes (Uint8Array)
 */

export const STDIN_STATUS = {
  WAITING: 0,
  DATA_AVAILABLE: 1,
  EOF: 2,
} as const;

/**
 * メインスレッド側で使用する stdin バッファ
 * データの書き込みと EOF 送信を行う
 *
 * メモリレイアウト（拡張版）:
 * - [0-3]: status (Int32)
 * - [4-7]: data length (Int32)
 * - [8-11]: read offset (Int32)
 * - [12-]: data bytes (Uint8Array)
 */
export class MainThreadStdinBuffer {
  private buffer: SharedArrayBuffer;
  private status: Int32Array;
  private length: Int32Array;
  private readOffset: Int32Array;
  private data: Uint8Array;

  constructor(size = 65536) {
    this.buffer = new SharedArrayBuffer(size + 12);
    this.status = new Int32Array(this.buffer, 0, 1);
    this.length = new Int32Array(this.buffer, 4, 1);
    this.readOffset = new Int32Array(this.buffer, 8, 1);
    this.data = new Uint8Array(this.buffer, 12);

    // 初期状態: waiting
    Atomics.store(this.status, 0, STDIN_STATUS.WAITING);
    Atomics.store(this.readOffset, 0, 0);
  }

  /**
   * SharedArrayBuffer を取得（Worker に渡すため）
   */
  getBuffer(): SharedArrayBuffer {
    return this.buffer;
  }

  /**
   * データを書き込んで Worker に通知
   */
  write(data: Uint8Array): void {
    if (data.length > this.data.length) {
      throw new Error(`Data too large: ${data.length} > ${this.data.length}`);
    }

    this.data.set(data);
    Atomics.store(this.length, 0, data.length);
    Atomics.store(this.status, 0, STDIN_STATUS.DATA_AVAILABLE);
    Atomics.notify(this.status, 0);
  }

  /**
   * 文字列を書き込む（便利メソッド）
   */
  writeString(str: string): void {
    this.write(new TextEncoder().encode(str));
  }

  /**
   * EOF を送信
   */
  sendEOF(): void {
    Atomics.store(this.status, 0, STDIN_STATUS.EOF);
    Atomics.notify(this.status, 0);
  }
}

/**
 * Worker 側で使用する stdin バッファ
 * 既存の SharedArrayBuffer から作成し、ブロッキング読み取りを行う
 *
 * メモリレイアウト（拡張版）:
 * - [0-3]: status (Int32)
 * - [4-7]: data length (Int32) - 書き込まれたデータの長さ
 * - [8-11]: read offset (Int32) - 読み取り済みオフセット
 * - [12-]: data bytes (Uint8Array)
 */
export class WorkerStdinBuffer {
  private status: Int32Array;
  private length: Int32Array;
  private readOffset: Int32Array;
  private data: Uint8Array;

  constructor(buffer: SharedArrayBuffer) {
    this.status = new Int32Array(buffer, 0, 1);
    this.length = new Int32Array(buffer, 4, 1);
    this.readOffset = new Int32Array(buffer, 8, 1);
    this.data = new Uint8Array(buffer, 12);
  }

  /**
   * データを読み取り（ブロッキング）
   *
   * データが来るまで待機し、データが来たら読み取って返す。
   * 部分読み取りに対応：まだデータが残っている場合は次のread()で続きを返す。
   * EOF の場合は空の Uint8Array を返す。
   */
  blockingRead(maxLen: number): Uint8Array {
    // 現在の status を取得
    let currentStatus = Atomics.load(this.status, 0);

    // status が WAITING の間はブロック
    while (currentStatus === STDIN_STATUS.WAITING) {
      Atomics.wait(this.status, 0, STDIN_STATUS.WAITING);
      currentStatus = Atomics.load(this.status, 0);
    }

    // EOF の場合は空配列を返す
    if (currentStatus === STDIN_STATUS.EOF) {
      return new Uint8Array(0);
    }

    // データを読み取る
    const dataLength = Atomics.load(this.length, 0);
    const offset = Atomics.load(this.readOffset, 0);
    const remaining = dataLength - offset;
    const readLength = Math.min(remaining, maxLen);
    const result = new Uint8Array(readLength);
    result.set(this.data.subarray(offset, offset + readLength));

    // オフセットを更新
    const newOffset = offset + readLength;
    Atomics.store(this.readOffset, 0, newOffset);

    // すべてのデータを読み取ったら WAITING に戻す
    if (newOffset >= dataLength) {
      Atomics.store(this.readOffset, 0, 0); // オフセットをリセット
      Atomics.store(this.status, 0, STDIN_STATUS.WAITING);
    }

    return result;
  }
}
