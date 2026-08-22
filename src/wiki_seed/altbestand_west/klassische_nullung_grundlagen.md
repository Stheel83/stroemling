# Klassische Nullung – Grundlagen

Die klassische Nullung ist eine Schutzmaßnahme gegen gefährliche
Berührungsspannung, die **ca. 1913 von der AEG eingeführt** wurde und
in Deutschland bis 1973 (BRD) für Neuanlagen zulässig war. Trotz des
Verbots für Neuanlagen ist sie in Millionen von Altbestandsanlagen
noch aktiv – mit erheblichen Sicherheitsrisiken.

---

## Was ist die klassische Nullung?

Bei der klassischen Nullung (Fachbegriff: **TN-C-System**) übernimmt
ein einzelner Leiter – der **PEN-Leiter** – gleichzeitig zwei Aufgaben:

- **N** (Neutralleiter): führt den Betriebsstrom zurück
- **PE** (Schutzleiter): verbindet Gehäuse mit Erde zum Schutz bei Fehlerstrom

Das Ergebnis: In 2-adrigen Leitungen gab es nur **Phase + PEN** —
kein separater Schutzleiter. Gehäuse von Geräten und Steckdosen-Schutzkontakte
wurden auf diesen kombinierten PEN aufgelegt.

```
Trafo/Netz  ─────────────── L (Phase)  ─────── Verbraucher
                 │                                    │
            PEN-Leiter  ─────────────────────── Gehäuse/N/PE
            (kombiniert)
```

**Vorteile damals:** Kostengünstig, weniger Kupfer, einfache Verlegung.  
**Nachteil:** Jede Unterbrechung des PEN macht das Gehäuse zur Spannungsquelle.

---

## Gefahren der klassischen Nullung

### 1. PEN-Leiter-Abriss (größte Gefahr)

Bricht der PEN-Leiter — durch Korrosion, schlechte Klemme, Beschädigung
oder bei Aluminiumleitern durch Kriechbruch — während der Außenleiter
(L) noch verbunden ist, liegt an **allen angeschlossenen Gehäusen die
volle Netzspannung (230 V) gegen Erde** an. Lebensgefahr!

```
           Abriss des PEN-Leiters
                    ✂
L ─────── Verbraucher ─────── (PEN unterbrochen) ─ Erde
                │
           Gehäuse = 230 V !
```

### 2. Spannungsabfall im Normalbetrieb

Schon im regulären Betrieb fließt der Betriebsstrom durch den PEN-Leiter.
Durch den Leitungswiderstand entsteht dabei eine **Spannung zwischen Gehäuse
und Erde** — in schlecht ausgelegten Anlagen fühlbar bis schmerzend.

### 3. Nullpunktverschiebung bei Drehstrom

Bei unsymmetrischer Belastung der drei Phasen verschiebt sich der Neutralpunkt.
An Gehäusen können dadurch **Brummspannungen** entstehen, auch ohne Fehler.

### 4. Besonderes DDR-Risiko: Aluminium-PEN

In DDR-Gebäuden war der PEN-Leiter oft aus Aluminium (2,5 mm²). Alu
kriecht unter Klemmdruck, die Verbindung lockert sich — PEN-Unterbrechungen
waren damit deutlich häufiger als in Kupfer-Anlagen.
(→ Artikel: „Aluminium-Leitungen nach DDR-Norm TGL")

---

## Systemvarianten im Überblick

| System    | PEN?  | PE und N getrennt? | Sicherheit   | Zulässig für Neuanlagen |
|-----------|:-----:|:------------------:|:------------:|:-----------------------:|
| TN-C      | ja    | nein               | gering       | ⛔ verboten (DE ab 1973) |
| TN-S      | nein  | ja                 | hoch         | ✅ Standard heute       |
| TN-C-S    | teilw.| ab Hauseinführung  | mittel–hoch  | ✅ üblich in DE          |
| TT        | nein  | ja (eigene Erde)   | hoch         | ✅ z.B. Österreich häufig|

**TN-C-S** ist der deutsche Standard heute: Das Netz führt einen PEN-Leiter,
der am **Hausanschluss** (Haupterdungsschiene / HAK) in getrennten PE und N
aufgeteilt wird. Ab diesem Punkt gibt es zwei separate Leiter.

---

## Technische Mindestanforderungen für PEN-Leiter

Damit die Sicherung bei einem Gehäuseschluss überhaupt auslöst, muss
der PEN-Leiter einen **ausreichend niedrigen Impedanzpfad** bieten.
VDE 0100/5.73 §10a schrieb erstmals vor:

- Mindestquerschnitt: **10 mm² Kupfer** oder **16 mm² Aluminium**
- Bei kleineren Querschnitten ist die Abschaltbedingung nicht sicher erfüllbar

> In der Praxis wurde diese Mindestanforderung in Altanlagen häufig
> nicht eingehalten — insbesondere in DDR-Wohngebäuden mit 2,5mm²-Alu-Leitungen.

---

## FI-Schutzschalter (RCD) in TN-C-Anlagen

**FI-Schutzschalter können in TN-C-Systemen nicht eingesetzt werden** —
sie würden im Normalfall permanent auslösen, weil N und PE am Gerät
zusammengeführt sind. (DIN VDE 0100-410 §411.4.5 verbietet es explizit.)

Für Anlagen mit klassischer Nullung bleibt als Schutzverbesserung:
1. Umbau auf TN-S (separate PE und N verlegen) — aufwendig
2. Zumindest in Bad/Küche auf 3-Leiter-System nachrüsten
3. RCD erst nach Auftrennung von PEN in PE+N einsetzen

---

## Bestandsschutz

Ordnungsgemäß errichtete Anlagen dürfen in ihrem ursprünglichen Zustand
**weiterbetrieben** werden — auch wenn sie neue Normen nicht erfüllen.

**Bestandsschutz erlischt** bei:
- Erweiterungen oder wesentlichen Änderungen der Anlage
- Neuvermietung (in Österreich verpflichtend RCD-Nachrüstung, ETV 2020)

In Deutschland gibt es **keine gesetzliche Nachrüstpflicht** für
Bestandsanlagen — aber eine klare Empfehlung für Räume mit Badewanne/Dusche
(DIN VDE 0100-700) und eine moralische Verantwortung des Eigentümers.

---

## Quellen

- Wikipedia: [Nullung](https://de.wikipedia.org/wiki/Nullung)
- Wikipedia: [TN-Netz](https://de.wikipedia.org/wiki/TN-Netz)
- Wikipedia: [Schutzmaßnahme (Elektrotechnik)](https://de.wikipedia.org/wiki/Schutzma%C3%9Fnahme_(Elektrotechnik))
- elektro.net: [Klassische Nullung im Anlagenbestand](https://www.elektro.net/praxisprobleme/klassische-nullung-im-anlagenbestand/)
- Elektropraktiker: [Bestandsschutz und Anpassung elektrischer Anlagen](https://www.elektropraktiker.de/fachartikel/detail/bestandsschutz-und-anpassung-elektrischer-anlagen-1)

*Hinweis: Die DDR-spezifischen Details (TGL-Bezeichnung, Aluminium-PEN-
Verbreitung) stammen aus Felderfahrung und sind schwerer über
Web-Quellen zu verifizieren als die BRD/VDE-Fakten — bei Bedarf gegen
Originaldokumente aus DDR-Normensammlungen gegenprüfen.*
