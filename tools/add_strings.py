#!/usr/bin/env python3
"""Merge new localized keys into Jarz/Localizable.xcstrings.

Edit NEW below and run. Existing keys are left untouched unless
overwrite=True. Languages: ru, sr-Latn, es, it, fr, de (en = key itself).
"""
import json
import os

CATALOG = os.path.join(os.path.dirname(__file__), "..", "Jarz", "Localizable.xcstrings")
LANGS = ["ru", "sr-Latn", "es", "it", "fr", "de"]

# key: [ru, sr-Latn, es, it, fr, de]
NEW = {
    "Choose format": ["Выбери формат", "Izaberi format", "Elige formato", "Scegli il formato",
                      "Choisissez le format", "Format wählen"],
    "JSON (full backup)": ["JSON (полный бэкап)", "JSON (puna kopija)", "JSON (copia completa)",
                           "JSON (backup completo)", "JSON (sauvegarde complète)", "JSON (vollständiges Backup)"],
    "CSV (spreadsheet)": ["CSV (таблица)", "CSV (tabela)", "CSV (hoja de cálculo)",
                          "CSV (foglio di calcolo)", "CSV (tableur)", "CSV (Tabelle)"],
    "Search notes": ["Поиск по заметкам", "Pretraga beležaka", "Buscar notas", "Cerca nelle note",
                     "Rechercher dans les notes", "Notizen durchsuchen"],
    "Recurring payments": ["Регулярные платежи", "Redovna plaćanja", "Pagos recurrentes",
                           "Pagamenti ricorrenti", "Paiements récurrents", "Wiederkehrende Zahlungen"],
    "New recurring payment": ["Новый регулярный платёж", "Novo redovno plaćanje", "Nuevo pago recurrente",
                              "Nuovo pagamento ricorrente", "Nouveau paiement récurrent",
                              "Neue wiederkehrende Zahlung"],
    "Nothing yet — add your first monthly bill below.": [
        "Пока пусто — добавь первый ежемесячный платёж ниже.",
        "Još je prazno — dodaj prvi mesečni račun ispod.",
        "Aún no hay nada: añade tu primera factura mensual abajo.",
        "Ancora niente: aggiungi la tua prima bolletta mensile qui sotto.",
        "Rien pour l’instant — ajoutez votre première facture mensuelle ci-dessous.",
        "Noch nichts — füge unten deine erste Monatsrechnung hinzu."],
    "Name (e.g. Spotify)": ["Название (напр. Spotify)", "Naziv (npr. Spotify)", "Nombre (p. ej. Spotify)",
                            "Nome (es. Spotify)", "Nom (ex. Spotify)", "Name (z. B. Spotify)"],
    "Amount": ["Сумма", "Iznos", "Cantidad", "Importo", "Montant", "Betrag"],
    "Jar": ["Копилка", "Tegla", "Tarro", "Barattolo", "Bocal", "Topf"],
    "Day of month": ["День месяца", "Dan u mesecu", "Día del mes", "Giorno del mese",
                     "Jour du mois", "Tag des Monats"],
    "Every month on day %lld · %@": ["Каждый месяц %lld числа · %@", "Svakog meseca %lld. · %@",
                                     "Cada mes el día %lld · %@", "Ogni mese il giorno %lld · %@",
                                     "Chaque mois le %lld · %@", "Jeden Monat am %lld. · %@"],
    "Add": ["Добавить", "Dodaj", "Añadir", "Aggiungi", "Ajouter", "Hinzufügen"],
    "%@ — %@ from %@": ["%@ — %@ из «%@»", "%@ — %@ iz „%@“", "%@ — %@ de %@",
                        "%@ — %@ da %@", "%@ — %@ depuis %@", "%@ — %@ aus %@"],
    "Past periods": ["Прошлые периоды", "Prethodni periodi", "Períodos anteriores",
                     "Periodi passati", "Périodes précédentes", "Vergangene Perioden"],
    "Logged %@ on food.": ["Записано %@ на еду.", "Zabeleženo %@ za hranu.", "Registrado %@ en comida.",
                           "Registrato %@ per il cibo.", "%@ enregistrés en nourriture.",
                           "%@ für Essen erfasst."],
    "Left for today: %@": ["Осталось на сегодня: %@", "Preostalo za danas: %@", "Queda para hoy: %@",
                           "Rimasto per oggi: %@", "Reste pour aujourd’hui : %@", "Heute übrig: %@"],
}


def main(overwrite: bool = False):
    with open(CATALOG, encoding="utf-8") as f:
        catalog = json.load(f)
    strings = catalog["strings"]
    added = skipped = 0
    for key, values in NEW.items():
        if key in strings and not overwrite:
            skipped += 1
            continue
        strings[key] = {
            "extractionState": "manual",
            "localizations": {
                lang: {"stringUnit": {"state": "translated", "value": value}}
                for lang, value in zip(LANGS, values)
            },
        }
        added += 1
    with open(CATALOG, "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2, sort_keys=True)
    print(f"added {added}, skipped {skipped}, total {len(strings)}")


if __name__ == "__main__":
    main()
