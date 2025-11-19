# LehrerWM – Supabase Variante (Option B)

Diese Lieferung enthält:

- Supabase SQL-Schema (Tabellen, Indizes)
- RLS-Policies für Admin- und Voting-Flows
- RPC-Funktionen für sicheres anonymes Voting mit UUID/Fingerprint-HMAC
- Realtime-Konzept (Broadcasts via supabase_realtime)
- Frontend-Integration (supabase-js Client vorbereitet)
- Setup-Anleitung für Supabase Free-Tier und Hosting-Hinweise

## 1) Environment Variablen

- VITE_SUPABASE_URL
- VITE_SUPABASE_ANON_KEY
- SUPABASE_SERVICE_ROLE (nur lokal/Server, nicht im Browser!)
- RECAPTCHA_SITE_KEY (optional)
- RECAPTCHA_SECRET_KEY (optional, nur auf Server)
- HMAC_SECRET (für UUID/Fingerprint HMAC; auf Server/Edge-Func)

## 2) SQL-Schema

Siehe `sql/schema.sql` und `sql/policies.sql` sowie `sql/rpc.sql`.

## 3) Deployment

- Supabase Projekt erstellen → SQL-Skripte ausführen
- Frontend (Vercel/Netlify): ENV setzen (VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY)
- Realtime aktivieren (Database → Replication → supabase_realtime)

## 4) Realtime Subscriptions

- Kanal `matches` für Status- und Vote-Änderungen
- Kanal `tournaments` für Turnierstatus/Sieger

## 5) Voting Flow

- Client generiert UUID (+ optional Fingerprint)
- Client ruft RPC `cast_vote(match_id, choice, uuid_hmac, fingerprint_hmac, recaptcha_token?)`
- Server prüft Match-Fenster, Duplikate, optional reCAPTCHA
- Insert in `votes`, Counts ableiten via Aggregation

## 6) Turnierlogik

- Funktion `advance_bracket_after_match(match_id)` setzt Gewinner und erstellt nächste Runde
- Freilos wird beim Bracket-Build berücksichtigt

## 7) Admin

- Admins via Supabase Auth (E-Mail/Passwort). Rolle in Tabelle `admins`.
- Admin UI nutzt supabase-js Auth + Policies

