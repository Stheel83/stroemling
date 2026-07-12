# Bordnetz-Architektur: vom Einzelstromkreis zum CAN-/LIN-Bus

Frühe Fahrzeuge hatten für jeden Verbraucher eine eigene, direkte Leitung
zum Schalter. Mit steigender Funktionsvielfalt wurde das unhaltbar – die
Antwort war eine grundlegend neue Bordnetz-Architektur: der Datenbus.

---

## 1. Das Problem der klassischen Punkt-zu-Punkt-Verkabelung

In einem klassischen Kabelbaum führt jede Funktion (jeder Schalter, jeder
Sensor, jeder Aktor) eine eigene, durchgehende Leitung zum jeweiligen
Steuergerät oder direkt zum Verbraucher. Mit zunehmender Ausstattung
(elektrische Fensterheber, Zentralverriegelung, ABS, Klimaautomatik,
Bordcomputer …) wuchs der Kabelbaum immer weiter – mehr Gewicht, mehr
Steckverbinder, mehr potenzielle Fehlerquellen, höhere Fertigungskosten.

## 2. CAN-Bus: die Lösung für sicherheitsrelevante/schnelle Kommunikation

Der **CAN-Bus (Controller Area Network)** wurde ab 1983 bei Bosch
entwickelt und 1986 auf der SAE-Konferenz in Detroit vorgestellt. Statt
vieler Einzelleitungen kommunizieren alle angeschlossenen Steuergeräte über
**eine gemeinsame, zweiadrige Leitung** – jede Nachricht trägt eine
Kennung, jedes Steuergerät „hört" mit und verarbeitet nur die für sich
relevanten Nachrichten. 1991 kam mit dem Mercedes-Benz W140 (S-Klasse) das
erste Serienfahrzeug mit CAN-basierter Mehrfachverkabelung auf den Markt.

**Vorteile:**

- Drastisch weniger Leitungen und Steckverbinder
- Neue Funktionen lassen sich softwareseitig ergänzen, ohne neue Leitungen
  zu verlegen
- Steuergeräte können Daten austauschen (z.B. nutzt das ABS-Steuergerät
  Raddrehzahlen, die auch die Motorsteuerung braucht) statt redundanter
  Einzelsensoren

## 3. LIN-Bus: die kostengünstige Ergänzung

CAN-Bus-Hardware ist für einfache Nebenverbraucher (Fensterheber-Taster,
Türschloss-Aktor, Sitzheizungsschalter) unnötig aufwendig und teuer. Mitte
1999 veröffentlichte das **LIN-Konsortium** (gegründet u.a. von BMW,
Volkswagen-Konzern, Audi, Volvo und Mercedes-Benz) das erste
**LIN-Protokoll (LIN 1.0)** – ein einfacher, günstiger Ein-Draht-Bus als
Ergänzung zum CAN-Bus für genau solche unkritischen Nebenfunktionen.

| Merkmal | CAN-Bus | LIN-Bus |
|---|---|---|
| Leitungen | 2 (verdrillt, differentiell) | 1 |
| Geschwindigkeit | bis zu 1 Mbit/s (klassisch) | max. 20 kbit/s |
| Kosten je Knoten | höher | deutlich günstiger |
| Typischer Einsatz | Motor, ABS, Airbag, Getriebe | Fensterheber, Sitzverstellung, Klimaklappen |
| Architektur | Multi-Master (alle gleichberechtigt) | Master-Slave (ein Master steuert) |

## 4. Weitere Bussysteme (Ausblick)

Für noch höhere Datenraten (Infotainment, Fahrerassistenzsysteme,
Kamerabilder) reicht klassischer CAN-Bus nicht mehr aus – moderne
Fahrzeuge nutzen zusätzlich **CAN-FD** (höhere Datenrate), **FlexRay**
(zeitgesteuert, für sicherheitskritische Echtzeitanwendungen wie
Fahrwerksregelung) und zunehmend **Automotive Ethernet** für
bandbreitenintensive Anwendungen. Diese Systeme im Detail zu behandeln
würde den Rahmen dieses Wiki-Bereichs sprengen – wichtig für Hobbyisten ist
vor allem das Grundverständnis: Moderne Fahrzeuge sind vernetzte
Steuergeräte-Systeme, keine Ansammlung unabhängiger Einzelstromkreise mehr.

## 5. Konsequenz für Diagnose und Reparatur

Die Bus-Architektur ist einer der Hauptgründe, warum moderne Kfz-Diagnose
nicht mehr mit einem einfachen Multimeter allein auskommt (→ Artikel
„Diagnose im Wandel: OBD → OBD-II → Gateway-Steuergeräte") – ein
Signalausfall kann an vielen Stellen im Bussystem liegen, nicht nur direkt
am betroffenen Verbraucher.

---

## Quellen

- CAN in Automation (CiA): [History of CAN technology](https://www.can-cia.org/can-knowledge/history-of-can-technology)
- Wikipedia: [CAN bus](https://en.wikipedia.org/wiki/CAN_bus), [Local Interconnect Network](https://en.wikipedia.org/wiki/Local_Interconnect_Network)
- CSS Electronics: [LIN Bus Explained – A Simple Intro](https://www.csselectronics.com/pages/lin-bus-protocol-intro-basics)

*Hinweis: FlexRay und Automotive Ethernet werden hier nur als Ausblick
erwähnt, nicht vertiefend behandelt – das würde den Rahmen dieser
Hobbyisten-orientierten Kategorie sprengen.*
