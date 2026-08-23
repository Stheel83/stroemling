// Gemeinsame Hilfsfunktionen für die verschiedenen *CsvSpeichern()-Methoden
// (REFACTOR-CPP-01) — Datei-öffnen/UTF-8-BOM-Boilerplate + Feld-Escaping
// waren zuvor in 10 Funktionen über 4 Database_*.cpp-Dateien dupliziert.
#pragma once

#include "logging.h"
#include <QFile>
#include <QTextStream>
#include <QUrl>
#include <QVariant>

namespace CsvHelfer {

inline QString lokalerPfad(const QString &pfad)
{
    const QString p = QUrl(pfad).toLocalFile();
    return p.isEmpty() ? pfad : p;
}

// Öffnet die Zieldatei zum Schreiben, bindet den übergebenen QTextStream
// daran (UTF-8, mit BOM für Excel) — file und out müssen den Aufrufer
// überleben. funktionsname erscheint in der Warnmeldung bei Fehlschlag.
inline bool dateiOeffnenMitBom(const QString &pfad, QFile &file, QTextStream &out,
                                const char *funktionsname)
{
    file.setFileName(lokalerPfad(pfad));
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qCWarning(lcDb) << funktionsname << ": kann nicht öffnen:" << file.fileName();
        return false;
    }
    out.setDevice(&file);
    out.setEncoding(QStringConverter::Utf8);
    out << "\xEF\xBB\xBF";
    return true;
}

// Feld nur in Anführungszeichen setzen, wenn nötig (Trennzeichen/
// Anführungszeichen/Zeilenumbruch im Wert) — Stil der Listen-/Klemmen-/
// Steckverbinder-Exporte.
inline QString escapeBedarf(const QString &s)
{
    if (s.contains(u';') || s.contains(u'"') || s.contains(u'\n'))
        return u'"' + QString(s).replace(u'"', QLatin1String("\"\"")) + u'"';
    return s;
}

// Feld-Inhalt escapen, Anführungszeichen setzt der Aufrufer selbst manuell
// um jedes Feld — Stil des SPS-IO-Listen-Exports.
inline QString escapeImmer(const QVariant &v)
{
    if (v.isNull()) return QString();
    return v.toString().replace(u'"', QLatin1String("\"\""));
}

} // namespace CsvHelfer
