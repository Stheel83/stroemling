# Strukturkennzeichen: Anlage, Ort und die Hierarchie ==/=/++/+

Strömling Design kennzeichnet Betriebsmittel nach **DIN EN 81346** über bis
zu vier Struktur-Ebenen. Alle vier werden zentral im Seitenbaum gepflegt –
in Elementen selbst gibt es dafür nur noch Dropdowns, keine Freitextfelder.

---

## Die vier Ebenen

```
==  Übergeordnete Anlage   (optional – nur bei Projekten, die Teil einer größeren Anlage sind)
 =  Anlage                 (Pflicht – mindestens eine pro Projekt)
    ++ Übergeordneter Standort  (optional – nur bei Orten, die Teil eines größeren Standorts sind)
     +  Ort                (Pflicht – mindestens einer pro Anlage)
          Seite            (eine oder mehr pro Ort)
```

`==` gehört zur **Anlage**, `++` gehört zum **Ort**. Beide sind optional –
leer bedeutet „nicht vorhanden", nicht „nicht ausgefüllt".

### Beispiele

| Belegte Ebenen | Ergebnis-BMK |
|---|---|
| nur `=` und `+` | `=AQ+TR-M1` |
| mit `++` | `=AQ++WERK+TR-M1` |
| mit `==` und `++` | `==EXT=AQ++WERK+TR-M1` |

`==` und `++` erscheinen im BMK **nur wenn belegt** – sowohl im Canvas als
auch in allen Listen und Ausgabedokumenten.

---

## Der Seitenbaum als Struktureditor

Anlagen und Orte werden **ausschließlich im Seitenbaum** angelegt und
bearbeitet – nicht in einzelnen Elementen.

- **Neue Anlage/neuer Ort:** „+ Anlage" bzw. „+ Ort" im Seitenbaum, auch
  ohne dass dafür sofort eine Seite angelegt werden muss.
- **`==`/`++` bearbeiten:** Rechtsklick auf eine Anlage → Bearbeiten →
  Feld „Übergeordnete Anlage (==)" aufklappen (standardmäßig eingeklappt,
  da meist nicht gebraucht). Analog bei einem Ort das Feld
  „Übergeordneter Standort (++)".
- **STRUKTUR-Panel:** Am unteren Rand des Seitenbaums zeigt ein eigener
  Bereich alle Anlagen und Orte mit Seitenanzahl – auch solche, die noch
  keine Seite haben.

---

## Verwendung in Elementen: nur Dropdowns

Jedes Element, das einem Ort zugeordnet werden kann, bekommt zwei
ComboBoxen:

```
Anlage:  [ = AQ  Aquarium    ▾ ]
Ort:     [ + TR  Technikraum ▾ ]
```

Die `==`/`++`-Anteile werden **automatisch** aus der gewählten
Anlage/Ort übernommen – dafür gibt es kein eigenes Eingabefeld mehr.

Betroffen sind: Klemmenleiste (KR-Editor), Gerätekasten, Betriebsmittel,
Strukturkasten und Normblatt-Felder.

> **Neue Anlagen und Orte werden im Seitenbaum angelegt** (`+ Anlage` /
> `+ Ort`) – taucht in einem Element-Dropdown die gewünschte Anlage oder
> der gewünschte Ort noch nicht auf, zuerst im Seitenbaum ergänzen.
