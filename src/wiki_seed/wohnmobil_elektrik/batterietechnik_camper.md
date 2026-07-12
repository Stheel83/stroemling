# Batterietechnik für Camper: AGM/Gel vs. LiFePO4 + BMS

Die Wahl der Aufbaubatterie ist eine der folgenreichsten Entscheidungen
beim Camper-Ausbau – sie beeinflusst Gewicht, Kosten, nutzbare Kapazität
und die restliche Elektrik-Auslegung (Ladebooster, Solarladeregler)
gleichermaßen.

---

## 1. Blei-Gel-Batterie

Klassische, günstige Lösung: Blei-Säure-Technik mit gelförmig gebundenem
Elektrolyt (vergleichbar dem Grundprinzip der AGM-Technik, → Kategorie
„KFZ-Elektrik im Wandel der Zeit", Artikel „Batterietechnik im Wandel") –
auslaufsicher, robust, aber mit deutlichen Einschränkungen: Nur ein Teil
der Nennkapazität sollte im Alltag genutzt werden (typische Faustregel:
nicht tiefer als 50 % entladen, sonst sinkt die Lebensdauer drastisch),
begrenzte Zyklenfestigkeit, deutlich höheres Gewicht je nutzbarer
Kapazität als Lithium.

## 2. AGM-Batterie

Wie im PKW-Bereich (→ verlinkter Artikel oben) bietet AGM gegenüber
klassischem Gel höhere Vibrationsfestigkeit, bessere Kaltstartleistung
und etwas höhere Zyklenfestigkeit – bleibt aber technisch in derselben
Blei-Säure-Familie mit denselben Grundeinschränkungen bei Entladetiefe
und Gewicht.

## 3. LiFePO4 (Lithium-Eisenphosphat)

Die inzwischen im Camperausbau weit verbreitete Alternative:

- **Deutlich geringeres Gewicht** bei gleicher nutzbarer Kapazität
  (oft weniger als halbes Gewicht gegenüber Blei-Technik)
- **Nahezu vollständige Entladetiefe nutzbar** (oft 80–100 % der
  Nennkapazität ohne relevanten Lebensdauerverlust, im Gegensatz zur
  50-%-Faustregel bei Blei)
- **Sehr hohe Zyklenfestigkeit** (mehrere tausend Vollzyklen möglich)
- **Kälteempfindlichkeit beim Laden:** Unter 0 °C darf eine LiFePO4-Zelle
  ohne Schutzmaßnahme **nicht geladen werden** (irreversible Schädigung
  durch Lithium-Plating) – hochwertige Camper-LiFePO4-Batterien haben
  dafür eine interne Heizung oder das BMS unterbindet die Ladung bei
  Kälte automatisch

## 4. Das BMS (Batteriemanagementsystem)

Jede LiFePO4-Batterie braucht zwingend ein **BMS**, das:

- die einzelnen Zellen innerhalb der Batterie **balanciert** (gleichmäßige
  Ladung/Entladung aller Zellen, verhindert vorzeitigen Ausfall einzelner
  Zellen)
- vor **Tiefentladung, Überladung, Überstrom und Übertemperatur** schützt
  und den Stromkreis im Fehlerfall automatisch trennt
- bei Kälte die Ladefreigabe blockiert (siehe oben)

Ohne funktionierendes BMS ist der Betrieb einer LiFePO4-Zelle nicht
sicher – anders als bei klassischer Blei-Technik, wo ein einfacher
Laderegler ausreicht.

## 5. Kompatibilität mit bestehender Elektrik

Beim Umstieg von Blei- auf LiFePO4-Technik in einem bestehenden Ausbau
unbedingt prüfen:

- Ist der vorhandene **Ladebooster/Solarladeregler** für LiFePO4-Ladekurven
  geeignet oder umschaltbar? (Lithium braucht eine andere Ladekennlinie
  als Blei)
- Verträgt der vorhandene **Wechselrichter** die LiFePO4-typische, flachere
  Entladekurve (Spannung bleibt bis kurz vor komplett leer relativ
  konstant, anders als bei Blei mit allmählichem Spannungsabfall)?
- Ist eine **Kälteabsicherung** vorhanden, falls die Batterie im Winter im
  unbeheizten Bereich verbaut ist?

---

## Quellen

- Allgemeine Fachinformationen zu LiFePO4-Batterietechnik im
  Camping-/Marine-Bereich (Hersteller-Datenblätter Victron Energy,
  BSL Batterien u.a.)

*Hinweis: Konkrete Lade-/Entladeparameter (z.B. exakte Temperaturgrenzen,
zulässige Entladetiefe) unterscheiden sich zwischen Herstellern und
Modellen – im Zweifel gilt das jeweilige Batterie-Datenblatt.*
