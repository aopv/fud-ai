import { useEffect, useState } from "react";
import { AppShell } from "./components/AppShell";
import type { AppSection } from "./domain";
import { CoachScreen } from "./screens/CoachScreen";
import { HomeScreen } from "./screens/HomeScreen";
import { ProgressScreen } from "./screens/ProgressScreen";
import { SettingsScreen } from "./screens/SettingsScreen";
import { WorkoutsScreen } from "./screens/WorkoutsScreen";
import { useAppStore } from "./store/AppStore";

const sections = new Set<AppSection>(["home", "progress", "coach", "workouts", "settings"]);

function sectionFromHash(): AppSection {
  const value = window.location.hash.replace(/^#\/?/u, "") as AppSection;
  return sections.has(value) ? value : "home";
}

export default function App() {
  const { ready, initializationError } = useAppStore();
  const [section, setSection] = useState<AppSection>(sectionFromHash);

  useEffect(() => {
    function onHashChange() { setSection(sectionFromHash()); }
    window.addEventListener("hashchange", onHashChange);
    return () => window.removeEventListener("hashchange", onHashChange);
  }, []);

  function navigate(next: AppSection) {
    window.location.hash = next;
    setSection(next);
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  if (!ready) {
    return <div className="loading-screen"><img src="/pwa-192.png" alt="" /><span>Loading your private diary…</span></div>;
  }

  if (initializationError) {
    return <div className="loading-screen error-screen"><img src="/pwa-192.png" alt="" /><strong>Your private diary could not be opened</strong><span>{initializationError}</span><button className="primary-button" type="button" onClick={() => window.location.reload()}>Try again</button></div>;
  }

  return (
    <AppShell section={section} onSectionChange={navigate}>
      {section === "home" ? <HomeScreen /> : null}
      {section === "progress" ? <ProgressScreen /> : null}
      {section === "coach" ? <CoachScreen /> : null}
      {section === "workouts" ? <WorkoutsScreen /> : null}
      {section === "settings" ? <SettingsScreen /> : null}
    </AppShell>
  );
}
