# Sprungfunktion – von der Liste zum Canvas

An vielen Stellen in Strömling Design – Seitenbaum, Bauteil-Ansicht,
Eigenschaften-Panel, Listen-Ansicht – taucht ein kleiner **→**-Button auf.
Er springt direkt zu der Seite und Position im Canvas, an der das
zugehörige Element platziert ist.

---

## Wo der →-Button erscheint

| Ort | Springt zu |
|---|---|
| Seitenbaum – Klemme im BAUTEILE-Bereich | Position des `klemme_anschluss`-Symbols |
| BAUTEILE-Panel – Gerätekästen | Gerätekasten auf seiner Seite |
| BAUTEILE-Panel – Geräte (Schütz/Relais) | Spule bzw. Kontakt-Symbol |
| EP – Kontaktspiegel (Hauptfunktion ausgewählt) | Position des jeweiligen Kontakts |
| EP – Gerätekasten „Weitere Kästen mit diesem BMK" | Andere Seite desselben Geräts |
| Listen-Ansicht – Stückliste, Querverweise, Aderliste, Klemmenplan, Klemmlistenauszug, Steckverbinder, Belegungsplan | Jeweiliges Element auf seiner Seite |
| Fehlersuchmodus – Querverweis im Info-Panel | Korrespondierender Querverweis auf der Zielseite |

---

## Verhalten

1. Klick auf **→**.
2. Falls das Element auf einer anderen Seite liegt, wechselt die App
   automatisch dorthin.
3. Der Canvas zentriert sich auf die Position des Elements.

Der Button ist **ausgegraut**, wenn das referenzierte Element noch nicht
auf dem Canvas platziert ist (z. B. eine Klemme, die im Klemmeneditor
angelegt, aber noch nicht als Anschluss gezeichnet wurde) – ein Sprung ist
dann nicht möglich.

---

## Ausnahme: Kabelliste

In der Listen-Ansicht hat die **Kabelliste** bewusst keinen Sprung-Button.
Ein Kabel kann mehrere Kabellinien auf mehreren Seiten haben (1:n-Beziehung)
– welche davon gemeint ist, lässt sich nicht eindeutig aus einer Zeile
ableiten. Für alle anderen Listen-Tabs ist die Beziehung eindeutig (1:1),
dort funktioniert der Sprung normal.

> **Tipp:** Um ein bestimmtes Kabelende zu finden, über die Klemmenliste
> oder den Seitenbaum navigieren – dort sind einzelne Kabellinien direkt
> anspringbar.
