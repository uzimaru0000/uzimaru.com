import { useState } from 'react';
import type { RendererProps } from './types';

interface ImageProps {
  src: string;
  alt?: string;
  width?: number;
  height?: number;
}

export function ImageRenderer({ props }: RendererProps<ImageProps>) {
  const { src, alt = '', width, height } = props;
  const [error, setError] = useState(false);

  if (error) {
    return (
      <span className="text-term-error">
        [Image not found: {src}]
      </span>
    );
  }

  return (
    <div className="my-2">
      <img
        src={src}
        alt={alt}
        width={width}
        height={height}
        className="max-w-full rounded block"
        onError={() => setError(true)}
      />
    </div>
  );
}

export function isImageProps(props: unknown): props is ImageProps {
  return (
    typeof props === 'object' &&
    props !== null &&
    typeof (props as ImageProps).src === 'string'
  );
}
