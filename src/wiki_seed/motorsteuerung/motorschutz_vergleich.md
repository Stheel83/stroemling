# Motorschutzschalter vs. Thermorelay – Vergleich

Beide Geräte schützen Motoren vor thermischer Überlastung — aber
sie unterscheiden sich in Aufbau, Einsatzbereich und Kombination
mit anderen Schutzgeräten erheblich.

> **Norm:** DIN EN 60947-4-1 (beide Gerätetypen)

---

## Grundunterschied

| | Motorschutzschalter (MSS) | Thermorelay (Überlastrelais) |
|---|---|---|
| **Kurzschlussschutz** | ja (eigener Magnetauslöser) | nein |
| **Überlastschutz** | ja (Bimetall-Auslöser) | ja (Bimetall-Auslöser) |
| **Schaltorgan** | selbst (unterbricht direkt) | nein (schaltet Schütz ab) |
| **Kombination** | allein einsetzbar | benötigt Schütz |
| **Einstellbereich** | 0,1 A bis ~32 A | 0,1 A bis > 100 A |
| **Typische Anwendung** | kleiner Motor direkt | Schütz-Kombination |

---

## Motorschutzschalter (MSS / PKZ)

Der Motorschutzschalter kombiniert **Kurzschlussschutz** (Magnetauslöser)
und **Überlastschutz** (Thermobimetall) in einem Gerät.

**Vorteile:**
- Kompakt: ein Gerät ersetzt LSS + Thermorelay
- Kein separates Schütz für reinen Tipp-Betrieb nötig
- Direkte manuelle Schaltbarkeit (EIN/AUS-Schalter)

**Nachteile:**
- Eingeschränkter Nennstrombereich (meistens bis 32 A)
- Keine Fernsteuerung ohne zusätzliches Schütz
- Kein Selbsthaltestromkreis ohne Zubehör

**Typischer Einsatz:**
- Kleine Motoren bis ~15 kW
- Pumpen, Lüfter, Förderbänder ohne Fernsteuerung
- Klemmenkasten direkt am Motor
- Maschinen mit Vor-Ort-Bedienung

---

## Thermorelay (Bimetall-Überlastrelais)

Das Thermorelay überwacht den Motorstrom und gibt einen **Schaltbefehl**
an den Steuerstromkreis — es unterbricht den Lastkreis selbst **nicht**.

**Vorteile:**
- Höhere Ströme möglich (bis 300 A und mehr)
- Passt zu jedem Schütz
- Genaue Einstellung auf Motornennstrom
- Meldekontakt (97/98) für Fernmeldung
- Phasenausfallschutz integriert (3-phasige Typen)

**Nachteile:**
- Immer in Kombination mit Schütz erforderlich
- Kein eigener Kurzschlussschutz (LSS oder Q1 im Hauptkreis nötig)
- Baut mehr Platz auf als MSS

**Typischer Einsatz:**
- Motoren ab ~7,5 kW
- Ferngesteuerte Anlagen (Schütz + Taster)
- Stern-Dreieck-Anlasser
- Anlagen mit Meldepflicht (Auslösung wird weitergeleitet)

---

## Phasenausfallschutz

Fällt eine Phase aus, läuft der Motor einphasig — er erwärmt sich
stark, da der Strom in den verbleibenden Wicklungen steigt.

| Gerät | Phasenausfallschutz? |
|-------|:-------------------:|
| Motorschutzschalter (3-polig) | ja (differenziertes Bimetall) |
| Thermorelay (3-polig) | ja (differenziertes Bimetall) |
| LSS (Leitungsschutzschalter) | nein |

> **Wichtig:** Einen 3-Phasen-Motor niemals nur mit einem
> einphasigen LSS schützen — kein Phasenausfallschutz!

---

## Auswahltabelle nach Einsatzszenario

| Szenario | Empfehlung |
|----------|-----------|
| Kleiner Motor (< 4 kW), Vor-Ort-Betrieb | Motorschutzschalter (allein) |
| Motor mit Fernsteuerung, beliebige Leistung | LSS + Schütz + Thermorelay |
| Motor > 15 kW | LSS + Schütz + Thermorelay |
| Stern-Dreieck-Anlasser | LSS + 3 Schütze + Thermorelay |
| Frequenzumrichter | Kein Thermorelay! (UMR schützt selbst) |

---

## Thermorelay bei Frequenzumrichter: Nicht verwenden!

Frequenzumrichter liefern **nichtsinusförmigen Strom** — Thermorelais
mit Bimetall messen diesen ungenau (Oberwellen verfälschen Messung).

Bei Umrichter-Betrieb:
- Den **internen Motorschutz des Umrichters** aktivieren (I²t-Auslöser)
- Oder PTC-Temperaturfühler im Motor + externer Auslöser
- Kein Bimetall-Thermorelay im Umrichterausgang!
