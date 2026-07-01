# Klassische Nullung – Verbotsdaten und Übergangsfristen

Eine Kurzübersicht, wann die klassische Nullung (TN-C-System) in
verschiedenen Ländern für Neuanlagen verboten wurde — und wie der
Bestandsschutz seither gehandhabt wird.

> **Quellen:**
> - Wikipedia: [Nullung](https://de.wikipedia.org/wiki/Nullung)
> - Wikipedia: [TN-Netz](https://de.wikipedia.org/wiki/TN-Netz)
> - Wikipedia: [Schutzmaßnahme (Elektrotechnik)](https://de.wikipedia.org/wiki/Schutzma%C3%9Fnahme_(Elektrotechnik))

---

## Verbot für Neuanlagen nach Land/Region

| Land / Region            | Verboten ab         | Übergangsfrist       | Rechtsgrundlage                           |
|--------------------------|:-------------------:|:--------------------:|-------------------------------------------|
| **BRD (West)**           | **1. Mai 1973**     | bis 31. März 1974    | VDE 0100/5.73                             |
| **DDR (Ost)**            | ca. **1976–1980**   | —                    | TGL 10488 (Umbau auf 3-Leiter schrittweise) |
| Schweiz                  | 1. Januar 1974      | —                    | NIV (Niederspannungsinstallationsverordnung) |
| Österreich               | Kein Verbot*        | —                    | ETG 1992 / ÖVE-ÖNORM E 8001-1:2010       |
| EU (Neuanlagen)          | Laufend verboten    | —                    | DIN VDE 0100-410:2007-06, IEC 60364-4-41 |

\* Österreich hat die klassische Nullung nie formell verboten — neue
Anlagen folgen jedoch de facto dem TN-C-S-Standard des Netzbetreibers.

---

## BRD: Details zur Übergangsfrist 1973/74

Die **VDE 0100/5.73** (Mai 1973) war die erste Fassung, die einen
**separaten Schutzleiter** verpflichtend vorschrieb.

- **Ab 1. Mai 1973:** Klassische Nullung in neuen Anlagen verboten
- **Bis 31. März 1974:** Übergangsfrist für Anlagen, die sich bereits im Bau befanden
- **Ab 1. April 1974:** Kein Bestandsschutz mehr für neu errichtete TN-C-Anlagen

Für **Bestandsanlagen** (vor 1. Mai 1973 errichtet) gilt Bestandsschutz.
Sie dürfen im vorhandenen Umfang weiterbetrieben werden.

---

## DDR: Eigener Weg und eigene Zeitlinie

Die DDR folgte dem VDE-Verbot von 1973 **nicht direkt** — sie hatte
ein eigenes Normensystem (TGL – Technische Güte- und Lieferbedingungen).

**Schrittweiser Übergang (ca. 1973–1985):**

| Zeitraum     | DDR-Praxis                                                                  |
|--------------|-----------------------------------------------------------------------------|
| bis ca. 1973 | Klassische Nullung (TN-C) mit 2-adrigen Aluminium-Leitungen Standard       |
| ca. 1973–80  | 3-adrige Verlegung in Küchen und Bädern zunehmend gefordert (TGL-Anpassung) |
| ca. 1980–90  | Neubauten mit getrenntem PE in den meisten Räumen                           |
| ab 1990      | Wiedervereinigung — VDE-Normen galten, DDR-Bestand erhielt Bestandsschutz  |

> **Wichtig:** In vielen DDR-Altbauten (vor 1973) wurde selbst in
> Küchen und Bädern klassisch genullt verlegt. Die Kombination aus
> **Aluminium-PEN-Leitern** und Kriechverbindungen macht diese Anlagen
> zu den gefährlichsten im deutschen Altbestand.

---

## Was passiert bei Änderungen / Erweiterungen?

| Situation                                              | Rechtsfolge                                                        |
|--------------------------------------------------------|--------------------------------------------------------------------|
| Altanlage unverändert weiterbetreiben                  | Bestandsschutz, kein Handlungsbedarf                               |
| Neue Steckdose in bestehenden Stromkreis einschleifen  | Nur wenn Stromkreis unverändert bleibt, ggf. Bestandsschutz        |
| Neuen Stromkreis einrichten                            | Muss VDE-aktuell sein (TN-S mit getrenntem PE)                     |
| Wesentliche Änderung am Verteiler                      | Bestandsschutz erlischt, gesamte Anlage muss geprüft werden        |
| Umbau Küche / Bad                                      | VDE 0100-700: 3-Leiter-Anlage mit RCD verpflichtend                |

---

## FI-Schutzschalter-Pflicht (RCD): Zeitlinie

| Datum                     | Regelung                                                             | Norm                       |
|---------------------------|----------------------------------------------------------------------|----------------------------|
| 1. Juni 2007              | RCD ≤30 mA für alle Steckdosen in Neuanlagen (Laiennutzung)         | DIN VDE 0100-410:2007-06   |
| bis 1. Februar 2009       | Übergangsfrist für oben genannte Pflicht                             | —                          |
| 1. Oktober 2018           | RCD-Pflicht auf Steckdosen bis 32 A ausgeweitet                     | DIN VDE 0100-410:2018-10   |
| bis 7. Juli 2020          | Übergangsfrist für 2018er-Erweiterung                               | —                          |

> **Für TN-C-Anlagen gilt:** RCD kann **nicht** direkt eingebaut werden —
> erst PEN in PE+N aufteilen (Hauseinführung / Hauptverteilung), dann
> RCD auf dem TN-S-Teil einsetzen.

---

## Checkliste: Umgang mit Verdacht auf klassische Nullung

1. **Baujahr ermitteln:** Gebäude vor 1973 in der BRD → Verdacht stark
2. **Leitungsquerschnitt prüfen:** 2-adrig = PEN vorhanden
3. **Schutzkontakt messen:** Spannung zwischen PE-Kontakt und Erde → >0 V = TN-C wahrscheinlich
4. **Isolationsmessung:** PEN-Widerstand prüfen (Alu-Verbindungen!)
5. **Kurzschlussstrommessung:** Schleifenimpedanz messen → Abschaltbedingung überprüfen
6. **Dokumentation:** Datum des Befunds und Zustand protokollieren
7. **Eigentümer informieren:** Handlungsempfehlung + Priorität (Bad/Küche zuerst)
