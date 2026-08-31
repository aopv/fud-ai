import { ChevronLeft, ChevronRight } from "lucide-react";
import { startOfLocalDay } from "../domain";

interface DateStripProps {
  selected: Date;
  onSelect: (date: Date) => void;
}

export function DateStrip({ selected, onSelect }: DateStripProps) {
  const start = startOfLocalDay(selected);
  start.setDate(start.getDate() - start.getDay());
  const days = Array.from({ length: 7 }, (_, index) => {
    const date = new Date(start);
    date.setDate(start.getDate() + index);
    return date;
  });
  const today = startOfLocalDay(new Date()).getTime();

  function move(daysToMove: number) {
    const next = new Date(selected);
    next.setDate(next.getDate() + daysToMove);
    onSelect(next);
  }

  return (
    <div className="date-strip-wrap">
      <button className="date-arrow" type="button" aria-label="Previous week" onClick={() => move(-7)}>
        <ChevronLeft />
      </button>
      <div className="date-strip" role="list" aria-label="Select day">
        {days.map((date) => {
          const active = date.toDateString() === selected.toDateString();
          return (
            <button
              type="button"
              key={date.toISOString()}
              className={active ? "is-selected" : ""}
              aria-pressed={active}
              aria-label={date.toLocaleDateString(undefined, { weekday: "long", month: "long", day: "numeric" })}
              onClick={() => onSelect(date)}
            >
              <span>{date.toLocaleDateString(undefined, { weekday: "narrow" })}</span>
              <strong>{date.getDate()}</strong>
              {date.getTime() === today && !active ? <i aria-label="Today" /> : null}
            </button>
          );
        })}
      </div>
      <button className="date-arrow" type="button" aria-label="Next week" onClick={() => move(7)}>
        <ChevronRight />
      </button>
    </div>
  );
}
