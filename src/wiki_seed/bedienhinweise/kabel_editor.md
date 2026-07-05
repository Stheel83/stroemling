# Kabel-Typ anlegen und bearbeiten

Der Kabel-Editor ist eine Vollbild-Ansicht analog zum Klemmen-Editor:
links die Stammdaten, rechts eine editierbare Ader-Tabelle.

---

## Direktes Anlegen

Klick auf `[+]` bei „Kabel" legt sofort ein Bauteil „Neues Kabel" mit
Standardwerten an und öffnet den Editor – du benennst das Kabel dort.

## Linke Spalte – Stammdaten

- Allgemeine Bauteilfelder: Bezeichnung, Hersteller, Artikel-Nr.,
  Lieferant, Preis, Spannung, Strom, Leistung, Bemerkung, Links
  (Hersteller-Website / Datenblatt)
- Kabeltyp (Normbezeichnung, z. B. `NYM-J`, `LIYY`, `ÖLFLEX CLASSIC 110`)
- Geschirmt / Paarweise verdrillt (Schalter)
- Außenmantelfarbe, Außendurchmesser (mm)
- Leitermaterial (Cu/Al), Isolierungsmaterial (PVC/LSZH/Gummi/XLPE)
- Ein „Speichern"-Button ganz unten sichert alle Felder zusammen

Aderanzahl, Adernkennung und Nennquerschnitt gibt es hier **nicht** als
eigene Felder – das ergibt sich vollständig aus der Ader-Tabelle rechts.

## Rechte Spalte – Ader-Tabelle

Pro Zeile eine Ader: Nummer, Bezeichnung (z. B. `L`, `N`, `PE`), Farbe nach
IEC 60757 (z. B. `BN`, `BU`, `GNYE`), Querschnitt in mm². Alle Felder sind
inline editierbar (Textfeld, Übernahme beim Verlassen). Reihenfolge per
↑/↓ ändern, Ader per × entfernen, „+ Ader" hängt eine neue Zeile an. Farbe
und Bezeichnung können beide gesetzt sein oder auch nur eines von beiden –
mindestens eines ist Pflicht. Ein Kabel-Fußzeile zeigt die aktuelle
Aderanzahl.

**Paarweise Verdrillung:** Ist der Schalter links aktiv, ordnest du je zwei
Adern zu einem Paar zusammen (z. B. für verdrillte Steuerleitungen wie
LiYCY) – relevant für Kabel mit mehreren verdrillten Aderpaaren unter
einem Gesamtschirm.

---

## Kabel im Schaltplan verwenden

Der hier definierte Kabeltyp wird über eine **Kabellinie** im Schaltplan
verknüpft (Werkzeug „Kabellinie" zeichnen, Kabeltyp aus der Bibliothek
wählen). Die Ader-zu-Pin-Zuordnung und Aderbeschriftung erfolgen dann direkt
am Kreuzungspunkt im Canvas bzw. in der Kabelliste der Listen-Ansicht.
