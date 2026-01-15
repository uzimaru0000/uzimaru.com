/**
 * WASI Pollable Implementation
 *
 * Worker 内で Atomics.wait() を使ったブロッキング待機を実現するのだ。
 */

// SharedArrayBuffer を使ったブロッキング待機用バッファ
const waitBuffer = new Int32Array(new SharedArrayBuffer(4));

/**
 * カスタム Pollable クラス
 */
export class Pollable {
  durationNs: bigint = 0n;
}

/**
 * pollOne - 単一の Pollable を待機（戻り値なし）
 */
export function pollOne(pollable: unknown): void {
  const p = pollable as Pollable;
  if (p && p.durationNs && p.durationNs > 0n) {
    const durationMs = Number(p.durationNs / 1_000_000n);
    if (durationMs > 0) {
      Atomics.wait(waitBuffer, 0, 0, durationMs);
    }
  }
}

/**
 * pollList - 複数の Pollable を待機して、ready になったインデックスを返す
 */
export function pollList(list: unknown[]): Uint32Array {
  if (list && list.length > 0) {
    pollOne(list[0]);
    return new Uint32Array([0]);
  }
  return new Uint32Array([]);
}

/**
 * poll - pollList のエイリアス（Uint32Array を返す必要がある）
 */
export function poll(list: unknown[]): Uint32Array {
  return pollList(list);
}

/**
 * カスタム poll モジュール
 */
export const customPoll = {
  Pollable,
  pollOne,
  pollList,
  poll,
};

/**
 * カスタム monotonic clock モジュール
 */
export const customMonotonicClock = {
  resolution(): bigint {
    return 1_000_000n; // 1ms
  },
  now(): bigint {
    return BigInt(Math.floor(performance.now() * 1_000_000));
  },
  subscribeDuration(durationNs: bigint): Pollable {
    const p = new Pollable();
    p.durationNs = BigInt(durationNs);
    return p;
  },
  subscribeInstant(instant: bigint): Pollable {
    const now = BigInt(Math.floor(performance.now() * 1_000_000));
    const duration = BigInt(instant) > now ? BigInt(instant) - now : 0n;
    const p = new Pollable();
    p.durationNs = duration;
    return p;
  },
};
