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

Zwei Gründe:

**1. Norm-Übergangsphase ohne klare Vorgabe**
Die TGL-Norm (DDR-Normensystem) forderte ab den frühen 1970ern
zunehmend eine 3-adrige Verlegung in bestimmten Räumen. Aber die
Trennung von PE und N am Verteiler war technisch komplex — es fehlte
an separaten PE-Schienen und an Installateurskenntnis.

**2. Kein separater PE-Potential am Verteiler vorhanden**
Viele DDR-Unterverteiler hatten schlicht keine Erdungsschiene (PE-Schiene).
Der einzige Anschlusspunkt für Schutzpotenzial war der PEN-Leiter
vom Netz. Also kam die 3. Ader dort hin.

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
