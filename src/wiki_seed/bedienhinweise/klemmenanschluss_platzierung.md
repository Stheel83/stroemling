# Klemmenanschlüsse – warum getrennt platziert?

Jeder Anschlusspunkt einer Klemme ist ein **eigenständiges Symbol** auf dem
Canvas – anders als bei den meisten anderen Bauteilen gibt es zwischen den
beiden Seiten einer Klemme keine automatisch gezeichnete Verbindungslinie.
Das wirkt beim ersten Mal ungewohnt: man platziert zwei kleine Kreise, aber
"dazwischen" passiert scheinbar nichts.

## Warum keine sichtbare Linie zwischen den Anschlüssen?

Eine reale Klemme verbindet zwei physisch getrennte Verdrahtungsseiten –
zum Beispiel die feste Werksverdrahtung auf der einen und die
Feldverdrahtung zu einem externen Gerät auf der anderen Seite. Diese beiden
Seiten werden im Schaltplan oft an ganz unterschiedlichen Stellen
gebraucht: manchmal direkt nebeneinander, häufig aber auf **unterschiedlichen
Blättern**, weil die eine Seite zur Stromversorgung gehört und die andere zu
einem Verbraucher in einem völlig anderen Teil der Anlage.

Würde Strömling Design beide Seiten zwingend über eine gezeichnete Linie
verbinden, müsste diese Linie entweder über das ganze Blatt oder sogar
blattübergreifend gezogen werden – das würde den Plan schnell unübersichtlich
machen. Stattdessen bleibt jeder Anschluss ein unabhängig platzierbares
Symbol mit eigener Position, Ausrichtung und Beschriftung. Die elektrische
Verbindung besteht trotzdem: beide Anschlüsse referenzieren intern denselben
Klemmen-Datensatz, unabhängig davon, wo sie gezeichnet sind.

## Wie finde ich die Gegenstelle?

Drei Hilfsmittel machen die sonst unsichtbare Verbindung im Programm
greifbar:

- **Hover-Tooltip:** Die Maus kurz über einen Klemmenanschluss halten zeigt
  Leiste, Klemmen-Nr., Anschlussbezeichnung – und, falls vorhanden, die
  Gegenstelle mit Seitenangabe ("↔ ...").
- **Klick auf den Anschluss:** Hebt alle Anschlüsse derselben Klemme auf der
  aktuellen Seite gestrichelt hervor (lässt sich in den Einstellungen
  abschalten, falls nicht gewünscht).
- **Klick auf die Verbindung:** Liegen beide Anschlüsse auf derselben Seite,
  zeigt die Auswahl der Verbindung eine kurze Hilfslinie zwischen ihnen –
  genau wie bei jeder anderen Leitung im Plan.

## Im PDF-Export

Die Hilfsmittel oben sind interaktiv und daher im gedruckten/exportierten
PDF nicht verfügbar. Damit die Information trotzdem nicht verloren geht,
zeigt der PDF-Export direkt am Anschluss eine kleine zusätzliche Zeile mit
der Gegenstelle an ("↔ Leiste:Nr. auf Seite …"), sofern eine existiert.
