import { formatNumber, type Nutrients } from "../domain";

interface MacroBarsProps {
  totals: Nutrients;
  goals: Nutrients;
  onViewMore: () => void;
}

export function MacroBars({ totals, goals, onViewMore }: MacroBarsProps) {
  const macros = [
    { key: "protein", label: "Protein" },
    { key: "carbs", label: "Carbs" },
    { key: "fat", label: "Fat" },
    { key: "fiber", label: "Fiber" },
  ] as const;
  return (
    <section className="macro-panel" aria-label="Macronutrients">
      <div className="macro-grid">
        {macros.map(({ key, label }) => {
          const current = totals[key];
          const target = goals[key];
          const percentage = Math.min(100, target > 0 ? (current / target) * 100 : 0);
          return (
            <div className="macro" key={key}>
              <strong>{formatNumber(current)}</strong>
              <div className="macro-track" aria-hidden="true">
                <i style={{ height: `${percentage}%` }} />
              </div>
              <span>{label}</span>
              <small>/{formatNumber(target)}g</small>
            </div>
          );
        })}
      </div>
      <button className="text-action" type="button" onClick={onViewMore}>View More <span aria-hidden="true">›</span></button>
    </section>
  );
}
