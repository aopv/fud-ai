import type { RecordVersionV1 } from "@fud-ai/sync-contracts";

export type AppSection = "home" | "progress" | "coach" | "workouts" | "settings";
export type MealType = "breakfast" | "lunch" | "dinner" | "snack";

export interface Nutrients {
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  fiber: number;
}

export interface FoodEntry extends Nutrients {
  id: string;
  name: string;
  meal: MealType;
  timestamp: string;
  quantity: number;
  unit: string;
  note: string;
  favorite: boolean;
  emoji: string;
}

export interface WaterEntry {
  id: string;
  timestamp: string;
  milliliters: number;
}

export interface FastEntry {
  id: string;
  startedAt: string;
  endedAt: string | null;
  targetHours: number;
  status: "active" | "completed" | "cancelled";
}

export interface WeightEntry {
  id: string;
  timestamp: string;
  kilograms: number;
}

export interface BodyFatEntry {
  id: string;
  timestamp: string;
  percentage: number;
}

export interface WorkoutSet {
  weightKg: number;
  reps: number;
}

export interface WorkoutEntry {
  id: string;
  timestamp: string;
  name: string;
  category: string;
  sets: WorkoutSet[];
  caloriesBurned: number;
  saved: boolean;
}

export interface ChatMessage {
  id: string;
  timestamp: string;
  role: "user" | "assistant";
  content: string;
}

export interface UserProfile extends Nutrients {
  id: "profile";
  displayName: string;
  waterGoalMl: number;
  units: "metric" | "imperial";
}

export type AppNamespace =
  | "profile"
  | "food.logs"
  | "water.logs"
  | "fasting.logs"
  | "weight.logs"
  | "bodyfat.logs"
  | "workout.logs"
  | "coach.messages";

export type NamespaceData = {
  profile: UserProfile;
  "food.logs": FoodEntry;
  "water.logs": WaterEntry;
  "fasting.logs": FastEntry;
  "weight.logs": WeightEntry;
  "bodyfat.logs": BodyFatEntry;
  "workout.logs": WorkoutEntry;
  "coach.messages": ChatMessage;
};

export interface LocalEntity<T = unknown> {
  recordId: string;
  namespace: AppNamespace;
  version: RecordVersionV1;
  deleted: boolean;
  data: T | null;
}

export interface SyncConfiguration {
  endpoint: string;
  accessToken: string;
  encryptionKey: string;
  keyId: string;
  cursor: string;
  enabled: boolean;
}

export const DEFAULT_PROFILE: UserProfile = {
  id: "profile",
  displayName: "You",
  calories: 1_850,
  protein: 152,
  carbs: 103,
  fat: 42,
  fiber: 30,
  waterGoalMl: 2_500,
  units: "metric",
};

export const EMPTY_SYNC_CONFIGURATION: SyncConfiguration = {
  endpoint: "",
  accessToken: "",
  encryptionKey: "",
  keyId: "",
  cursor: "",
  enabled: false,
};

export function resetSyncCursorWhenWorkspaceChanges(
  previous: SyncConfiguration,
  next: SyncConfiguration,
): SyncConfiguration {
  const workspaceChanged = previous.endpoint !== next.endpoint
    || previous.accessToken !== next.accessToken
    || previous.encryptionKey !== next.encryptionKey
    || previous.keyId !== next.keyId;
  return workspaceChanged ? { ...next, cursor: "" } : next;
}

export function isSameSyncConnection(
  left: SyncConfiguration,
  right: SyncConfiguration,
): boolean {
  return left.endpoint === right.endpoint
    && left.accessToken === right.accessToken
    && left.encryptionKey === right.encryptionKey
    && left.keyId === right.keyId
    && left.enabled === right.enabled;
}

export function nextMutationTimestamp(previousUpdatedAt?: string, now = Date.now()): string {
  const previous = previousUpdatedAt ? Date.parse(previousUpdatedAt) : Number.NaN;
  const next = Number.isFinite(previous) ? Math.max(now, previous + 1) : now;
  return new Date(next).toISOString();
}

export function startOfLocalDay(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

export function isSameLocalDay(iso: string, selected: Date): boolean {
  const value = new Date(iso);
  return value.getFullYear() === selected.getFullYear()
    && value.getMonth() === selected.getMonth()
    && value.getDate() === selected.getDate();
}

export function nutrientTotals(entries: readonly FoodEntry[]): Nutrients {
  return entries.reduce<Nutrients>((total, entry) => ({
    calories: total.calories + entry.calories,
    protein: total.protein + entry.protein,
    carbs: total.carbs + entry.carbs,
    fat: total.fat + entry.fat,
    fiber: total.fiber + entry.fiber,
  }), { calories: 0, protein: 0, carbs: 0, fat: 0, fiber: 0 });
}

export function formatNumber(value: number, maximumFractionDigits = 1): string {
  return new Intl.NumberFormat(undefined, { maximumFractionDigits }).format(value);
}

export function displayMeal(meal: MealType): string {
  return meal[0]?.toUpperCase() + meal.slice(1);
}
