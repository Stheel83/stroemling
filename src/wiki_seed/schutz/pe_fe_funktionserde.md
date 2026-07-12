# PE und FE – Schutzleiter vs. Funktionserde

PE und FE sehen im Schaltplan fast gleich aus — zwei Buchstaben, ein
Erdsymbol — und werden deshalb oft verwechselt. Dabei erfüllen sie
gänzlich unterschiedliche Aufgaben: **PE schützt Menschen**, **FE
schützt die Funktion**. Wer FE dort einsetzt, wo PE gefordert ist,
hebelt den Personenschutz aus.

> **Normen:** DIN VDE 0100-540 (Erdungsanlagen, Schutzleiter),
> DIN VDE 0100-410 / IEC 60364-4-41 (Schutzmaßnahme automatische
> Abschaltung), DIN EN IEC 60445 (VDE 0197) — Kennzeichnung

---

## 1. PE – Schutzleiter (Protective Earth)

Der Schutzleiter verbindet die berührbaren leitfähigen Teile eines
Betriebsmittels (den Körper) niederohmig mit Erde. Seine einzige
Aufgabe: **Personenschutz gegen elektrischen Schlag.**

```
Isolationsfehler im Gerät
        │
        │  Fehlerstrom über PE
        ▼
   Schutzeinrichtung (Sicherung/RCD) löst aus
```

Tritt ein Isolationsfehler auf (z. B. Kurzschluss zwischen
spannungsführender Ader und Gehäuse), muss über den PE ein
ausreichend hoher Fehlerstrom fließen können, damit die
vorgeschaltete Schutzeinrichtung innerhalb der geforderten Zeit
abschaltet. Bemessung und Ausführung regelt **DIN VDE 0100-540**,
die zugehörige Schutzmaßnahme (automatische Abschaltung der
Stromversorgung) **DIN VDE 0100-410**. Zur Netzform-Abhängigkeit
(TN/TT/IT) siehe → Artikel „TN-, TT- und IT-Netze".

**Kennzeichnung:** Farbe **grün-gelb** — ausschließlich dem
Schutzleiter vorbehalten, für keinen anderen Zweck zulässig.
Kennbuchstabe **PE**.

---

## 2. FE – Funktionserde (Functional Earth)

Die Funktionserde sieht aus wie eine Spielart des PE, dient aber
**nicht dem Personenschutz**, sondern der einwandfreien *Funktion*
eines Betriebsmittels: als Bezugspotential für elektronische
Schaltungen, zur Ableitung von EMV-Störströmen oder als
Potentialausgleich in IT-/Kommunikationsanlagen (ICT).

Erst die aktuelle Fassung von **DIN EN IEC 60445 (VDE 0197)**
trennt Funktionserdung normativ klar von der Schutzerdung und
ergänzt eigene Anforderungen an Funktionserdung und
Funktionspotentialausgleich für informationstechnische Anlagen.
Der zugehörige Leiter trägt den Kennbuchstaben **FE**.

**Kennzeichnung:** Seit der Fassung **2023** sieht die Norm als
bevorzugte Kennfarbe **Rosa** vor — ausdrücklich *nicht*
grün-gelb, um Verwechslungen mit dem Schutzleiter von vornherein
auszuschließen.

---

## 3. Der entscheidende Unterschied

| | **PE** | **FE** |
|---|---|---|
| Zweck | Personenschutz | Funktionspotential / EMV / ICT |
| Pflicht bei Fehler | Muss Fehlerstrom sicher führen | Keine Schutzfunktion |
| Farbe (DIN EN 60445) | Grün-Gelb | Rosa |
| Dimensionierung | Auf Kurzschlussstrom ausgelegt | Häufig dünner dimensioniert |
| Darf ersetzen | — | **niemals den PE** |

**Praxis-Warnung:** Eine Funktionserde darf einen Schutzleiter nie
ersetzen. Ein FE-Leiter ist in der Regel nicht auf den im
Fehlerfall auftretenden Kurzschlussstrom ausgelegt — wird er
versehentlich als PE genutzt, entfällt der Personenschutz
vollständig, ohne dass das auf den ersten Blick auffällt (beide
Leiter „gehen auf Erde").

---

## 4. Bezug zur Schirmung

Auch der Bezugspunkt eines Kabelschirms ist eine Funktionsmaßnahme
(EMV), keine Schutzmaßnahme — Schirme werden daher konzeptionell
eher der Funktionserde als dem Schutzleiter zugeordnet, auch wenn
sie in der Praxis oft direkt an eine PE-Schiene aufgelegt werden.
Details zu ein-/beidseitiger Schirmerdung, Feldtypen und
Schirmkontaktierung → Artikel „Schirmung — Konzepte, Feldtypen und
Praxis".

---

## Quellen

- DIN VDE 0100-540 (VDE 0100-540):2024-06 — Erdungsanlagen und Schutzleiter
- DIN VDE 0100-410 / IEC 60364-4-41 — Schutzmaßnahme: automatische Abschaltung der Stromversorgung
- DIN EN IEC 60445 (VDE 0197):2023-02 — Kennzeichnung von Anschlüssen und Leitern
- Deutsche Kommission Elektrotechnik (DKE), Normendokumentation zu DIN VDE 0100-540
- WEKA Produktsicherheit: „Kennzeichnung von Kabeln und Leitern nach neuer DIN EN 60445 (VDE 0197)"
- Elektropraktiker: „Anschlusskennzeichnung bei Maschinen- und Anlagentechnik: DIN EN 60445 (VDE 0197)"

*Hinweis: Normbezeichnungen und -inhalte können sich mit neuen
Ausgaben ändern. Für die verbindliche Auslegung im konkreten
Projekt gilt stets die jeweils aktuell gültige Normfassung im
VDE-Verlag bzw. bei der DKE.*
