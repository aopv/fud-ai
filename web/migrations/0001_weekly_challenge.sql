PRAGMA foreign_keys = ON;

CREATE TABLE challenge_participants (
  participant_id TEXT PRIMARY KEY,
  token_hash TEXT NOT NULL UNIQUE CHECK (length(token_hash) = 64),
  display_name TEXT NOT NULL CHECK (length(display_name) BETWEEN 2 AND 40),
  social_platform TEXT,
  social_handle TEXT,
  rules_accepted_at TEXT NOT NULL,
  rules_version TEXT NOT NULL,
  eligibility_accepted_at TEXT NOT NULL,
  eligibility_version TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  last_active_at TEXT NOT NULL,
  CHECK (
    (social_platform IS NULL AND social_handle IS NULL)
    OR
    (social_platform IN ('x', 'instagram') AND social_handle IS NOT NULL)
  )
);

CREATE INDEX challenge_participants_inactive_idx
  ON challenge_participants(last_active_at);

CREATE TABLE challenge_weekly_scores (
  participant_id TEXT NOT NULL,
  week_start TEXT NOT NULL CHECK (length(week_start) = 10),
  overall_points INTEGER NOT NULL CHECK (overall_points BETWEEN 0 AND 28),
  activity_days INTEGER NOT NULL CHECK (activity_days BETWEEN 0 AND 7),
  nutrition_days INTEGER NOT NULL CHECK (nutrition_days BETWEEN 0 AND 7),
  consistency_days INTEGER NOT NULL CHECK (consistency_days BETWEEN 0 AND 7),
  hydration_days INTEGER NOT NULL CHECK (hydration_days BETWEEN 0 AND 7),
  activity_kcal INTEGER NOT NULL CHECK (activity_kcal BETWEEN 0 AND 14000),
  updated_at TEXT NOT NULL,
  PRIMARY KEY (participant_id, week_start),
  FOREIGN KEY (participant_id)
    REFERENCES challenge_participants(participant_id)
    ON DELETE CASCADE,
  CHECK (
    overall_points = activity_days + nutrition_days + consistency_days + hydration_days
  )
);

CREATE INDEX challenge_scores_overall_idx
  ON challenge_weekly_scores(week_start, overall_points DESC);
CREATE INDEX challenge_scores_activity_idx
  ON challenge_weekly_scores(week_start, activity_days DESC, activity_kcal DESC);
CREATE INDEX challenge_scores_nutrition_idx
  ON challenge_weekly_scores(week_start, nutrition_days DESC);
CREATE INDEX challenge_scores_consistency_idx
  ON challenge_weekly_scores(week_start, consistency_days DESC);
CREATE INDEX challenge_scores_hydration_idx
  ON challenge_weekly_scores(week_start, hydration_days DESC);

CREATE TABLE challenge_reports (
  report_id TEXT PRIMARY KEY,
  reporter_participant_id TEXT NOT NULL,
  reported_participant_id TEXT NOT NULL,
  reason TEXT NOT NULL CHECK (
    reason IN ('impersonation', 'inappropriate_name', 'spam', 'unsafe_content', 'other')
  ),
  details TEXT CHECK (details IS NULL OR length(details) <= 300),
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'reviewed', 'resolved')),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (reporter_participant_id)
    REFERENCES challenge_participants(participant_id)
    ON DELETE CASCADE,
  FOREIGN KEY (reported_participant_id)
    REFERENCES challenge_participants(participant_id)
    ON DELETE CASCADE,
  CHECK (reporter_participant_id <> reported_participant_id),
  UNIQUE (reporter_participant_id, reported_participant_id)
);

CREATE INDEX challenge_reports_status_idx
  ON challenge_reports(status, created_at);
CREATE INDEX challenge_reports_created_idx
  ON challenge_reports(created_at);
