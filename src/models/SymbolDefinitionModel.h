#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QString>
#include <QStringList>
#include <QHash>

// Bietet QML-Zugriff auf das Primitiv-Symbolsystem (Lesen + Schreiben).
// Lesen:  primitiveFuerSymbol, hatPrimitive, pinsForSymbol, rolleForSymbol, symbolInfo, alleSymbole
// Schreiben: symbolAnlegen, symbolAktualisieren, symbolLoeschen,
//            primitivHinzufuegen, primitivAlleLoeschen,
//            pinHinzufuegen, pinAlleLoeschen

class SymbolDefinitionModel : public QObject
{
    Q_OBJECT

public:
    explicit SymbolDefinitionModel(QObject *parent = nullptr);

    // ── Lesemethoden ────────────────────────────────────────────────

    // Gibt alle Primitive eines Symbols geordnet zurück.
    // Jeder Eintrag ist eine QVariantMap mit id + allen Feldern aus symbol_primitiv.
    Q_INVOKABLE QVariantList primitiveFuerSymbol(const QString &symbolId) const;

    // True wenn das Symbol als Primitiv-Definition in der DB vorliegt.
    Q_INVOKABLE bool hatPrimitive(const QString &symbolId) const;

    // Gibt alle Pins eines Symbols zurück.
    // Jeder Eintrag: {id, name, x, y, offen:{x,y}, signaltyp, kontext}
    Q_INVOKABLE QVariantList pinsForSymbol(const QString &symbolId) const;

    // Gibt die Rolle des Symbols zurück (z.B. "durchleiter", "verbraucher").
    Q_INVOKABLE QString rolleForSymbol(const QString &symbolId) const;

    // Berechnet Auto-Verbindungen zwischen Symbol-Pins auf gleicher H-/V-Lane.
    // snapshot   : elementeModel.snapshot()
    // gridPx     : root.gridPx  (canvas-Einheiten pro Rasterfeld)
    // normblatt  : root.normblattDaten || {}  (für anlageKuerzel/ortKuerzel)
    // Gibt [{x1,y1,x2,y2, elIdxA/B, rolleA/B, quellSigA/B, signaltyp, logisch?}] zurück.
    Q_INVOKABLE QVariantList autoVerbindungenBerechnen(const QVariantList &snapshot,
                                                       double gridPx,
                                                       const QVariantMap &normblatt) const;

    // Gibt Basisdaten eines Symbols zurück: {name, kategorie, breiteMm, hoeheMm, rolle, ist_builtin}
    Q_INVOKABLE QVariantMap symbolInfo(const QString &symbolId) const;

    // Schriftgröße (mm) für Pin-Beschriftungen dieses Symbols
    // (PIN-LABEL-SCHRIFTGROESSE-01). Eigener leichtgewichtiger Lookup statt
    // vollem symbolInfo(), da im Canvas-Renderer pro platziertem Symbol und
    // Redraw aufgerufen. Default 2.0 wenn Symbol nicht gefunden.
    Q_INVOKABLE double pinSchriftMm(const QString &symbolId) const;

    // Gibt alle Symbole zurück: [{id, name, kategorie, breiteMm, hoeheMm, rolle, ist_builtin}, …]
    Q_INVOKABLE QVariantList alleSymbole() const;

    // True wenn das Symbol zum Löschen markiert ist (SYM-LOESCH-MARKIERUNG-01,
    // Entwicklungsphase-Werkzeug — reine Merker-Spalte, löscht nichts selbst).
    Q_INVOKABLE bool istMarkiertLoeschen(const QString &symbolId) const;

    // IDs aller aktuell zum Löschen markierten Symbole (built-in + eigene).
    Q_INVOKABLE QStringList symboleMarkiertLoeschen() const;

    // Alle Symbole mit gesetztem kopie_von_id (SYM-KOPIE-VON-01, Entwicklungsphase-
    // Werkzeug): offene Nutzer-Kopien, die noch auf Seed-Sync warten.
    // Jeder Eintrag: {id, name, kategorie, kopieVonId, kopieVonName,
    // nameAbweichend, alternativZielId}. nameAbweichend=true (KOPIE-KETTE-01):
    // der Name "Kopie von <X>" passt zu einem ANDEREN existierenden Symbol als
    // kopie_von_id anzeigt (z.B. Kopie wurde als Zeichenvorlage für ein
    // anderes Familienmitglied umgewidmet) - alternativZielId nennt das
    // wahrscheinlichere Sync-Ziel, kopie_von_id bleibt trotzdem gesetzt.
    Q_INVOKABLE QVariantList symboleMitKopieVon() const;

    // ── Schreibmethoden ─────────────────────────────────────────────

    // Neues Symbol anlegen (ist_builtin = 0). Gibt false zurück wenn id schon belegt.
    // bmkSeite ("auto"|"vertikal", SYMBOL-BMKSEITE-EDITOR-01): steuert wie in
    // symbol_definition, Default "auto" für Aufrufer die (noch) keinen Wert mitgeben.
    // kopieVonId (SYM-KOPIE-VON-01): Quell-Symbol-ID wenn dieses Symbol per
    // "Als Vorlage kopieren" entstanden ist, sonst leer. Wird nur beim
    // allerersten Anlegen gesetzt (nicht bei symbolAktualisieren), da die
    // Vorlagen-Beziehung nur zum Erstellungszeitpunkt bekannt ist.
    // pinSchriftMm (PIN-LABEL-SCHRIFTGROESSE-01): symbolweite Schriftgröße
    // für Pin-Beschriftungen in mm, Default 2.0 (bisherige feste Konstante).
    Q_INVOKABLE bool symbolAnlegen(const QString &id, const QString &name,
                                    const QString &kategorie, int breiteMm, int hoeheMm,
                                    const QString &rolle, const QString &bmkSeite = QStringLiteral("auto"),
                                    double pinSchriftMm = 2.0,
                                    const QString &kopieVonId = QString());

    // Metadaten eines nicht-eingebauten Symbols aktualisieren.
    Q_INVOKABLE bool symbolAktualisieren(const QString &id, const QString &name,
                                          const QString &kategorie, int breiteMm, int hoeheMm,
                                          const QString &rolle, const QString &bmkSeite = QStringLiteral("auto"),
                                          double pinSchriftMm = 2.0);

    // Symbol löschen (nur ist_builtin = 0). Primitive und Pins werden per FK gelöscht.
    Q_INVOKABLE bool symbolLoeschen(const QString &symbolId);

    // Löschmarkierung setzen/aufheben (auch für ist_builtin=1 — Entfernen aus
    // dem Seed macht Claude auf Zuruf anhand dieser Markierung, nicht die App
    // selbst). SYM-LOESCH-MARKIERUNG-01.
    Q_INVOKABLE bool markierungLoeschenSetzen(const QString &symbolId, bool markiert);

    // Einzelnes Primitiv hinzufügen; gibt neue Zeilen-ID zurück (-1 bei Fehler).
    // daten: {typ, reihenfolge, x1, y1, x2, y2, x3, y3, radius,
    //         winkel_von, winkel_bis, bogen_gegen_uhrzeiger,
    //         text_inhalt, schrift_relativ, schrift_fett,
    //         text_align, text_baseline, linienart}
    Q_INVOKABLE int primitivHinzufuegen(const QString &symbolId, const QVariantMap &daten);

    // Alle Primitive eines Symbols löschen (z.B. vor Neu-Speichern).
    Q_INVOKABLE bool primitivAlleLoeschen(const QString &symbolId);

    // Einzelnen Pin hinzufügen; gibt neue Zeilen-ID zurück (-1 bei Fehler).
    // daten: {name, x, y, offenX, offenY, signaltyp, kontext}
    Q_INVOKABLE int pinHinzufuegen(const QString &symbolId, const QVariantMap &daten);

    // Alle Pins eines Symbols löschen.
    Q_INVOKABLE bool pinAlleLoeschen(const QString &symbolId);

    // Cache-Invalidierung nach Bearbeitung im Symboleditor.
    Q_INVOKABLE void cacheLeeren();

private:
    // In-Memory-Cache: symbolId → Primitive-Liste (gültig solange keine Schreiboperation stattfindet)
    mutable QHash<QString, QVariantList> m_primitivCache;
    mutable QHash<QString, QVariantList> m_pinCache;
};
