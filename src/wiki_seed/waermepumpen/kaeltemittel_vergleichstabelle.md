# Kältemittel-Vergleichstabelle

Schnellübersicht der gängigsten Kältemittel in Wärmepumpen – GWP,
Sicherheitsgruppe nach ISO 817/ANSI-ASHRAE 34 und typische
Füllmengenordnung. Hintergrund zu Klimawirkung und F-Gase-Verordnung →
Artikel „Kältemittel im Wandel".

---

## 1. Sicherheitsgruppen-Systematik (ISO 817 / ASHRAE 34)

Die Einstufung setzt sich aus **Toxizität** (Buchstabe) und
**Brennbarkeit** (Ziffer/Buchstabe) zusammen:

| Kürzel | Toxizität | Brennbarkeit |
|:---:|---|---|
| A | geringe Toxizität | — |
| B | höhere Toxizität | — |
| 1 | — | nicht brennbar |
| 2L | — | schwer entflammbar (niedrige Verbrennungsgeschwindigkeit, < 10 cm/s) |
| 2 | — | brennbar |
| 3 | — | hochentzündlich |

**A2L** benötigt nach Praxisangaben rund das **Tausendfache** an
Zündenergie im Vergleich zu A3-Kältemitteln (Kohlenwasserstoffe wie
Propan/Isobutan) – eine Entzündung durch eine weggeworfene Zigarette oder
ein Heizgerät gilt als praktisch ausgeschlossen, ändert aber nichts an der
grundsätzlichen Brennbarkeits-Einstufung.

## 2. Vergleichstabelle

| Kältemittel | Typ | GWP (100 J.) | Sicherheitsgruppe | Betriebsdruck | Bemerkung |
|---|---|---:|:---:|---|---|
| R410A | synthetisch (HFKW) | ~2088 | A1 | 25–30 bar | Altbestand, wird verdrängt, ab 2027 faktisch für Neuanlagen ≤12 kW ausgeschlossen |
| R32 | synthetisch (HFKW) | 675 | A2L | 25–45 bar | aktuell verbreitet, ab 1.1.2027 GWP-Grenze 150 für Neuanlagen bis 12 kW relevant |
| R454B | synthetisch (HFKW-Gemisch) | ~466 | A2L | ähnlich R410A-Bereich | Nachfolger von R410A, v. a. gewerblich |
| R290 (Propan) | natürlich (Kohlenwasserstoff) | 3 | A3 | 25–45 bar | Zielkältemittel der Branche, hochentzündlich → Füllmengenbegrenzung je Aufstellort |
| R744 (CO₂) | natürlich | 1 | A1 | bis 140 bar (transkritisch) | nicht brennbar, sehr hohe Drücke → robuste/teurere Komponenten, hohe Vorlauftemperaturen möglich |

## 3. Einordnung für die Praxis

- **A1-Kältemittel** (R410A, R744) sind nicht brennbar – keine besonderen
  Zündschutzmaßnahmen erforderlich, dafür bei R410A hoher GWP bzw. bei
  R744 hoher Anlagendruck als jeweiliger Nachteil
- **A2L-Kältemittel** (R32, R454B) gelten als praxistauglicher Kompromiss:
  moderat reduzierter GWP gegenüber R410A, Brennbarkeit nur unter sehr
  spezifischen Bedingungen relevant
- **A3-Kältemittel** (R290) bieten den mit Abstand niedrigsten GWP,
  verlangen aber die konsequenteste sicherheitstechnische Behandlung
  (Füllmengengrenzen, Zündquellenfreiheit, ggf. Belüftungskonzept bei
  Innenaufstellung)

---

## Quellen

- Verordnung (EU) 2024/573 über fluorierte Treibhausgase
- cold.world: [Kältemittel Klassifizierung](https://cold.world/de/know-how/kaeltemittelklassifizierung)
- Landesinnung Kälte-Klima: [Leitfaden „Umgang mit brennbaren Kältemitteln der Sicherheitsklasse A2L"](https://www.landesinnung-kaelte-klima.de/fileadmin/DATEIEN/Download/TIP_19_Leitfaden_A2L_Teil_1.pdf)
- Danfoss: [A2L-Kältemittel in der Gewerbekälte](https://www.danfoss.com/de-de/about-danfoss/our-businesses/cooling/refrigerants-and-energy-efficiency/a2l-refrigerants-in-commercial-refrigeration/)
- Bundesamt für Energie (Schweiz): [Kältemittel-Fibel für Heizungs-, Lüftungs- und Klima-Fachleute](https://pubdb.bfe.admin.ch/de/publication/download/8710)

*Hinweis: GWP-Werte werden je nach IPCC-Bewertungsbericht (AR4/AR5/AR6)
leicht unterschiedlich angegeben – diese Tabelle nutzt die derzeit in der
EU-Regulatorik gebräuchlichen AR5-Werte. Betriebsdrücke sind
Größenordnungen, keine Auslegungswerte für konkrete Anlagen.*
