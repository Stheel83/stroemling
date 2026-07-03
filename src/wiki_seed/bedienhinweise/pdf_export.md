# PDF-Export

Ein Projekt (oder eine einzelne Seite) lässt sich als mehrseitiges,
**echtes Vektor-PDF** exportieren – kein Screenshot, sondern gezeichnete
Linien und Texte, beliebig skalierbar und druckfertig.

---

## Export starten

- Toolbar-Button (neben dem Normblatt-Button), oder
- Tastenkürzel **Strg+Umschalt+P**

Im Dialog wählst du **Alle Seiten** oder **Aktuelle Seite** sowie den
Zielpfad.

Existiert die Zieldatei bereits, fragt ein Bestätigungsdialog vor dem
Überschreiben nach – bewusst ein Dialog statt eines Toasts, da ein
versehentliches Überschreiben Konsequenzen hat.

---

## Was mit exportiert wird

- Alle Symbole, Leitungen, Texte, Bilder und Kästen (Geräte-, Struktur-,
  Makrokasten) der jeweiligen Seite
- Kreuzungslücken bei sich kreuzenden Leitungen aus unterschiedlichen
  Netzen
- Aderbeschriftungen (Bezeichnung, Aderfarbe, Querschnitt, Länge)
- Das Normblatt inkl. Schriftfeld, Logo und Revisionsstand
- Ist ein Revisionsstatus gesetzt (Entwurf/Freigegeben/Veraltet), erscheint
  automatisch ein diagonales Wasserzeichen auf der exportierten Seite

> **Bekannte Einschränkung:** Seiten, die im aktuellen Programmlauf noch
> nie geöffnet wurden, können im PDF ohne Leitungen erscheinen – die
> Verbindungsdaten werden erst beim Öffnen einer Seite synchronisiert.
> Einmal kurz jede Seite öffnen behebt das.
