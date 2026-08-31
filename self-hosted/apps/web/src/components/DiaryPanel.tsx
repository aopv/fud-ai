import { Droplets, EllipsisVertical, Heart, Moon, Plus, Sun, Sunrise, Trash2 } from "lucide-react";
import { useMemo, useState, type FormEvent } from "react";
import {
  displayMeal,
  formatNumber,
  isSameLocalDay,
  nutrientTotals,
  type FoodEntry,
  type MealType,
  type WaterEntry,
} from "../domain";
import { useAppStore } from "../store/AppStore";
import { Modal } from "./Modal";

const meals: MealType[] = ["breakfast", "lunch", "dinner", "snack"];

function mealIcon(meal: MealType) {
  if (meal === "breakfast") return <Sunrise />;
  if (meal === "lunch") return <Sun />;
  if (meal === "dinner") return <Moon />;
  return <span className="meal-emoji">✦</span>;
}

function mealForHour(hour: number): MealType {
  if (hour < 11) return "breakfast";
  if (hour < 16) return "lunch";
  if (hour < 22) return "dinner";
  return "snack";
}

interface DiaryPanelProps {
  selectedDate: Date;
  addOpen: boolean;
  onAddOpenChange: (open: boolean) => void;
}

export function DiaryPanel({ selectedDate, addOpen, onAddOpenChange }: DiaryPanelProps) {
  const { entities, saveEntity, deleteEntity } = useAppStore();
  const foodEntries = entities("food.logs").filter((entry) => isSameLocalDay(entry.timestamp, selectedDate));
  const waterEntries = entities("water.logs").filter((entry) => isSameLocalDay(entry.timestamp, selectedDate));
  const [editing, setEditing] = useState<FoodEntry | null>(null);

  const grouped = useMemo(() => meals.map((meal) => ({
    meal,
    foods: foodEntries.filter((entry) => entry.meal === meal).sort((a, b) => a.timestamp.localeCompare(b.timestamp)),
    waters: waterEntries.filter((entry) => mealForHour(new Date(entry.timestamp).getHours()) === meal),
  })).filter((group) => group.foods.length > 0 || group.waters.length > 0), [foodEntries, waterEntries]);

  async function saveEdited(entry: FoodEntry) {
    await saveEntity("food.logs", entry.id, entry);
    setEditing(null);
  }

  return (
    <section className="diary-panel">
      <header className="diary-heading">
        <div>
          <h2>Diary</h2>
          <p>{selectedDate.toLocaleDateString(undefined, { weekday: "long", month: "long", day: "numeric" })}</p>
        </div>
        <button className="primary-button compact" type="button" onClick={() => onAddOpenChange(true)}>
          <Plus /> Add Food
        </button>
      </header>

      <div className="meal-list">
        {grouped.length === 0 ? (
          <div className="empty-state">
            <span>🍽️</span>
            <h3>Nothing logged yet</h3>
            <p>Add food or water to start this day.</p>
            <button className="primary-button" type="button" onClick={() => onAddOpenChange(true)}><Plus /> Add Food</button>
          </div>
        ) : grouped.map(({ meal, foods, waters }) => {
          const totals = nutrientTotals(foods);
          return (
            <section className="meal-group" key={meal}>
              <header>
                <div className="meal-title">{mealIcon(meal)} <h3>{displayMeal(meal)}</h3></div>
                <div className="meal-total">
                  <strong>{formatNumber(totals.calories, 0)} kcal</strong>
                  <span>{formatNumber(totals.protein)}P · {formatNumber(totals.carbs)}C · {formatNumber(totals.fat)}F</span>
                </div>
              </header>
              <div className="meal-rows">
                {waters.map((water) => <WaterRow entry={water} key={water.id} onDelete={() => deleteEntity("water.logs", water.id)} />)}
                {foods.map((food) => <FoodRow entry={food} key={food.id} onEdit={() => setEditing(food)} />)}
              </div>
            </section>
          );
        })}
      </div>

      {addOpen ? <AddLogModal selectedDate={selectedDate} onClose={() => onAddOpenChange(false)} /> : null}
      {editing ? (
        <EditFoodModal
          entry={editing}
          onClose={() => setEditing(null)}
          onSave={saveEdited}
          onDelete={async () => {
            await deleteEntity("food.logs", editing.id);
            setEditing(null);
          }}
        />
      ) : null}
    </section>
  );
}

function FoodRow({ entry, onEdit }: { entry: FoodEntry; onEdit: () => void }) {
  return (
    <button className="diary-row" type="button" onClick={onEdit}>
      <span className="food-visual" aria-hidden="true">{entry.emoji || "🍽️"}</span>
      <span className="food-copy">
        <strong>{entry.name}{entry.favorite ? <Heart className="favorite-mark" fill="currentColor" /> : null}</strong>
        <span>{formatNumber(entry.quantity)} {entry.unit}</span>
        <small>
          <i>P {formatNumber(entry.protein)}g</i>
          <i>C {formatNumber(entry.carbs)}g</i>
          <i>F {formatNumber(entry.fat)}g</i>
        </small>
      </span>
      <span className="row-trailing">
        <strong>{formatNumber(entry.calories, 0)} kcal</strong>
        <time>{new Date(entry.timestamp).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })}</time>
        <EllipsisVertical aria-hidden="true" />
      </span>
    </button>
  );
}

function WaterRow({ entry, onDelete }: { entry: WaterEntry; onDelete: () => void }) {
  return (
    <div className="diary-row water-row">
      <span className="food-visual neutral" aria-hidden="true">💧</span>
      <span className="food-copy"><strong>Water</strong><span>{formatNumber(entry.milliliters, 0)} ml</span></span>
      <span className="row-trailing">
        <time>{new Date(entry.timestamp).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })}</time>
        <button className="row-delete" type="button" aria-label="Delete water log" onClick={onDelete}><Trash2 /></button>
      </span>
    </div>
  );
}

function dateWithTime(date: Date, time: string): string {
  const [hours = "12", minutes = "00"] = time.split(":");
  const value = new Date(date);
  value.setHours(Number(hours), Number(minutes), 0, 0);
  return value.toISOString();
}

function AddLogModal({ selectedDate, onClose }: { selectedDate: Date; onClose: () => void }) {
  const { saveEntity } = useAppStore();
  const [mode, setMode] = useState<"food" | "water">("food");
  const now = new Date();
  const [time, setTime] = useState(`${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`);

  async function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    const id = crypto.randomUUID();
    if (mode === "water") {
      await saveEntity("water.logs", id, {
        id,
        timestamp: dateWithTime(selectedDate, time),
        milliliters: Number(data.get("milliliters")) || 250,
      });
    } else {
      await saveEntity("food.logs", id, {
        id,
        name: String(data.get("name") || "Food"),
        meal: String(data.get("meal") || "snack") as MealType,
        timestamp: dateWithTime(selectedDate, time),
        quantity: Number(data.get("quantity")) || 1,
        unit: String(data.get("unit") || "serving"),
        calories: Number(data.get("calories")) || 0,
        protein: Number(data.get("protein")) || 0,
        carbs: Number(data.get("carbs")) || 0,
        fat: Number(data.get("fat")) || 0,
        fiber: Number(data.get("fiber")) || 0,
        note: "",
        favorite: false,
        emoji: String(data.get("emoji") || "🍽️"),
      });
    }
    onClose();
  }

  return (
    <Modal title={mode === "food" ? "Add Food" : "Add Water"} onClose={onClose}>
      <div className="segmented-control" role="group" aria-label="Log type">
        <button type="button" className={mode === "food" ? "is-selected" : ""} onClick={() => setMode("food")}>Food</button>
        <button type="button" className={mode === "water" ? "is-selected" : ""} onClick={() => setMode("water")}><Droplets /> Water</button>
      </div>
      <form className="form-stack" onSubmit={onSubmit}>
        {mode === "food" ? (
          <>
            <label className="field">Food name<input name="name" required autoFocus placeholder="Chicken and rice" /></label>
            <div className="form-grid three">
              <label className="field">Meal<select name="meal" defaultValue={mealForHour(now.getHours())}>{meals.map((meal) => <option key={meal} value={meal}>{displayMeal(meal)}</option>)}</select></label>
              <label className="field">Emoji<input name="emoji" defaultValue="🍽️" maxLength={4} /></label>
              <label className="field">Time<input type="time" value={time} onChange={(event) => setTime(event.target.value)} /></label>
            </div>
            <div className="form-grid three">
              <label className="field">Quantity<input name="quantity" type="number" min="0" step="0.1" defaultValue="1" /></label>
              <label className="field">Unit<input name="unit" defaultValue="serving" /></label>
              <label className="field">Calories<input name="calories" type="number" min="0" required /></label>
            </div>
            <div className="form-grid four">
              <label className="field">Protein<input name="protein" type="number" min="0" step="0.1" defaultValue="0" /></label>
              <label className="field">Carbs<input name="carbs" type="number" min="0" step="0.1" defaultValue="0" /></label>
              <label className="field">Fat<input name="fat" type="number" min="0" step="0.1" defaultValue="0" /></label>
              <label className="field">Fiber<input name="fiber" type="number" min="0" step="0.1" defaultValue="0" /></label>
            </div>
          </>
        ) : (
          <>
            <label className="field">Amount (ml)<input name="milliliters" type="number" min="1" defaultValue="250" autoFocus /></label>
            <label className="field">Time<input type="time" value={time} onChange={(event) => setTime(event.target.value)} /></label>
          </>
        )}
        <button className="primary-button full" type="submit"><Plus /> Add to diary</button>
      </form>
    </Modal>
  );
}

function EditFoodModal({
  entry,
  onClose,
  onSave,
  onDelete,
}: {
  entry: FoodEntry;
  onClose: () => void;
  onSave: (entry: FoodEntry) => Promise<void>;
  onDelete: () => Promise<void>;
}) {
  const [favorite, setFavorite] = useState(entry.favorite);
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    await onSave({
      ...entry,
      name: String(data.get("name") || entry.name),
      quantity: Number(data.get("quantity")) || entry.quantity,
      unit: String(data.get("unit") || entry.unit),
      calories: Number(data.get("calories")) || 0,
      protein: Number(data.get("protein")) || 0,
      carbs: Number(data.get("carbs")) || 0,
      fat: Number(data.get("fat")) || 0,
      fiber: Number(data.get("fiber")) || 0,
      favorite,
    });
  }
  return (
    <Modal title="Edit Food" onClose={onClose}>
      <form className="form-stack" onSubmit={submit}>
        <label className="field">Food name<input name="name" defaultValue={entry.name} required /></label>
        <div className="form-grid three">
          <label className="field">Quantity<input name="quantity" type="number" min="0" step="0.1" defaultValue={entry.quantity} /></label>
          <label className="field">Unit<input name="unit" defaultValue={entry.unit} /></label>
          <label className="field">Calories<input name="calories" type="number" min="0" defaultValue={entry.calories} /></label>
        </div>
        <div className="form-grid four">
          <label className="field">Protein<input name="protein" type="number" min="0" step="0.1" defaultValue={entry.protein} /></label>
          <label className="field">Carbs<input name="carbs" type="number" min="0" step="0.1" defaultValue={entry.carbs} /></label>
          <label className="field">Fat<input name="fat" type="number" min="0" step="0.1" defaultValue={entry.fat} /></label>
          <label className="field">Fiber<input name="fiber" type="number" min="0" step="0.1" defaultValue={entry.fiber} /></label>
        </div>
        <button className={`secondary-button full${favorite ? " is-favorite" : ""}`} type="button" onClick={() => setFavorite((value) => !value)}>
          <Heart fill={favorite ? "currentColor" : "none"} /> {favorite ? "Saved as favorite" : "Save as favorite"}
        </button>
        <div className="modal-actions">
          <button className="danger-button" type="button" onClick={() => void onDelete()}><Trash2 /> Delete</button>
          <button className="primary-button" type="submit">Save changes</button>
        </div>
      </form>
    </Modal>
  );
}
