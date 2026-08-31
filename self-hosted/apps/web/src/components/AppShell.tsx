import {
  BarChart3,
  Dumbbell,
  Home,
  MessageSquareText,
  Settings,
} from "lucide-react";
import type { AppSection } from "../domain";
import { useAppStore } from "../store/AppStore";

const navigation: Array<{
  id: AppSection;
  label: string;
  icon: typeof Home;
}> = [
  { id: "home", label: "Home", icon: Home },
  { id: "progress", label: "Progress", icon: BarChart3 },
  { id: "coach", label: "Coach", icon: MessageSquareText },
  { id: "workouts", label: "Workouts", icon: Dumbbell },
  { id: "settings", label: "Settings", icon: Settings },
];

interface AppShellProps {
  section: AppSection;
  onSectionChange: (section: AppSection) => void;
  children: React.ReactNode;
}

export function AppShell({ section, onSectionChange, children }: AppShellProps) {
  const { profile, syncState, syncMessage } = useAppStore();
  return (
    <div className="app-shell">
      <aside className="sidebar" aria-label="Primary navigation">
        <button className="brand" type="button" onClick={() => onSectionChange("home")}>
          <img src="/favicon-32.png" alt="" />
          <span>Fud AI</span>
        </button>
        <nav className="sidebar-nav">
          {navigation.map(({ id, label, icon: Icon }) => (
            <button
              className={`nav-item${section === id ? " is-selected" : ""}`}
              key={id}
              type="button"
              aria-current={section === id ? "page" : undefined}
              onClick={() => onSectionChange(id)}
            >
              <Icon aria-hidden="true" />
              <span>{label}</span>
            </button>
          ))}
        </nav>
        <div className={`sync-card sync-${syncState}`}>
          <span className="sync-dot" aria-hidden="true" />
          <div>
            <strong>{syncState === "syncing" ? "Syncing" : syncState === "error" ? "Sync needs attention" : syncState === "synced" ? "Encrypted · Synced" : "Stored locally"}</strong>
            <span>{syncMessage}</span>
          </div>
        </div>
        <button className="profile-chip" type="button" onClick={() => onSectionChange("settings")}>
          <span>{profile.displayName.trim().charAt(0).toUpperCase() || "Y"}</span>
          <strong>{profile.displayName || "You"}</strong>
        </button>
      </aside>

      <main className="app-content">{children}</main>

      <nav className="bottom-nav" aria-label="Primary navigation">
        {navigation.map(({ id, label, icon: Icon }) => (
          <button
            className={section === id ? "is-selected" : ""}
            key={id}
            type="button"
            aria-current={section === id ? "page" : undefined}
            onClick={() => onSectionChange(id)}
          >
            <Icon aria-hidden="true" />
            <span>{label}</span>
          </button>
        ))}
      </nav>
    </div>
  );
}
