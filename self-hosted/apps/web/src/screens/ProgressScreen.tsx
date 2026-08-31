import { CirclePlus, Scale } from "lucide-react";
import { useMemo, useState, type FormEvent } from "react";
import { LineChart } from "../components/LineChart";
import { Modal } from "../components/Modal";
import { formatNumber } from "../domain";
import { useAppStore } from "../store/AppStore";

type Metric = "weight" | "bodyfat";
type DateRange = "1W" | "1M" | "3M" | "6M" | "1Y" | "All";

const RANGE_DAYS: Record<Exclude<DateRange, "All">, number> = {
  "1W": 7,
  "1M": 30,
  "3M": 90,
  "6M": 183,
  "1Y": 365,
};

export function ProgressScreen() {
  const { entities, saveEntity } = useAppStore();
  const [metric, setMetric] = useState<Metric>("weight");
  const [range, setRange] = useState<DateRange>("1M");
  const [logOpen, setLogOpen] = useState(false);
  const weights = entities("weight.logs").sort((a, b) => a.timestamp.localeCompare(b.timestamp));
  const bodyFat = entities("bodyfat.logs").sort((a, b) => a.timestamp.localeCompare(b.timestamp));
  const series = useMemo(() => {
    const source = metric === "weight" ? weights : bodyFat;
    const cutoff = range === "All"
      ? Number.NEGATIVE_INFINITY
      : Date.now() - (RANGE_DAYS[range] * 24 * 60 * 60 * 1_000);
    const visible = source.filter((entry) => new Date(entry.timestamp).getTime() >= cutoff);
    return metric === "weight" ? (visible as typeof weights).map((entry) => ({
    label: new Date(entry.timestamp).toLocaleDateString(undefined, { month: "short", day: "numeric" }),
    value: entry.kilograms,
  })) : (visible as typeof bodyFat).map((entry) => ({
    label: new Date(entry.timestamp).toLocaleDateString(undefined, { month: "short", day: "numeric" }),
    value: entry.percentage,
  }));
  }, [bodyFat, metric, range, weights]);
  const current = series.at(-1)?.value ?? 0;
  const first = series[0]?.value ?? current;
  const change = current - first;
  const average = series.length ? series.reduce((sum, point) => sum + point.value, 0) / series.length : 0;

  async function logMetric(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    const id = crypto.randomUUID();
    const timestamp = new Date().toISOString();
    if (metric === "weight") {
      await saveEntity("weight.logs", id, { id, timestamp, kilograms: Number(data.get("value")) });
    } else {
      await saveEntity("bodyfat.logs", id, { id, timestamp, percentage: Number(data.get("value")) });
    }
    setLogOpen(false);
  }

  return (
    <div className="standard-screen progress-screen">
      <header className="standard-header"><div><p>Long-term trends</p><h1>Progress</h1></div><button className="primary-button" type="button" onClick={() => setLogOpen(true)}><CirclePlus /> Log {metric === "weight" ? "Weight" : "Body Fat"}</button></header>
      <div className="range-control" role="group" aria-label="Date range">
        {(["1W", "1M", "3M", "6M", "1Y", "All"] as const).map((item) => <button key={item} type="button" className={range === item ? "is-selected" : ""} onClick={() => setRange(item)}>{item}</button>)}
      </div>
      <div className="segmented-control metric-switch" role="group" aria-label="Progress metric">
        <button type="button" className={metric === "weight" ? "is-selected" : ""} onClick={() => setMetric("weight")}>Weight</button>
        <button type="button" className={metric === "bodyfat" ? "is-selected" : ""} onClick={() => setMetric("bodyfat")}>Body Fat</button>
      </div>
      <section className="metric-card">
        <header><div><Scale /><h2>{metric === "weight" ? "Weight" : "Body Fat"}</h2></div><button className="text-action" type="button" onClick={() => setLogOpen(true)}><CirclePlus /> Log</button></header>
        <div className="metric-stats">
          <div><strong>{formatNumber(current)} {metric === "weight" ? "kg" : "%"}</strong><span>Current</span></div>
          <div><strong className={change < 0 ? "positive-change" : ""}>{change > 0 ? "+" : ""}{formatNumber(change)} {metric === "weight" ? "kg" : "%"}</strong><span>Net Change</span></div>
          <div><strong>{formatNumber(average)} {metric === "weight" ? "kg" : "%"}</strong><span>Average</span></div>
        </div>
        <LineChart points={series} unit={metric === "weight" ? "kg" : "%"} emptyMessage={`Log another ${metric === "weight" ? "weight" : "body fat"} entry to see a trend.`} />
      </section>
      <section className="history-list">
        <h2>{metric === "weight" ? "Weight" : "Body Fat"} History</h2>
        {[...series].reverse().slice(0, 8).map((point, index) => (
          <div key={`${point.label}-${index}`}><span>{point.label}</span><strong>{formatNumber(point.value)} {metric === "weight" ? "kg" : "%"}</strong></div>
        ))}
      </section>
      {logOpen ? (
        <Modal title={`Log ${metric === "weight" ? "Weight" : "Body Fat"}`} onClose={() => setLogOpen(false)}>
          <form className="form-stack" onSubmit={logMetric}>
            <label className="field">{metric === "weight" ? "Kilograms" : "Percentage"}<input autoFocus required name="value" type="number" step="0.1" min="1" defaultValue={current || (metric === "weight" ? 70 : 18)} /></label>
            <button className="primary-button full" type="submit">Save entry</button>
          </form>
        </Modal>
      ) : null}
    </div>
  );
}
