import { useEffect, useRef, useState } from "react";
import { Terminal } from "./components/Terminal";
import clsx from "clsx";

export function App() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [mousePosition, setMousePosition] = useState<{
    x: number;
    y: number;
  }>({ x: document.body.clientWidth / 2, y: document.body.clientHeight });

  const [isOpen, setIsOpen] = useState(false);

  useEffect(() => {
    if (isOpen) {
      return;
    }

    let requestId: number;
    const loop = () => {
      if (!canvasRef.current) {
        return;
      }

      const canvas = canvasRef.current;
      const ctx = canvas.getContext("2d");
      if (!ctx) {
        return;
      }

      ctx.clearRect(0, 0, canvas.width, canvas.height);
      drawIcon(ctx, mousePosition ?? { x: 0, y: 0 });

      requestId = requestAnimationFrame(loop);
    };

    requestId = requestAnimationFrame(loop);

    return () => {
      cancelAnimationFrame(requestId);
    };
  }, [mousePosition, isOpen]);

  return (
    <div
      className="h-screen font-mono flex justify-center items-center bg-term-quote"
      onMouseMove={(e) => setMousePosition({ x: e.clientX, y: e.clientY })}
    >
      <div
        className={clsx(
          "transition-all",
          "duration-75",
          "bg-term-border",
          "text-base",
          "border-term-border",
          "border-8",
          {
            "w-full h-full sm:w-11/12 sm:h-11/12 sm:rounded-md": isOpen,
            "w-28 h-24 cursor-pointer rounded-md": !isOpen,
          }
        )}
        onClick={() => setIsOpen(true)}
      >
        {isOpen ? (
          <Terminal onClose={() => setIsOpen(false)} />
        ) : (
          <canvas
            ref={canvasRef}
            className="w-full h-full rounded-md bg-term-bg"
            width={96}
            height={80}
          />
        )}
      </div>
    </div>
  );
}

const drawIcon = (
  ctx: CanvasRenderingContext2D,
  mousePosition: { x: number; y: number }
) => {
  const windowCenter = {
    x: document.body.clientWidth / 2,
    y: document.body.clientHeight / 2,
  };

  const rad = Math.atan2(
    mousePosition.y - windowCenter.y,
    mousePosition.x - windowCenter.x
  );
  const x = Math.cos(rad);
  const y = Math.sin(rad);

  const canvasSize = { width: ctx.canvas.width, height: ctx.canvas.height };

  // 右目
  ctx.translate(
    canvasSize.width / 4 - canvasSize.width / 8,
    canvasSize.height / 3
  );
  drawEye(ctx, canvasSize.width / 4, canvasSize.height / 3, x, y);
  ctx.resetTransform();
  // 左目
  ctx.translate(
    (canvasSize.width / 4) * 3 - canvasSize.width / 8,
    canvasSize.height / 3
  );
  drawEye(ctx, canvasSize.width / 4, canvasSize.height / 3, x, y);
  ctx.resetTransform();
};

const drawEye = (
  ctx: CanvasRenderingContext2D,
  width: number,
  height: number,
  offsetX: number,
  offsetY: number
) => {
  ctx.save();

  ctx.strokeStyle = "red";

  ctx.fillStyle = "#ce9178";
  ctx.fillRect(0, 0, width, 2);

  ctx.beginPath();
  const x = width / 2 + (offsetX * width) / 4;
  const y = Math.max(0, (offsetY * height) / 3);
  ctx.ellipse(x, 0, width / 3, height / 3 + y, 0, 0, Math.PI);
  ctx.fill();

  ctx.restore();
};
