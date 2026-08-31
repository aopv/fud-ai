import type { AppNamespace, LocalEntity, NamespaceData } from "../domain";
import { DEFAULT_PROFILE } from "../domain";

function isoAt(hour: number, minute: number, dayOffset = 0): string {
  const value = new Date();
  value.setDate(value.getDate() + dayOffset);
  value.setHours(hour, minute, 0, 0);
  return value.toISOString();
}

function entity<N extends AppNamespace>(
  namespace: N,
  recordId: string,
  data: NamespaceData[N],
  deviceId: string,
  revision = 1,
): LocalEntity<NamespaceData[N]> {
  return {
    recordId,
    namespace,
    deleted: false,
    data,
    version: {
      updatedAt: new Date().toISOString(),
      revision,
      deviceId,
      mutationId: crypto.randomUUID(),
    },
  };
}

export function createDemoEntities(deviceId: string): LocalEntity[] {
  return [
    entity("profile", "profile", DEFAULT_PROFILE, deviceId),
    entity("food.logs", "demo-breakfast", {
      id: "demo-breakfast",
      name: "Yogurt bowl with blueberries and granola",
      meal: "breakfast",
      timestamp: isoAt(8, 10),
      quantity: 250,
      unit: "g",
      calories: 320,
      protein: 12,
      carbs: 45,
      fat: 10,
      fiber: 4,
      note: "",
      favorite: true,
      emoji: "🥣",
    }, deviceId),
    entity("food.logs", "demo-lunch", {
      id: "demo-lunch",
      name: "Roast chicken breast with asparagus",
      meal: "lunch",
      timestamp: isoAt(13, 5),
      quantity: 250,
      unit: "g",
      calories: 380,
      protein: 45,
      carbs: 5.5,
      fat: 18,
      fiber: 4,
      note: "",
      favorite: false,
      emoji: "🍗",
    }, deviceId),
    entity("food.logs", "demo-dinner", {
      id: "demo-dinner",
      name: "Cheeseburger meal with fries and cola",
      meal: "dinner",
      timestamp: isoAt(19, 55),
      quantity: 620,
      unit: "g",
      calories: 1_150,
      protein: 45,
      carbs: 115,
      fat: 58,
      fiber: 6.5,
      note: "",
      favorite: false,
      emoji: "🍔",
    }, deviceId),
    entity("water.logs", "demo-water", {
      id: "demo-water",
      timestamp: isoAt(15, 20),
      milliliters: 750,
    }, deviceId),
    ...Array.from({ length: 10 }, (_, index) => {
      const kilograms = 72.6 - (index * 0.16);
      return entity("weight.logs", `demo-weight-${index}`, {
        id: `demo-weight-${index}`,
        timestamp: isoAt(7, 30, index - 9),
        kilograms,
      }, deviceId);
    }),
    ...Array.from({ length: 6 }, (_, index) => entity("bodyfat.logs", `demo-bodyfat-${index}`, {
      id: `demo-bodyfat-${index}`,
      timestamp: isoAt(7, 35, (index * 2) - 10),
      percentage: 18.8 - (index * 0.13),
    }, deviceId)),
    entity("workout.logs", "demo-workout", {
      id: "demo-workout",
      timestamp: isoAt(18, 15),
      name: "Upper Body",
      category: "Strength",
      sets: [
        { weightKg: 60, reps: 8 },
        { weightKg: 60, reps: 8 },
        { weightKg: 57.5, reps: 10 },
      ],
      caloriesBurned: 310,
      saved: true,
    }, deviceId),
  ];
}
