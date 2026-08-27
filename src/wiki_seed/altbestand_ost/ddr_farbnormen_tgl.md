# DDR-Farbnormen und TGL-Querschnitte

In der DDR galten eigene Normen — die **TGL** (Technische Normen, Gütevorschriften
und Lieferbedingungen), inhaltlich an die westdeutschen VDE-Normen angelehnt,
aber in wichtigen Details abweichend. Wer heute in Altbauten der neuen
Bundesländer arbeitet, trifft auf beides gleichzeitig: alte TGL-Bestandsanlagen
und spätere Nachrüstungen nach westdeutscher/gesamtdeutscher Norm.

---

## 1. Aderfarben nach TGL — Kurzfassung

Die vollständige Farbtabelle mit Ost/West-Vergleich steht in
`kabel_aderfarben/aderfarben_normen_geschichte.md` §4/§5 — hier nur die
für die Praxis wichtigste Abweichung:

| Leiter | TGL/DDR | BRD (VDE, ab 1965) |
|---|---|---|
| PE (Schutzleiter) | **grün, einfarbig** | grün-gelb (zweifarbig) |
| L1/L2/L3 | oft alle **schwarz**, teils schwarz/rot/grau gemischt | schwarz/rot/grau (bis 2007) |
| N / PEN | hellblau oder grau | hellblau |

**Die wichtigste Verwechslungsgefahr:** Ein einfarbig grüner Leiter war in
der DDR **PE** — nach heutiger Norm ist einfarbig Grün **kein** gültiges
PE-Kennzeichen mehr (nur noch Grün-Gelb gilt). Vor jeder Arbeit messen,
nicht nach Farbe vertrauen.

---

## 2. Kabelquerschnitte: TGL 200-1750 (Starkstromkabel)

Die einschlägige TGL-Reihe für Starkstromkabel war **TGL 200-1750**, mehrteilig
gegliedert (Bl.01 „Übersicht", Bl.02 „Allgemeine Festlegungen", Bl.03 „Prüfung",
Bl.05 „1-kV-Kabel", Bl.08 „Plastkabel" u. a.), archiviert im TGL-Normenkatalog
der Universitätsbibliothek Weimar. Die genormten Querschnittsstufen selbst
waren im Kern dieselbe international gebräuchliche Vorzugsreihe (1,5 / 2,5 / 4
/ 6 / 10 / 16 / 25 / 35 / 50 mm² …) wie in der BRD — hier gab es keinen
grundlegenden Bruch. **Die eigentliche DDR-Besonderheit lag nicht in der
Zahlenreihe, sondern im verwendeten Material:**

### Aluminium statt Kupfer — mit einer Stufe „Sicherheitszuschlag"

- **1,5 mm² Kupfer entsprach 2,5 mm² Aluminium** — die in der DDR verbreitete
  Faustregel „eine Stufe größer" (Aluminium hat geringere Leitfähigkeit,
  Belastbarkeit und ist spröder/kriechfähiger unter Klemmdruck)
- Analog: **4 mm² Alu ≈ 2,5 mm² Cu**
- Typische Absicherung: Beleuchtungsstromkreise 6 A, Steckdosenringe 10 A,
  Herdanschluss 3 × 4 mm² Alu mit 2 × 16 A
- Aluminiumleiter wurden ab 2,5 mm² in praktisch allen DDR-Wohnbauten bis ca.
  1989 verlegt (Kupfermangel, s. `altbestand_ost/aluminium_leitungen_tgl.md`
  für die Hintergründe und den Umgang damit im Bestand)
- **AlCu-Hybridleiter** (Kupfer nicht aufgedampft, sondern als Band um den
  Alu-Kern gewickelt und verschweißt) sowie **fettgefüllte Pressverbinder**
  (Presshülsen) zur Verbindungstechnik waren gebräuchlich — beide halten laut
  Praxisberichten bis heute, sofern nie mechanisch belastet oder erwärmt

### Für heutige Nachrüstungen

Neu verlegte Aluminiumleiter sind heute erst **ab 16 mm²** üblich/zugelassen
— bei kleineren Querschnitten wird grundsätzlich Kupfer verwendet. Ein
Anschluss von TGL-Aluminiumbestand (2,5–10 mm²) an neue Kupferleitungen
braucht spezielle Alu-Cu-Verbindungstechnik (Bimetall-Klemmen/-Pressverbinder),
niemals direkte Schraubklemmen ohne Kontaktvermittler.

---

## 3. Einordnung: kein einheitliches Bild

Anders als bei den zentral gesteuerten Farbnormen war die tatsächliche
Umsetzung auf Baustellen uneinheitlicher, als es „eine TGL-Norm" vermuten
lässt — mehrere unabhängige Praxisberichte beschreiben stark variierende
Ausführungen (alle drei Phasen schwarz, teils Rot/Grau gemischt, je nach
Hersteller und Verlegejahr). Das deckt sich mit der allgemeinen Erfahrung im
Altbestand: **die Farbe ist ein Hinweis, kein Beweis** — das gilt für
TGL-Anlagen noch mehr als für westdeutsche Altanlagen, weil die tatsächliche
Baustellenpraxis von der Normvorgabe teils deutlich abwich.

---

## Quellen

- [Elektro-Elektroinstallation.de: Verkabelung in Aluminium – die typische DDR-Verkabelung](https://elektro-elektroinstallation.de/elektriker-berlin-2/verkabelung-in-aluminium/)
- [Elektrikforum.de: „DDR-Elektrik noch zulässig?"](https://www.elektrikforum.de/threads/ddr-elektrik-noch-zulaessig.14807/) — Forums-Erfahrungsberichte zu Querschnitt-Äquivalenzen, Absicherung, AlCu/Pressverbinder
- TGL-Normenkatalog der Universitätsbibliothek Weimar: [TGL 200-1750 Bl.01 „Starkstromkabel – Übersicht"](https://katalog.ub.uni-weimar.de/tgl/TGL_200-1750-01_04-1975.pdf) (weitere Blätter derselben Reihe dort ebenfalls archiviert)
- Siehe auch `kabel_aderfarben/aderfarben_normen_geschichte.md` (vollständige Ost/West-Farbhistorie) und `altbestand_ost/aluminium_leitungen_tgl.md` (Hintergrund + Umgang mit Alu-Bestand)

> **Unsicherheit/Lücke:** Der TGL-Normenkatalog der UB Weimar führt die
> vollständigen Original-Dokumente der Reihe TGL 200-1750, deren genauer
> Inhalt (z. B. eine eigene DDR-Vorzugsreihe abweichend von der BRD-Reihe)
> sich über reine Web-Recherche nicht abschließend verifizieren ließ — wer
> Zugriff auf die Originaldokumente hat oder eigene TGL-Praxiserfahrung
> beisteuern kann, ergänzt hier gerne genauer.
