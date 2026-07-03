# Meldungen: Toast statt Dialog

Kurze Erfolgs- oder Info-Rückmeldungen (z. B. „PDF gespeichert") erscheinen
in Strömling Design als **nicht-blockierende Toast-Meldung** unten
rechts – kein Klick-weg-Dialog, der den Workflow unterbricht.

---

## Toast vs. Dialog – die Abgrenzung

| Situation | Darstellung | Warum |
|---|---|---|
| Erfolg/Info ohne Entscheidungsbedarf (z. B. „PDF gespeichert", „Export fehlgeschlagen, Pfad prüfen") | **Toast** | Du musst nicht reagieren, sollst weiterarbeiten können |
| Ernste Fehler, die gelesen werden müssen (z. B. Datenbankfehler) | **Dialog** | Soll nicht wegverschwinden, bevor er gelesen wurde |
| Entscheidung nötig (Löschen bestätigen, „Fortfahren?") | **Dialog** | Erfordert eine explizite Ja/Nein-Antwort |

Ein Toast zeigt ✓ (grün) bei Erfolg oder ✗ (rot) bei Misserfolg, verschwindet
nach wenigen Sekunden von selbst und blockiert nichts.

---

## Meldungen-Panel

Sidebar-Eintrag **🔔 Meldungen** (direkt unter „Errungenschaften") zeigt
alle Toast-Meldungen der laufenden Sitzung als chronologische Liste –
praktisch, wenn ein Toast verpasst wurde. Die Liste ist reine
Session-Historie: **kein Datenbank-Persist**, nach einem Neustart der App
ist sie leer.

Leer-Zustand: „Noch keine Meldungen in dieser Session."
