import { Bookmark, Dumbbell, Flame, Plus, Trash2 } from "lucide-react";
import { useState, type FormEvent } from "react";
import { Modal } from "../components/Modal";
import { formatNumber } from "../domain";
import { useAppStore } from "../store/AppStore";

export function WorkoutsScreen() {
  const { entities, saveEntity, deleteEntity } = useAppStore();
  const workouts = entities("workout.logs").sort((a, b) => b.timestamp.localeCompare(a.timestamp));
  const [addOpen, setAddOpen] = useState(false);
  const totalSets = workouts.reduce((sum, workout) => sum + workout.sets.length, 0);
  const totalReps = workouts.reduce((sum, workout) => sum + workout.sets.reduce((setSum, set) => setSum + set.reps, 0), 0);
  const totalCalories = workouts.reduce((sum, workout) => sum + workout.caloriesBurned, 0);

  async function addWorkout(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    const id = crypto.randomUUID();
    const setCount = Number(data.get("sets")) || 3;
    const reps = Number(data.get("reps")) || 8;
    const weightKg = Number(data.get("weight")) || 0;
    await saveEntity("workout.logs", id, {
      id,
      timestamp: new Date().toISOString(),
      name: String(data.get("name") || "Workout"),
      category: String(data.get("category") || "Strength"),
      sets: Array.from({ length: setCount }, () => ({ weightKg, reps })),
      caloriesBurned: Number(data.get("calories")) || 0,
      saved: false,
    });
    setAddOpen(false);
  }

  return (
    <div className="standard-screen workout-screen">
      <header className="standard-header"><div><p>Training diary</p><h1>Workouts</h1></div><button className="primary-button" type="button" onClick={() => setAddOpen(true)}><Plus /> Add Workout</button></header>
      <section className="workout-summary">
        <div><span><Dumbbell /></span><small>Workouts</small><strong>{workouts.length}</strong></div>
        <div><span>≡</span><small>Sets</small><strong>{totalSets}</strong></div>
        <div><span>↔</span><small>Reps</small><strong>{totalReps}</strong></div>
        <div><span><Flame /></span><small>Burn</small><strong>{formatNumber(totalCalories, 0)} kcal</strong></div>
      </section>
      <div className="workout-list">
        {workouts.length === 0 ? <div className="empty-state"><Dumbbell /><h3>No workouts yet</h3><p>Add your first training entry.</p></div> : workouts.map((workout) => (
          <article className="workout-card" key={workout.id}>
            <div className="workout-icon"><Dumbbell /></div>
            <div className="workout-copy"><time>{new Date(workout.timestamp).toLocaleDateString(undefined, { weekday: "long", month: "short", day: "numeric" })}</time><h2>{workout.name}</h2><p>{workout.category} · {workout.sets.length} sets · {workout.sets.reduce((sum, set) => sum + set.reps, 0)} reps</p></div>
            <strong>{workout.caloriesBurned} kcal</strong>
            <div className="workout-actions">
              <button className={workout.saved ? "is-saved" : ""} type="button" aria-label={workout.saved ? "Remove from saved" : "Save workout"} onClick={() => void saveEntity("workout.logs", workout.id, { ...workout, saved: !workout.saved })}><Bookmark fill={workout.saved ? "currentColor" : "none"} /></button>
              <button type="button" aria-label="Delete workout" onClick={() => void deleteEntity("workout.logs", workout.id)}><Trash2 /></button>
            </div>
          </article>
        ))}
      </div>
      {addOpen ? (
        <Modal title="Add Workout" onClose={() => setAddOpen(false)}>
          <form className="form-stack" onSubmit={addWorkout}>
            <label className="field">Workout name<input name="name" required autoFocus placeholder="Upper Body" /></label>
            <label className="field">Category<select name="category"><option>Strength</option><option>Cardio</option><option>Mobility</option><option>Sport</option></select></label>
            <div className="form-grid four"><label className="field">Sets<input name="sets" type="number" min="1" defaultValue="3" /></label><label className="field">Reps<input name="reps" type="number" min="1" defaultValue="8" /></label><label className="field">kg<input name="weight" type="number" min="0" step="0.5" defaultValue="20" /></label><label className="field">kcal<input name="calories" type="number" min="0" defaultValue="150" /></label></div>
            <button className="primary-button full" type="submit">Add workout</button>
          </form>
        </Modal>
      ) : null}
    </div>
  );
}
