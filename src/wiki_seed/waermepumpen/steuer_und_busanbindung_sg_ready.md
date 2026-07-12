# Steuer- und Busanbindung – EVU-Sperrkontakt, SG-Ready, Modbus/eBus

Neben der reinen Leistungsversorgung besitzen praktisch alle modernen
Wärmepumpen zusätzliche Steuer-/Kommunikationsanschlüsse – für die
Elektroplanung relevant, weil dafür eigene (Klein-)Signalleitungen
vorzusehen sind.

---

## 1. EVU-Sperrkontakt (historisch)

Ältere Anlagen und das klassische Modell fester Sperrzeiten
(→ Artikel „§14a EnWG") nutzten einen einfachen potentialfreien Kontakt
vom Netzbetreiber-Rundsteuerempfänger zur Wärmepumpensteuerung: Kontakt
offen/geschlossen = Wärmepumpe darf laufen/muss pausieren. Diese einfache
Zweipunkt-Logik ist Vorläufer der heutigen SG-Ready-Schnittstelle.

## 2. SG-Ready – die etablierte Standardschnittstelle

**SG-Ready (Smart-Grid-Ready)** ist keine Bus-Protokoll-Norm, sondern
basiert auf zwei einfachen, potentialfreien **Ein/Aus-Relaiskontakten**
(2-Bit-Codierung), die vier Betriebszustände signalisieren:

| Zustand | Bedeutung |
|:---:|---|
| 1 | EVU-/Netzbetreiber-Sperre (Betrieb pausiert, Mindestversorgung bleibt) |
| 2 | Normalbetrieb (Standard-Reglerlogik) |
| 3 | Verstärkter Betrieb empfohlen (z. B. PV-Überschuss vorhanden) |
| 4 | Einschaltbefehl garantiert (Wärmepumpe muss laufen) |

Zustand 3/4 wird typischerweise von einer Energiemanagement-Steuerung
(Wechselrichter, Smart-Home-Zentrale) angesteuert, um PV-Überschussstrom
statt Netzstrom in Wärme umzuwandeln – wirtschaftlicher als Einspeisung zu
geringer Vergütung.

## 3. Digitale Schnittstellen: Modbus, eBus, EEBus

Der Trend geht über die einfache SG-Ready-Relaislogik hinaus zu
digitalen Feldbus-/IP-Schnittstellen, die deutlich feinere Steuerung
erlauben (stufenlose Leistungsvorgabe statt vier diskreter Zustände):

- **Modbus TCP/RTU** – herstellerübergreifend verbreiteter
  Industriestandard, von vielen Wärmepumpen-Herstellern zusätzlich
  angeboten
- **eBus** – firmenübergreifend genutzter Heizungs-Feldbus (u. a. bei
  Vaillant), auch für Kaskaden-/Mehrkesselanlagen
- **EEBus** – herstellerneutrale IP-basierte Norm, zunehmend auch für
  die Anbindung ans Smart-Meter-Gateway relevant

## 4. Relevanz für die Elektroplanung

- SG-Ready-Kontakte sind **Kleinspannungs-Steuerleitungen**, keine
  Leistungsleitungen – getrennte Verlegung von den Leistungsadern
  einplanen (EMV, keine gemeinsame Bündelung mit 400-V-Zuleitung)
- Bei digitaler Busanbindung (Modbus/eBus/EEBus) ist ggf. eine
  zusätzliche Datenleitung (z. B. Twisted-Pair) zwischen Wärmepumpe und
  Energiemanager/Wechselrichter vorzusehen
- Für BAFA-geförderte Anlagen gilt seit 1. Januar 2025 die Pflicht zur
  Anschlussfähigkeit an ein zertifiziertes Smart-Meter-Gateway
  (→ Artikel „§14a EnWG")

---

## Quellen

- energie-experten.org: [Der beste Energiemanager für PV + Wärmepumpe: SG-Ready oder Modbus, EEBus & Co.?](https://www.energie-experten.org/news/der-beste-energiemanager-fuer-pv-waermepumpe-sg-ready-oder-modbus-eebus-co)
- energie-experten.org: [SG Ready Wärmepumpe: Label, Schnittstelle & Steuerung](https://www.energie-experten.org/heizung/waermepumpe/betrieb/smart-grid-ready)
- priwatt: [SG-Ready-Schnittstelle: smarter Strom für die Wärmepumpe](https://priwatt.de/blog/sg-ready-schnittstelle/)
- SMA: [Wärmepumpen mit SG Ready-Schnittstelle](https://manuals.sma.de/HM-20/de-DE/10402408587.html)

*Hinweis: Die genaue Klemmenbelegung und unterstützten Protokolle sind
gerätespezifisch – verbindlich ist stets das Elektro-Anschlussschema des
Herstellers.*
