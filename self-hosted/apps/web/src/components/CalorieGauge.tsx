import { Flame } from "lucide-react";
import { formatNumber } from "../domain";

interface CalorieGaugeProps {
  consumed: number;
  goal: number;
}

export function CalorieGauge({ consumed, goal }: CalorieGaugeProps) {
  const ratio = goal > 0 ? consumed / goal : 0;
  const ticks = 39;
  const filledTicks = Math.min(ticks, Math.round(ratio * ticks));
  const remaining = goal - consumed;
  return (
    <section className="calorie-gauge" aria-label={`${formatNumber(consumed, 0)} of ${formatNumber(goal, 0)} calories`}>
      <svg viewBox="0 0 420 235" role="img" aria-hidden="true">
        <g transform="translate(210 205)">
          {Array.from({ length: ticks }, (_, index) => {
            const rotation = -90 + ((180 / (ticks - 1)) * index);
            return (
              <line
                key={rotation}
                className={index < filledTicks ? "is-filled" : ""}
                x1="0"
                y1="-174"
                x2="0"
                y2="-151"
                transform={`rotate(${rotation})`}
              />
            );
          })}
        </g>
      </svg>
      <div className="gauge-copy">
        <span>Calories</span>
        <strong>{formatNumber(consumed, 0)}</strong>
        <small className={remaining < 0 ? "is-over" : ""}>
          <Flame aria-hidden="true" />
          {formatNumber(Math.abs(remaining), 0)} {remaining < 0 ? "over" : "left"}
        </small>
      </div>
    </section>
  );
}
