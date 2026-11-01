-- PG Khata — migration 32: per-profile language + notification preferences.
--
-- Backs the real Settings screen (`docs/design-readme-reconciliation.md`'s
-- "Settings — notification preferences & language" gap, never built until
-- now). Defaults to English/on so every existing profile keeps behaving
-- exactly as it does today the moment this ships — nobody's experience
-- changes until they actually open Settings and change something.
--
-- Rent reminders are deliberately NOT a toggle here — the approved design
-- for Settings.dc.html made that one mandatory/always-on, so there's
-- nothing to store for it.

alter table profiles
  add column preferred_language text not null default 'en'
    check (preferred_language in ('en', 'te')),
  add column notify_complaints boolean not null default true,
  add column notify_announcements boolean not null default true;

comment on column profiles.preferred_language is
  'ISO 639-1 code — only "en"/"te" exist as real app translations right now (see mobile/lib/l10n). Add more as more languages ship.';
