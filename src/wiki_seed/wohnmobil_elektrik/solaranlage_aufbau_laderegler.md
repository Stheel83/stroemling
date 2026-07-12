# Solaranlage: Aufbau, PWM- vs. MPPT-Laderegler, Dimensionierung

Eine Solaranlage ist für autarkes Reisen ohne regelmäßigen Landstrom-
Anschluss praktisch unverzichtbar – sie lädt die Aufbaubatterie, während
das Fahrzeug steht, also gerade dann, wenn Trennrelais/Ladebooster nichts
tun können (→ Artikel „Trennrelais und Ladebooster").

---

## 1. Grundaufbau

Drei Kernkomponenten:

- **Solarmodul(e)** auf dem Dach – wandeln Sonnenlicht direkt in
  Gleichstrom um
- **Laderegler** – zwischen Solarmodul und Batterie geschaltet, verhindert
  Überladung und passt die Ladespannung an den Batteriezustand an
- **Aufbaubatterie** als Speicher (→ Artikel „Batterietechnik für Camper")

## 2. PWM-Laderegler

Der einfachere, günstigere Reglertyp: **PWM (Pulsweitenmodulation)**
schaltet die Verbindung zwischen Solarmodul und Batterie getaktet ein und
aus, um die Ladespannung zu begrenzen. Nachteil: Die Solarmodulspannung
wird dabei praktisch direkt auf Batteriespannungsniveau „heruntergezogen"
– ein Modul, das für eine höhere Spannung ausgelegt ist als die Batterie,
verschenkt an einem PWM-Regler erhebliches Leistungspotenzial.

## 3. MPPT-Laderegler

**MPPT (Maximum Power Point Tracking)** ist die heute übliche, effizientere
Technik: Der Regler sucht aktiv den Punkt auf der Solarmodul-
Kennlinie, an dem die maximale Leistung anliegt, und wandelt Spannung/
Strom elektronisch so um, dass die Batterie optimal geladen wird –
unabhängig davon, ob die Modulspannung deutlich über der
Batteriespannung liegt. Ergebnis: spürbar höherer Ladeertrag,
insbesondere bei bewölktem Himmel, schräg einfallendem Licht oder
teilverschatteten Modulen – Situationen, in denen ein PWM-Regler deutlich
mehr Ertrag verschenkt.

| Merkmal | PWM | MPPT |
|---|---|---|
| Wirkungsgrad | niedriger, besonders bei ungünstigem Licht | höher, auch bei Teilverschattung/schwachem Licht |
| Kosten | günstig | teurer |
| Modulspannung | sollte nah an Batteriespannung liegen | flexibel, auch deutlich höhere Modulspannung sinnvoll nutzbar |
| Typischer Einsatz heute | sehr kleine Anlagen, Budget-Lösungen | Standard bei modernen Camper-Solaranlagen |

## 4. Dimensionierung

Die passende Modulleistung hängt vom Verbrauchsprofil ab – grober
Anhaltspunkt: Ein 100-Wp-Modul liefert unter guten Bedingungen
(Sommer, wenig Verschattung) über den Tag verteilt realistisch eher
30–50 Wh nutzbare Energie als die theoretisch mögliche Spitzenleistung,
da Sonnenstand, Wetter und Modulausrichtung stark schwanken. Für
zuverlässige autarke Nutzung wird meist eine deutliche Überdimensionierung
gegenüber dem reinen „Rechenwert" empfohlen, insbesondere bei Nutzung
außerhalb der Sommermonate.

## 5. Praxishinweis: Absicherung nicht vergessen

Auch die Solarleitung zwischen Modul und Laderegler sowie zwischen
Laderegler und Batterie braucht eine **eigene, passend dimensionierte
Sicherung** – ein häufig übersehener Punkt bei Selbstinstallationen, da
die vergleichsweise geringen Solarströme leicht unterschätzt werden.

---

## Quellen

- Allgemeine Fachinformationen zu PWM- und MPPT-Ladereglern
  (Hersteller-Dokumentation Victron Energy, Renogy u.a.)

*Hinweis: Konkrete Ertragswerte hängen stark von Standort, Jahreszeit,
Modulausrichtung und Verschattung ab – die genannten Werte sind grobe
Orientierung, keine belastbare Ertragsberechnung für ein konkretes
Projekt.*
