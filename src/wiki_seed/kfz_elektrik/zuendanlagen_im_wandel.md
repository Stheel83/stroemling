# Zündanlagen im Wandel: Kontaktzündung → elektronische Zündung → Steuergerät

Kaum ein Bauteil zeigt den elektrotechnischen Fortschritt im Kfz so deutlich
wie die Zündanlage: vom mechanischen Unterbrecherkontakt bis zur vollständig
computerberechneten Einzelfunken-Zündung im modernen Motorsteuergerät.

---

## 1. Kontaktzündung (Batterie-Spulenzündung, bis in die 1960er/70er)

Klassisches Prinzip: Ein mechanischer **Unterbrecherkontakt** im Verteiler
öffnet und schließt den Primärstromkreis der Zündspule. Beim Öffnen bricht
das Magnetfeld in der Spule zusammen, es entsteht der Hochspannungsimpuls
für die Zündkerze. Ein **Kondensator** parallel zum Kontakt verhindert
Funkenüberschlag am Kontakt selbst.

**Nachteile:**

- Der volle Primärstrom (mehrere Ampere) fließt durch den mechanischen
  Kontakt → Verschleiß, Abbrand, regelmäßiger Wartungsbedarf (Kontaktabstand
  einstellen, Kontakte reinigen/tauschen)
- Zündzeitpunkt-Verstellung nur über mechanische Fliehkraft- und
  Unterdruckversteller möglich – grob gegenüber heutigen Kennfeldern

## 2. Transistorzündung (ab 1965)

1965 brachte Bosch die **kontaktgesteuerte Transistorzündung (TSZ-k)** auf
den Markt: Der Unterbrecherkontakt bleibt vorhanden, schaltet aber nur noch
einen kleinen Steuerstrom – der eigentliche Primärstrom der Zündspule fließt
durch einen Transistor. Das entlastet den Kontakt erheblich und verlängert
seine Lebensdauer deutlich, beseitigt den mechanischen Verschleiß aber noch
nicht vollständig.

## 3. Kontaktlose (induktive) Zündung (ab 1974) und Hall-Zündung (ab 1977)

1974 kam die **kontaktlose Zündung** auf den Markt: Ein induktiver Sensor
im Verteiler löst den Zündimpuls berührungslos aus – kein mechanischer
Kontakt mehr, kein Verschleiß, kein Nachstellen. 1977 folgte die Variante
mit **Hall-Sensor**, die bis in die 1990er in vielen Fahrzeugen mit
Verteiler-Zündung verbaut wurde. Der Verteiler selbst (rotierende
Hochspannungsverteilung auf die Zündkerzen) blieb dabei mechanisch – nur die
Auslösung des Zündimpulses wurde elektronisch.

## 4. Vollelektronische Zündung mit Kennfeld

Der nächste Schritt war die **vollelektronische Zündung**: Ein Mikrocomputer
berechnet den optimalen Zündzeitpunkt aus einem im Steuergerät gespeicherten
**Zündkennfeld** (abhängig von Drehzahl, Last, Temperatur u.a.) – die
mechanische Fliehkraft-/Unterdruckverstellung entfällt komplett. Damit wurde
die Zündung Teil der zentralen Motorsteuerung, nicht mehr ein eigenständiges
mechanisches System.

## 5. Verteilerlose Zündung / Einzelfunkenspulen (moderne Fahrzeuge)

Heutige Fahrzeuge haben in der Regel **keinen Verteiler mehr**: Jede
Zündkerze bekommt entweder eine eigene **Einzelfunkenspule** (direkt auf der
Kerze aufgesteckt) oder mehrere Zylinder teilen sich eine
**Doppelfunkenspule**. Das Motorsteuergerät schaltet jede Spule einzeln zum
exakt berechneten Zeitpunkt – höhere Präzision, keine mechanischen
Verschleißteile im Zündpfad mehr, und die Zündung ist vollständig in die
Motorsteuerung integriert (→ Kategorie „Motorsteuerung" für angrenzende
Themen wie Einspritzung und Lambdaregelung).

## 6. Übersicht

| Generation | Auslösung | Primärstrom-Schaltung | Zündzeitpunkt |
|---|---|---|---|
| Kontaktzündung | mechanischer Kontakt | mechanischer Kontakt | Fliehkraft/Unterdruck |
| Transistorzündung (1965) | mechanischer Kontakt | Transistor | Fliehkraft/Unterdruck |
| Induktive Zündung (1974) | induktiver Sensor | Transistor | Fliehkraft/Unterdruck |
| Hall-Zündung (1977) | Hall-Sensor | Transistor | Fliehkraft/Unterdruck |
| Vollelektronische Zündung | Sensor | Transistor/Endstufe | Kennfeld im Steuergerät |
| Einzelfunken-/Doppelfunken-Zündung | Kurbelwellen-/Nockenwellensensor | Steuergerät-Endstufen | Kennfeld, zylinderindividuell |

---

## Quellen

- kfztech.de: [Geschichte der Zündung, Teil 1](https://www.kfztech.de/kfztechnik/technikprofi/history/zuendung-history_1.htm) und [Teil 2](https://www.kfztech.de/kfztechnik/technikprofi/history/zuendung-history_2.htm)
- Wikipedia: [Zündung (Verbrennungsmotor)](https://de.wikipedia.org/wiki/Z%C3%BCndung_(Verbrennungsmotor))

*Hinweis: Einführungsjahre gelten für Bosch als führenden Zulieferer und
markieren die Marktverfügbarkeit der jeweiligen Technik – die tatsächliche
Verbreitung in Serienfahrzeugen verschiedener Hersteller zog sich oft über
weitere 5–10 Jahre hin.*
