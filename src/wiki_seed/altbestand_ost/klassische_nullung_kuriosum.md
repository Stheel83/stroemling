# Kuriosum: 3-adrig verdrahtet, aber klassisch genullt

Ein besonderes DDR-Phänomen, das bei Elektrikern regelmäßig für
Verwirrung sorgt: **drei Adern im Rohr, aber PE und N gemeinsam
auf die Hauptklemme geführt** — klassische Nullung trotz dreiadriger
Verlegung.

> **Quellen:**
> - Wikipedia: [Nullung](https://de.wikipedia.org/wiki/Nullung)
> - Wikipedia: [TN-Netz](https://de.wikipedia.org/wiki/TN-Netz)

---

## Was wurde verbaut?

In DDR-Wohngebäuden der 1960er und 1970er Jahre findet man häufig:

```
Rohr mit 3 Adern:
  L    (Phase)      — schwarz
  PEN  (N + PE)     — hellblau oder hellgrau
  3. Ader           — separat verlegt, aber:
                       direkt auf die PEN-Schiene aufgelegt!
```

Das Ergebnis: **Die 3. Ader endet am Verteiler auf derselben Klemme
wie der PEN-Leiter.** Gehäuse, Schutzkontakte und Neutralleiter sind
elektrisch verbunden. Funktionell ist das eine klassische Nullung —
trotz der drei Adern.

---

## Warum wurde so gebaut?

Die Antwort liegt nicht beim Elektriker vor Ort — sondern im System dahinter.

### Das eigentliche Problem: Die Einspeisung war TN-C

Ein 3-adriges Kabel allein macht noch kein TN-S-System. Dafür braucht man
drei Dinge gleichzeitig:

1. Einen getrennten PE-Leiter **bis zum Unterverteiler**
2. Eine **separate PE-Schiene** im Unterverteiler
3. Einen Anschluss an echtes **Erdpotenzial** (Fundamenterder oder Gebäudeerdung)

In DDR-Plattenbau-Wohnungen kam die Einspeisung vom Stockwerksverteiler
typischerweise als **L + PEN** — zwei Leiter. Kein separates PE-Potential.
Der Stockwerksverteiler hatte meist nur eine einzige Neutral-/Schutzleiterschiene,
auf der alles gemeinsam lag. Es gab schlicht keine PE-Schiene zum Anschließen.

**Die 3. Ader endete also auf der einzigen Schiene — der PEN-Schiene.**
Drei Adern im Rohr, aber N und PE auf dem gleichen Potential. Funktionell
klassische Nullung.

### Vier Gründe, warum trotzdem 3-adrig verlegt wurde

**1. Norm im Übergang — Infrastruktur hinkt hinterher**
Die TGL-Norm forderte ab ~1973 zunehmend 3-adrige Verlegung in Küche und Bad,
ohne gleichzeitig die Verteilerinfrastruktur (Einspeisung, PE-Schienen) anzupassen.
Die Norm war der Realität voraus.

**2. Planwirtschaft: Was im Lager war, wurde verbaut**
3-adriges Kabel war verfügbar — also kam 3-adriges Kabel rein, unabhängig davon,
ob das System die dritte Ader sinnvoll nutzen konnte.

**3. Handwerkergewohnheit**
Der Elektriker verdrahtete wie immer. Die dritte Ader kam auf die einzige
vorhandene Schiene — was sonst? Eine separate PE-Schiene hätte zuerst
jemand einbauen müssen.

**4. Optische Compliance**
Die Anlage *sah* normgerecht aus (3 Adern = modernes System), war es
funktionell aber nicht. Das reichte für die Abnahme.

> **Kurzfassung:** Drei Adern bringen nichts, wenn der Verteiler nur
> eine Schiene hat und die Einspeisung nur zwei Leiter liefert. Das
> 3-adrige Kabel war eine Vorstufe ohne vollständige Infrastruktur dahinter.

---

## Die typische Fundkonstellation

```
Unterverteiler (DDR-Altbau):

  Einspeisung:  L1 + PEN vom Zähler
                     |
                  PEN-Schiene ------- N-Adern aller Stromkreise
                               ------- PE-Adern aller Stromkreise
                               ------- Gehäuse Verteilerkasten
```

Am Steckdosenauslass sieht es formal korrekt aus:
- Schutzkontakt mit grüner (oder grün-gelber, oder grauer) Ader
- Neutralkontakt mit hellblauer Ader

Aber beide führen zum gleichen PEN-Potential. Es **gibt keinen echten PE** —
nur einen PEN, der doppelt ausgezweigt wurde.

---

## Die Gefahr: doppelt so gefährlich wie gedacht

Klassische Nullung allein ist schon gefährlich (Spannung bei PEN-Abriss).
Dieses DDR-Kuriosum potenziert das Risiko:

**Beide Leiter (N und vermeintlicher PE) hängen am gleichen PEN.**
Bricht dieser PEN an einer Verbindung, stehen **N-Kontakt und
PE-Kontakt gleichzeitig auf 230 V** — auch wenn ein RCD verbaut wäre,
würde er nicht auslösen (kein Differenzstrom fließt, der Mensch
ist die Verbindung).

Hinzu kommt das **Aluminium-Problem**: DDR-PEN-Leiter waren oft aus
Alu (2,5 mm²), das unter Klemmdruck kriecht und Verbindungen lockert.
Ein Aluminium-Kriechbruch am PEN = volle Spannung auf PE- und N-Kontakt gleichzeitig.

---

## Erkennungsmerkmale im Feld

| Merkmal                                      | Hinweis auf DDR-Kuriosum                   |
|----------------------------------------------|--------------------------------------------|
| 3 Adern in Rohr / Kabelkanal                 | äußerlich wie TN-S                         |
| PE-Ader endet auf PEN-Schiene                | klassische Nullung trotz 3 Adern           |
| Messung: PE gegen Erde ≠ 0 V               | Spannungsabfall über PEN-Leiter sichtbar   |
| Aluminium-Leitungen (silbrige Aderenden)     | hohes Kriechbruch-Risiko                   |
| Unterverteiler ohne separate Erdungsschiene  | PE und N auf gemeinsamer Klemme            |
| Schutzleiter-Farbe: grün (einfarbig)        | DDR-Norm — kein BRD-Grün-Gelb              |

---

## Was tun?

1. **Messen statt vertrauen:** Spannungsmessung PE gegen N und PE gegen Erde
2. **Schleifenimpedanz messen:** Nur so lässt sich die Abschaltbedingung prüfen
3. **Nie RCD direkt einbauen** ohne vorherige Prüfung — in TN-C löst er nicht aus
4. **Umbau auf echtes TN-S:** Separate PE-Schiene einbauen, PE-Adern vom PEN trennen,
   Erdleitung (Schutzpotenzial) vom Gebäudeerder oder HAK anbinden
5. **Priorität: Bad und Küche** — VDE 0100-700 fordert hier sowieso 3-Leiter + RCD

---

## Historischer Hintergrund

Die klassische Nullung war in der DDR **nie formell verboten worden** —
sie war in den TGL-Normen nur schrittweise zurückgedrängt worden.
Nach der Wiedervereinigung 1990 galten die VDE-Normen auch für
Ostdeutschland, aber bestehende Anlagen bekamen **Bestandsschutz**.

Das bedeutet: In Plattenbausiedlungen und Altbauten der neuen Bundesländer
existiert diese Konstellation bis heute — und wird erst beim Umbau,
beim Eigentümerwechsel oder nach einem Schadensfall angepackt.

> Faustregel: **Gebäude DDR-Baujahr vor 1980 in der Wand = klassische
> Nullung bis zum Beweis des Gegenteils.**
