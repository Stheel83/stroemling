# Seitenbaum – Seiten sortieren und verschieben

## Hierarchie: Anlage → Ort → Seite

Der Seitenbaum ist dreistufig aufgebaut:

- **Anlage** (z. B. `=EG`) – das Gebäude oder die Einheit
- **Ort** (z. B. `+A1`) – ein Bereich innerhalb der Anlage (Schrank, Raum, …)
- **Seite** (z. B. `001 Stromversorgung`) – ein einzelnes Schaltplanblatt

Diese Struktur orientiert sich an **DIN EN 81346**: jede Seite gehört zu genau einem Ort,
jeder Ort zu genau einer Anlage.

## Reihenfolge ändern (innerhalb eines Orts)

Am linken Rand jeder Seite erscheint beim Hovern ein **☰-Griffsymbol**.
Damit lässt sich die Seite per Drag & Drop innerhalb ihres Orts umsortieren.

Das Umsortieren ändert nur die Anzeigereihenfolge im Seitenbaum –
Blattnummern, Querverweise und BMKs bleiben unverändert.

> **Einschränkung:** Drag & Drop funktioniert nur *innerhalb desselben Orts*.
> Das ist so gewollt – siehe unten.

## Seite in einen anderen Ort verschieben

Für einen **Ort-Wechsel** gibt es den **→-Button** (erscheint ebenfalls beim Hovern).
Er öffnet einen Dialog, in dem Anlage und Ziel-Ort gewählt werden.

Dasselbe gilt für Orte: der →-Button an einem Ort verschiebt den gesamten Ort
(inkl. aller Seiten) in eine andere Anlage.

## Warum kein orts-übergreifendes Drag & Drop?

Drag & Drop innerhalb einer Liste ist einfach und eindeutig – die Zielposition
ist durch die Y-Koordinate festgelegt. Ein orts-übergreifendes Drag & Drop
müsste dagegen aus zwei Informationen gleichzeitig bestehen:
*wohin in der Ordnung* und *in welchen Ort*.

Das macht die Geste mehrdeutig und fehleranfällig, besonders bei vielen Orten
mit ähnlicher Tiefe im Baum. Der Dialog macht die Entscheidung explizit:
erst Anlage wählen, dann Ort – ohne versehentliche Fehlplatzierungen.
