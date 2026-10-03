# PRCD – Ortsveränderliche Fehlerstrom-Schutzeinrichtungen

Ein **PRCD** (*Portable Residual Current Device*) ist ein FI-Schutzschalter,
der nicht fest im Verteiler sitzt, sondern **zwischen Steckdose und Verbraucher**
gesteckt wird – als Zwischenstecker, als Verlängerungsleitung oder als
Modul in einem mobilen Verteiler. Er rüstet den Personenschutz dort nach, wo
die fest installierte Anlage ihn nicht (sicher) bietet: auf Baustellen, bei
Veranstaltungen, im Rettungseinsatz oder in Altanlagen mit unbekanntem Zustand.

> **Normen:** DIN EN IEC 61540 (VDE 0661-10) — PRCD allgemein, DIN VDE 0661 —
> PRCD-S, DGUV Information 203-006 — Einsatz auf Baustellen,
> DIN 14660 — Feuerwehr. Prüfung: DIN VDE 0701-0702

---

## 1. Was ein PRCD vom Verteiler-FI unterscheidet

| | FI im Verteiler (RCCB/RCBO) | PRCD |
|---|---|---|
| Einbau | fest, in der Verteilung | ortsveränderlich, am Verbraucher |
| Schutzbereich | gesamter nachgelagerter Stromkreis | nur das angeschlossene Gerät |
| Eigene Überwachung der Zuleitung | nein | je nach Variante (PRCD-S: ja) |
| Typische Bemessung | 25–63 A, 30/100/300 mA | 16 A bis 32 A (Module bis 40 A), 30 mA |
| Normen | DIN EN 61008 / 61009 (VDE 0664) | DIN EN IEC 61540 / VDE 0661 |

Der PRCD ersetzt keinen FI in der Verteilung. Er schützt **Personen am
Verbraucher**, wenn die vorgelagerte Installation unbekannt, beschädigt oder
unzureichend ist.

---

## 2. Varianten

### PRCD-S (S = Safety) – der deutsche Standard

Der PRCD-S ist ein **allpolig schaltendes**, ortsveränderliches
Fehlerstrom-Schutzgerät mit elektronischer Fehlerstromauswertung und
erweitertem Schutzumfang. Er wird von der DGUV für Baustellen vorausgesetzt.

Schutzumfang (zusätzlich zum 30-mA-Fehlerstromschutz):

- **Unterspannungsauslösung:** bei Netzausfall fällt das Gerät ab und
  schaltet nach Netzwiederkehr **nicht von selbst wieder ein**
  (Wiederanlaufsperre – manuell einschalten).
- **Schutzleitererkennung:** Fehlt der PE oder ist er vertauscht,
  lässt sich der PRCD-S nicht einschalten.
- **Schutzleiterüberwachung:** Der PE wird beim Einschalten **und im
  Betrieb** überwacht; bei Unterbrechung löst das Gerät aus.
- **Fremdspannungserkennung am PE:** Liegt Spannung auf dem Schutzleiter
  (z. B. durch einen Fehler in der vorgelagerten Anlage), lässt sich der
  PRCD-S nicht einschalten bzw. schaltet ab.
- **Prüftaste** zur Funktionsprüfung vor jedem Einsatz.

Da er auch bei Fehlern in der Zuleitung nicht einschaltet, schützt der
PRCD-S nicht nur das angeschlossene Gerät, sondern warnt auch vor einer
**gefährlichen Steckdose**.

### PRCD-S+ / PRCD-K / PRCD-K+ (herstellerabhängige Bezeichnungen)

Manche Hersteller führen Varianten wie **PRCD-S+** oder **PRCD-K+**.
Nach den vorliegenden Herstellerunterlagen gilt:

- **PRCD-S / S+:** setzt einen vorhandenen **Schutzleiter (PE/PEN)** voraus –
  er überwacht ihn ja.
- **PRCD-K / K+:** vorgesehen für **IT-Systeme**, z. B. Notstromaggregate
  oder Trenntrafos, bei denen der Schutzleiter-Bezug des PRCD-S nicht
  passt.

> Die genaue Abgrenzung (K = „?") ist in den gefundenen Quellen nicht
> einheitlich erklärt. Im Zweifel das Datenblatt des Herstellers heranziehen.

### PRCD ohne „S"

Ein PRCD nach IEC/EN 61540 **ohne** die zusätzlichen S-Funktionen bietet nur
den Fehlerstromschutz. Er überwacht den Schutzleiter nicht und ist für den
Baustelleneinsatz nach DGUV in der Regel **nicht** ausreichend.

---

## 3. Fehlerstromtypen

| Ausführung | Typ | Typische Anwendung |
|---|:---:|---|
| 1-phasig, 230 V, 16 A | A | Handwerker-Zwischenstecker, Baustellenverlängerung |
| 3-phasig, 400 V, 16/32 A (CEE) | **B** | Drehstromverbraucher, Baustellenverteiler, Umrichter |

**Dreiphasige PRCD-S müssen mit einem RCD vom Typ B (allstromsensitiv)
ausgestattet sein.** Typ B erkennt auch glatte Gleichfehlerströme, wie sie
Frequenzumrichter und Wechselrichter erzeugen können. Einzelne Module
erkennen zusätzlich Gleichfehlerströme ab **6 mA**. Allgemeines zu
RCD-Typen → Artikel „RCD-Typen – Welcher FI-Schutzschalter wofür?".

---

## 4. Bauformen

| Bauform | Beschreibung |
|---|---|
| **Zwischenstecker** | PRCD-Gehäuse direkt zwischen Schuko-Stecker und -Kupplung. Kompakt, meist 1-phasig. |
| **Verlängerungsleitung** | Stecker – Leitung – PRCD – Kupplung. Der PRCD sitzt in der Leitung. |
| **CEE-Variante** | Rundstecker/Kupplung 16 A oder 32 A, 5-polig, 400 V für Drehstrom. |
| **Steckdosenleiste / Verteiler** | PRCD fest in einen mobilen Verteiler eingebaut, mehrere Abgänge. |
| **Basiskomponente / Modul** | Hutschienenmodul zum Einbau in eigene Gehäuse (z. B. 40 A, 8 TE). Wird von Verteilerbauern verwendet; dasselbe Modul steckt unter mehreren Marken. |
| **Kabelmodul** | Eingegossen in Steckvorrichtung/Leitung, hohe Schutzart (z. B. IP55). |

Schutzart: üblich **IP44** bis **IP55** für Baustelle und Veranstaltung,
höhere Werte bei Sonderausführungen.

---

## 5. Einsatz und Prüfung

**Wann ein PRCD-S sinnvoll oder gefordert ist:**

- Baustellen, wenn keine Baustromverteiler mit fest eingebautem
  Fehlerstromschutz zur Verfügung stehen (DGUV I 203-006)
- Veranstaltungs- und Messetechnik, Aufbau an unbekannten Anschlüssen
- Feuerwehr/Rettungsdienst (DIN 14660)
- Nachrüstung von Altanlagen mit unbekannter oder unzureichender
  Schutzmaßnahme

**Vor jedem Einsatz:** Sichtprüfung des Gehäuses und der Leitung, dann
Funktionsprüfung mit der **Prüftaste**.

**Wiederkehrende Prüfung** nach DIN VDE 0701-0702 (Intervall nach
Gefährdungsbeurteilung). Dazu gibt es spezielle **PRCD-Prüfadapter** bzw.
Prüfgeräte, die Auslösezeit und Auslösestrom, Schutzleiterüberwachung,
Fremdspannungs- und Unterspannungsfunktion messen.

---

## 6. Im Schaltplan

Der PRCD wird im Schaltplan als **FI-Schutzeinrichtung mit Überwachungsfunktionen**
dargestellt und je nach Bedeutung unterschiedlich ausgeführt:

- als Schutzeinrichtung **vor einem mobilen Verbraucher** oder Verteiler,
- mit Angabe von **Typ (A/B)**, **Bemessungsstrom** und **I_Δn = 30 mA**,
- bei Verteilern mit eingebautem PRCD zusätzlich der Abgangskreise.

Bauteilkennzeichnung nach DIN EN 81346 – siehe Artikel „BMK nach DIN EN 81346".

---

## Quellen

- DIN EN IEC 61540 (VDE 0661-10): [VDE-Verlag](https://www.vde-verlag.de/standards/1600384/e-din-en-iec-61540-vde-0661-10-2021-12.html)
- BG BAU: [PRCD-S Anforderungen](https://www.bgbau.de/fileadmin/Produkte/Arbeitsschutzpraemie/PRCD-S_Anforderungen.pdf)
- Mennekes: [PRCD-Whitepaper](https://www.mennekes.de/fileadmin/MEN-Deutschland/plugs_sockets/Service/Whitepaper/ip_cee_whitepaper_prcd_de_0426.pdf)
- Mennekes: [PRCD-Katalog](https://www.mennekes.de/fileadmin/MEN-Deutschland/plugs_sockets/Service/Kataloge_Prospekte/mennekes_prcd_0226.pdf)
- Doepke: [DPRCD-M1 Typ B, Art.-Nr. 09342100](https://www.doepke.de/de/produkte/schuetzen/ortsvera-nderliche-fehlerstrom-schutzeinrichtungen-prcd/basiskomponente/fehlerstromtyp-b/09342100)
- PCE: [PRCD-S+ Betriebsanleitung](https://www.pcelectric.at/tradepro/shop/artikel/allgemein/11189%20Betriebsanleitung%2004-2021%20V2.1.pdf)
- IDF NRW: [Personenschutzeinrichtungen](https://www.idf.nrw.de/dokumente/dienstleistungen/kompetenzzentrum/personenschutzeinrichtungen1.pdf)

*Hinweis: Normbezeichnungen und -stände ändern sich. Die Norm
DIN EN IEC 61540 lag zuletzt (Stand der Recherche) als Entwurf 12/2021 vor.
Für die verbindliche Auslegung gilt die jeweils aktuell gültige Fassung im
VDE-Verlag; für den Baustelleneinsatz die DGUV Information 203-006.*
