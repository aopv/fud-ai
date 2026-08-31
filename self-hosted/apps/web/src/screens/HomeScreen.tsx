import { Droplets, LockKeyhole, Plus, Timer } from "lucide-react";
import { useMemo, useState } from "react";
import { CalorieGauge } from "../components/CalorieGauge";
import { DateStrip } from "../components/DateStrip";
import { DiaryPanel } from "../components/DiaryPanel";
import { MacroBars } from "../components/MacroBars";
import { Modal } from "../components/Modal";
import { isSameLocalDay, nutrientTotals } from "../domain";
import { useAppStore } from "../store/AppStore";

export function HomeScreen() {
  const { profile, entities, syncState } = useAppStore();
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [addOpen, setAddOpen] = useState(false);
  const [moreOpen, setMoreOpen] = useState(false);
  const foods = entities("food.logs").filter((entry) => isSameLocalDay(entry.timestamp, selectedDate));
  const water = entities("water.logs").filter((entry) => isSameLocalDay(entry.timestamp, selectedDate));
  const activeFast = entities("fasting.logs").find((entry) => entry.status === "active");
  const totals = useMemo(() => nutrientTotals(foods), [foods]);
  const waterTotal = water.reduce((total, entry) => total + entry.milliliters, 0);

  return (
    <div className="home-screen">
      <section className="overview-column">
        <header className="mobile-brand-row">
          <div className="brand"><img src="/favicon-32.png" alt="" /><span>Fud AI</span></div>
          <button className={`mobile-sync sync-${syncState}`} type="button" aria-label="Open sync settings" onClick={() => { window.location.hash = "settings"; }}>
            <span /> <LockKeyhole />
          </button>
        </header>
        <div className="screen-title-row">
          <div><h1>Today</h1><p>{selectedDate.toLocaleDateString(undefined, { month: "long", day: "numeric", year: "numeric" })}</p></div>
        </div>
        <DateStrip selected={selectedDate} onSelect={setSelectedDate} />
        <CalorieGauge consumed={totals.calories} goal={profile.calories} />
        <MacroBars totals={totals} goals={profile} onViewMore={() => setMoreOpen(true)} />
      </section>
      <DiaryPanel selectedDate={selectedDate} addOpen={addOpen} onAddOpenChange={setAddOpen} />
      <button className="floating-add" type="button" aria-label="Add food" onClick={() => setAddOpen(true)}><Plus /></button>

      {moreOpen ? (
        <Modal title="Daily details" onClose={() => setMoreOpen(false)}>
          <div className="detail-list">
            <div><span className="detail-icon"><Droplets /></span><span><strong>Water</strong><small>{waterTotal.toLocaleString()} / {profile.waterGoalMl.toLocaleString()} ml</small></span><b>{Math.round((waterTotal / profile.waterGoalMl) * 100) || 0}%</b></div>
            <div><span className="detail-icon"><Timer /></span><span><strong>Fasting</strong><small>{activeFast ? "Fast in progress" : "No active fast"}</small></span><b>{activeFast ? `${activeFast.targetHours}h` : "—"}</b></div>
            <div><span className="detail-icon"><LockKeyhole /></span><span><strong>Storage</strong><small>Your diary remains on this device</small></span><b>Private</b></div>
          </div>
        </Modal>
      ) : null}
    </div>
  );
}
