# Gerätekasten und Geräte mit Kontaktspiegel

Zwei verschiedene, oft verwechselte Werkzeuge für komplexe Bauteile im
Schaltplan: der **Gerätekasten** (ein Rahmen für beliebige Elemente) und
das **Betriebsmittel** mit Kontaktspiegel (Schütz, Relais – Hauptfunktion
+ Nebenfunktionen mit gemeinsamer BMK).

---

## Gerätekasten

Ein Gerätekasten ist ein Rahmen-Element, das ein komplexes Gerät oder
einen Teil davon darstellt (Frequenzumrichter, SPS-Baugruppe,
Steckverbinderblock …). **Alle Elemente, deren Mittelpunkt innerhalb des
Kastens liegt, gehören automatisch dazu** – keine manuelle Verknüpfung
nötig.

### Anlegen

Werkzeug **G** auf dem Canvas aufziehen, dann im EP **BMK** und
**Bezeichnung** vergeben.

### Mehrseitig

Ein Gerät kann auf mehrere Gerätekästen verteilt sein (z. B. Lastkreis auf
Seite 1, Steuerkreis auf Seite 2) – Voraussetzung ist nur **derselbe
BMK-Text**. Im EP erscheint dann automatisch ein Block „Weitere Kästen mit
diesem BMK" mit Sprung-Buttons zu den anderen Seiten.

### Bauteil optional verknüpfen

Im BAUTEILE-Panel unter **PROJEKT → Gerätekästen** lässt sich jeder Kasten
mit einem Bibliothekseintrag (z. B. einem Steckverbinder-Gehäuse)
verknüpfen. Ist ein Bauteil verknüpft, zeigt das EP einen zusätzlichen,
schreibgeschützten Abschnitt **GEHÄUSEDATEN** (Hersteller, Typ, Polzahl,
IP, Kodierung …) mit einem Link „Im Bauteil-Editor öffnen →".

---

## Geräte (Schütz, Relais) und Kontaktspiegel

Ein „Gerät" besteht im Schaltplan aus mehreren Symbolen: einer
**Hauptfunktion** (z. B. Schützspule) und mehreren **Nebenfunktionen**
(Schließer, Öffner, Hilfskontakte). Alle teilen dieselbe BMK und können
auf beliebig vielen Seiten verteilt sein.

### Hauptfunktion platzieren (Bauteil-first)

1. BAUTEILE-Panel → **Bibliothek** → Bauteil mit Symbol auswählen → „+".
2. Auf dem Canvas klicken – das Symbol wird platziert.
3. Der BMK-Eingabe-Dialog öffnet sich automatisch. BMK eingeben →
   Betriebsmittel wird angelegt, das Symbol als Hauptfunktion verknüpft.
   „Überspringen" lässt das Symbol unverknüpft.

### Kontakte platzieren

1. BAUTEILE-Panel → Sektion **GERÄTE** → das Betriebsmittel aufklappen →
   „+".
2. Der Picker zeigt die Kontaktbelegung aus der Bibliothek (falls ein
   Bauteil verknüpft ist) oder eine generische Liste (Schließer, Öffner,
   Wechsler, Taster, Bimetall).
3. Kontakt anklicken → BMK und Kontaktbezeichnung (z. B. „13/14") werden
   vorbelegt, das Platzier-Werkzeug aktiviert sich.
4. Auf dem Canvas platzieren. Für weitere Kontakte wiederholen – auch auf
   anderen Seiten.

### Kontaktspiegel im EP

Bei ausgewählter Hauptfunktion zeigt das EP eine Übersichtstabelle aller
Kontakte des Geräts:

| Spalte | Inhalt |
|---|---|
| Bezeichnung | Kontaktbezeichnung, z. B. „13/14" |
| Typ | Schließer, Öffner, Hilfskontakt … |
| Platziert | Ja/Nein |
| Seite | Seitenbezeichnung, wenn platziert |
| Sprung | → springt zur Position des Kontakts |

Noch nicht platzierte Kontakte erscheinen grau/kursiv – sie existieren nur
als Eintrag in der Bibliothek, noch nicht auf dem Canvas.

### Falsch zugeordneten Kontakt umhängen

Zwei Wege: (1) EP des Kontakts → Dropdown „Gehört zu Betriebsmittel"
wechseln, BMK aktualisiert sich automatisch. (2) Im Kontaktspiegel der
Spule sind fehlzugeordnete Kontakte sichtbar und können dort korrigiert
werden.

---

## Abgrenzung

| | Klemme | Betriebsmittel (Schütz/Relais) | Gerätekasten |
|---|---|---|---|
| BMK-Vererbung | Nein (eigene BMK) | Ja – Kontakte erben von der Spule | Nein – Inhalt geometrisch zugeordnet |
| Mehrseitig | Ja (A-/B-Seite) | Ja (Spule/Kontakte) | Ja (mehrere Kästen, gleicher BMK) |
| Verknüpfungsmechanismus | `klemme`-Tabelle | Betriebsmittel-ID am Symbol | Gleicher BMK-Text |
| BAUTEILE-Panel-Sektion | Klemmenreihen | Geräte | Gerätekästen |

> Ein Gerätekasten kann auch **ohne** verknüpftes Bauteil verwendet
> werden – ebenso ein Betriebsmittel ohne Bibliothekseintrag. Beides ist
> optional und bringt Zusatznutzen (Anschlussbelegung, GEHÄUSEDATEN,
> Stücklisten-Eintrag), ist aber für die Grundfunktion nicht nötig.
