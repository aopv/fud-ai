import { describe, expect, it } from "vitest";
import {
  EMPTY_SYNC_CONFIGURATION,
  isSameLocalDay,
  nextMutationTimestamp,
  nutrientTotals,
  resetSyncCursorWhenWorkspaceChanges,
  type FoodEntry,
} from "./domain";

const base: FoodEntry = {
  id: "food-1",
  name: "Test meal",
  meal: "lunch",
  timestamp: "2026-08-31T07:30:00.000Z",
  quantity: 1,
  unit: "serving",
  calories: 410,
  protein: 30,
  carbs: 42,
  fat: 14,
  fiber: 7,
  note: "",
  favorite: false,
  emoji: "🍽️",
};

describe("nutrition domain", () => {
  it("totals all tracked macros without rounding away precision", () => {
    const totals = nutrientTotals([base, {
      ...base,
      id: "food-2",
      calories: 125,
      protein: 5.5,
      carbs: 20.25,
      fat: 3.75,
      fiber: 2.5,
    }]);
    expect(totals).toEqual({ calories: 535, protein: 35.5, carbs: 62.25, fat: 17.75, fiber: 9.5 });
  });

  it("matches calendar days in local time", () => {
    const date = new Date(base.timestamp);
    expect(isSameLocalDay(base.timestamp, date)).toBe(true);
    const tomorrow = new Date(date);
    tomorrow.setDate(tomorrow.getDate() + 1);
    expect(isSameLocalDay(base.timestamp, tomorrow)).toBe(false);
  });

  it("starts a full pull when the encrypted sync workspace changes", () => {
    const previous = { ...EMPTY_SYNC_CONFIGURATION, endpoint: "https://old.test", cursor: "42" };
    expect(resetSyncCursorWhenWorkspaceChanges(previous, { ...previous, endpoint: "https://new.test" }).cursor).toBe("");
    expect(resetSyncCursorWhenWorkspaceChanges(previous, { ...previous, enabled: true }).cursor).toBe("42");
  });

  it("keeps mutation timestamps monotonic when the device clock moves backward", () => {
    expect(nextMutationTimestamp("2026-08-31T00:00:10.000Z", Date.parse("2026-08-31T00:00:00.000Z")))
      .toBe("2026-08-31T00:00:10.001Z");
  });
});
