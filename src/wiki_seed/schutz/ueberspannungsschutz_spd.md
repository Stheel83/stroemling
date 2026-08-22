# Überspannungsschutz – SPD Typ 1 / 2 / 3

Überspannungen durch Blitz oder Schalthandlungen können Geräte
zerstören. SPD (Surge Protective Device) leitet Überspannungsimpulse
kontrolliert ab.

> **Norm:** DIN EN 61643-11 (VDE 0675-6-11), DIN VDE 0100-443 / -534

---

## Die drei SPD-Typen

| Typ | Frühere Bezeichnung | Installationsort | Stoßstrom |
|:---:|:-------------------:|-----------------|:---------:|
| **Typ 1** | Klasse B / Blitzstromableiter | Hauptverteiler, Gebäudeeinführung | 12,5–25 kA (10/350 µs) |
| **Typ 2** | Klasse C / Überspannungsableiter | Unterverteiler, Stockwerkverteiler | 5–40 kA (8/20 µs) |
| **Typ 3** | Klasse D / Geräteschutz | Direkt am Gerät, Steckdose | 1,5–10 kA (8/20 µs) |

---

## Typ 1 — Blitzstromableiter (Gebäudeeinführung)

**Wann:** Wenn das Gebäude einen **äußeren Blitzschutz** (Blitzableiter) hat
oder wenn die Energieversorgung über Freileitung kommt.

**Installationsort:** Im Hauptverteiler (HAK-Nähe), so nah wie möglich
an der Gebäudeeinführung.

**Schutzprinzip:** Leitet direkte Blitzstromanteile ab. Übersteht den
vollen Blitzstrom (Wellenform 10/350 µs = langsam abklingend, energiereich).

Pflicht nach DIN VDE 0100-534 wenn:
- Äußerer Blitzschutz vorhanden
- Einspeisung über Freileitung
- Gebäude in Klasse LPS I–IV (Blitzschutzzone 0A → 1)

---

## Typ 2 — Überspannungsableiter (Unterverteiler)

**Wann:** In **jedem** Unterverteiler — als Grundschutz auch ohne äußeren
Blitzschutz empfohlen (Schalthandlungen im Netz).

**Installationsort:** Am Anfang jedes Unterverteilers (nach LSS-Einspeisung).

**Schutzprinzip:** Begrenzt Überspannungen, die Typ 1 durchlässt, auf ein
Niveau, das normale Geräte überstehen.

**Empfehlung:** DIN VDE 0100-443 empfiehlt Typ 2 in allen Neubauten.
In Gebäuden mit Blitzschutz: Typ 1+2 kombiniert oder direkt Kombiableiter.

---

## Typ 3 — Geräteschutz (Endverbraucher)

**Wann:** Für empfindliche Geräte (Server, Messtechnik, HiFi, medizinische
Geräte) direkt am Gerät oder als Steckdosenleiste mit SPD.

**Installationsort:** Direkt vor dem zu schützenden Gerät.

**Schutzprinzip:** Feinschutz — begrenzt verbleibende Restüberspannung
aus Typ 1 und 2 auf geräteverträgliche Werte.

> Typ 3 allein (ohne Typ 2 im Verteiler) ist nicht ausreichend —
> er ist für die alleinige Ableitung zu schwach.

---

## Koordination (Zusammenspiel der Typen)

Alle drei Typen müssen koordiniert eingesetzt werden:

```
Netz → [Typ 1 im HAV] → [Typ 2 im UV] → [Typ 3 am Gerät]
```

Mindestleitungslänge zwischen den Typen: **10 m** (VDE 0100-534).
Kürzer → Koordination über Entkoppelinduktivität (L ≥ 1,5 µH).

Ohne ausreichenden Abstand löschen die Typen sich gegenseitig aus
(Energie läuft zurück).

---

## Schutzpegel U_p und Geräteempfindlichkeit

Der **Schutzpegel U_p** gibt die maximale Spannung an, die der SPD
am Ausgang zulässt.

| Gerätetyp | Max. Stoßspannungsfestigkeit (Überspannungskategorie) |
|-----------|:----------------------------------------------------:|
| Haushaltsgeräte, Unterhaltungselektronik | Kategorie II: 2,5 kV |
| Installationsmaterial, Verteiler | Kategorie III: 4 kV |
| Zähler, Einspeisung | Kategorie IV: 6 kV |

SPD Typ 2 sollte U_p ≤ 1,5 kV haben, um Kategorie-II-Geräte zu schützen.

---

## Wann ist SPD Pflicht?

| Situation | Pflicht? | Norm |
|-----------|:--------:|------|
| Äußerer Blitzschutz vorhanden | Ja (Typ 1+2) | VDE 0100-534 |
| Freileitung zur Einspeisung | Ja (Typ 1+2) | VDE 0100-534 |
| Neubau Wohngebäude | Empfohlen (Typ 2) | VDE 0100-443 |
| Empfindliche Geräte (IT, Medizin) | Empfohlen (Typ 3) | — |
| Altbau ohne Änderung | Kein Nachrüstzwang | — |

---

## Quellen

- elektro.net: [DIN VDE 0100-443 und -534 Überspannungsschutz](https://www.elektro.net/105823/ueberspannungsschutz-ist-nun-pflicht/)
- DEHN: [FAQ-Liste zur DIN VDE 0100-443 und DIN VDE 0100-534](https://www.dehn-international.com/sites/default/files/media/files/FAQ-DIN-VDE-0100-443-534-DS273-DE_1.pdf)
- WEKA: [DIN VDE 0100-443: Worauf Sie jetzt achten müssen](https://www.weka.de/elektrosicherheit/din-vde-0100-443/)

*Hinweis: Ob im Einzelfall SPD-Pflicht besteht (z. B. bei „wesentlichen
Änderungen" einer Bestandsanlage), hängt von der genauen
Risikobeurteilung nach VDE 0100-443 ab — die Tabelle oben ist eine
Praxis-Orientierung, keine Rechtsberatung. Bei Unsicherheit die aktuelle
Normausgabe bzw. eine Elektrofachkraft konsultieren.*
