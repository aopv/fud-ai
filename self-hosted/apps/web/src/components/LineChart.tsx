interface ChartPoint {
  label: string;
  value: number;
}

interface LineChartProps {
  points: ChartPoint[];
  unit: string;
  emptyMessage: string;
}

export function LineChart({ points, unit, emptyMessage }: LineChartProps) {
  if (points.length < 2) {
    return <div className="chart-empty"><span>∙</span><p>{emptyMessage}</p></div>;
  }
  const values = points.map((point) => point.value);
  const minimum = Math.min(...values);
  const maximum = Math.max(...values);
  const range = Math.max(maximum - minimum, 0.5);
  const coordinates = points.map((point, index) => {
    const x = 8 + ((index / (points.length - 1)) * 84);
    const y = 82 - (((point.value - minimum) / range) * 64);
    return { ...point, x, y };
  });
  const polyline = coordinates.map((point) => `${point.x},${point.y}`).join(" ");
  return (
    <div className="line-chart">
      <svg viewBox="0 0 100 100" preserveAspectRatio="none" role="img" aria-label={`Values from ${minimum.toFixed(1)} to ${maximum.toFixed(1)} ${unit}`}>
        <defs>
          <linearGradient id="chart-fill" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="var(--accent)" stopOpacity="0.26" />
            <stop offset="1" stopColor="var(--accent)" stopOpacity="0" />
          </linearGradient>
        </defs>
        {[18, 39, 60, 82].map((y) => <line className="chart-grid" key={y} x1="5" x2="95" y1={y} y2={y} />)}
        <polygon className="chart-area" points={`8,82 ${polyline} 92,82`} />
        <polyline className="chart-line" points={polyline} />
        {coordinates.map((point) => <circle className="chart-point" key={`${point.label}-${point.x}`} cx={point.x} cy={point.y} r="1.3" />)}
      </svg>
      <div className="chart-labels"><span>{points[0]?.label}</span><span>{points.at(-1)?.label}</span></div>
    </div>
  );
}
