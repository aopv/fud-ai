import { ArrowUp, LockKeyhole, MessageSquareText, RotateCcw, Sparkles } from "lucide-react";
import { useMemo, useState, type FormEvent } from "react";
import { isSameLocalDay, nutrientTotals } from "../domain";
import { useAppStore } from "../store/AppStore";

const suggestions = [
  "How is my nutrition today?",
  "What should I eat for dinner?",
  "Am I getting enough protein?",
  "How is my recent training?",
];

export function CoachScreen() {
  const { entities, profile, saveEntity, deleteEntity } = useAppStore();
  const messages = entities("coach.messages").sort((a, b) => a.timestamp.localeCompare(b.timestamp));
  const [draft, setDraft] = useState("");
  const todayFoods = entities("food.logs").filter((entry) => isSameLocalDay(entry.timestamp, new Date()));
  const totals = useMemo(() => nutrientTotals(todayFoods), [todayFoods]);

  async function ask(content: string) {
    if (!content.trim()) return;
    const userId = crypto.randomUUID();
    await saveEntity("coach.messages", userId, { id: userId, role: "user", content: content.trim(), timestamp: new Date().toISOString() });
    const proteinRemaining = Math.max(0, profile.protein - totals.protein);
    const calorieRemaining = profile.calories - totals.calories;
    const reply = calorieRemaining >= 0
      ? `You have ${Math.round(calorieRemaining)} kcal left today and about ${Math.round(proteinRemaining)} g of protein remaining. A protein-focused meal with vegetables would fit your current diary well.`
      : `You are ${Math.abs(Math.round(calorieRemaining))} kcal over your current target. One day does not define your progress—focus on hunger, hydration, and returning to your usual pattern tomorrow.`;
    const assistantId = crypto.randomUUID();
    await saveEntity("coach.messages", assistantId, { id: assistantId, role: "assistant", content: reply, timestamp: new Date(Date.now() + 1).toISOString() });
    setDraft("");
  }

  function submit(event: FormEvent) {
    event.preventDefault();
    void ask(draft);
  }

  return (
    <div className="coach-screen">
      <header className="coach-header"><h1>Coach</h1>{messages.length ? <button className="icon-button" type="button" aria-label="Clear conversation" onClick={() => void Promise.all(messages.map((message) => deleteEntity("coach.messages", message.id)))}><RotateCcw /></button> : null}</header>
      <div className={`coach-content${messages.length ? " has-messages" : ""}`}>
        {messages.length === 0 ? (
          <div className="coach-empty">
            <div className="coach-mark"><MessageSquareText /></div>
            <h2>Ask your Coach</h2>
            <p>Your local coach can read this browser’s nutrition and goals. No diary data is sent to the sync server.</p>
            <div className="suggestion-grid">{suggestions.map((suggestion) => <button key={suggestion} type="button" onClick={() => void ask(suggestion)}><ArrowUp />{suggestion}</button>)}</div>
          </div>
        ) : (
          <div className="message-list">
            {messages.map((message) => <div className={`message ${message.role}`} key={message.id}>{message.role === "assistant" ? <span><Sparkles /></span> : null}<p>{message.content}</p></div>)}
          </div>
        )}
      </div>
      <div className="coach-privacy"><LockKeyhole /> Responses are calculated locally in this web foundation.</div>
      <form className="coach-composer" onSubmit={submit}>
        <input value={draft} onChange={(event) => setDraft(event.target.value)} placeholder="Ask Coach…" aria-label="Message Coach" />
        <button type="submit" aria-label="Send" disabled={!draft.trim()}><ArrowUp /></button>
      </form>
    </div>
  );
}
