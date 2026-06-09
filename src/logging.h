#pragma once
#include <QLoggingCategory>

// stroemling.db   – Datenbankschicht (Database_*.cpp, Database.cpp)
// stroemling.model – C++-Modelle (SeitenModel, KabelModel, …)
// stroemling.app  – App-Start, Canvas-Modell, Achievements

Q_DECLARE_LOGGING_CATEGORY(lcDb)
Q_DECLARE_LOGGING_CATEGORY(lcModel)
Q_DECLARE_LOGGING_CATEGORY(lcApp)
