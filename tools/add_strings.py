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
    "Restore previous state": ["Вернуть прежнее состояние", "Vrati prethodno stanje", "Restaurar estado anterior",
                               "Ripristina stato precedente", "Restaurer l’état précédent", "Früheren Stand wiederherstellen"],
    "Snapshots": ["Снимки", "Snimci", "Instantáneas", "Istantanee", "Instantanés", "Schnappschüsse"],
    "No snapshots yet.": ["Снимков пока нет.", "Još nema snimaka.", "Aún no hay instantáneas.",
                          "Nessuna istantanea per ora.", "Aucun instantané pour l’instant.", "Noch keine Schnappschüsse."],
    "Saved automatically before deleting a jar, importing data, recalculating food or restoring. The last 5 are kept.": [
        "Сохраняются автоматически перед удалением копилки, импортом, пересчётом еды или восстановлением. Хранятся последние 5.",
        "Čuvaju se automatski pre brisanja tegle, uvoza, preračuna hrane ili vraćanja. Čuva se poslednjih 5.",
        "Se guardan automáticamente antes de eliminar un tarro, importar datos, recalcular la comida o restaurar. Se conservan las últimas 5.",
        "Salvate automaticamente prima di eliminare un barattolo, importare dati, ricalcolare il cibo o ripristinare. Vengono conservate le ultime 5.",
        "Enregistrés automatiquement avant de supprimer un bocal, d’importer, de recalculer la nourriture ou de restaurer. Les 5 derniers sont conservés.",
        "Werden automatisch vor dem Löschen eines Topfs, einem Import, der Neuberechnung des Essens oder einer Wiederherstellung gespeichert. Die letzten 5 bleiben erhalten."],
    "Restore this state?": ["Вернуть это состояние?", "Vratiti ovo stanje?", "¿Restaurar este estado?",
                            "Ripristinare questo stato?", "Restaurer cet état ?", "Diesen Stand wiederherstellen?"],
    "Restore": ["Вернуть", "Vrati", "Restaurar", "Ripristina", "Restaurer", "Wiederherstellen"],
    "Everything in Jarz will be replaced with this snapshot. Your current state is saved as a new snapshot first.": [
        "Всё в Jarz будет заменено этим снимком. Текущее состояние сначала сохранится новым снимком.",
        "Sve u Jarz-u biće zamenjeno ovim snimkom. Trenutno stanje se prvo čuva kao novi snimak.",
        "Todo en Jarz se reemplazará con esta instantánea. Tu estado actual se guarda primero como una nueva.",
        "Tutto in Jarz sarà sostituito da questa istantanea. Lo stato attuale viene prima salvato come nuova istantanea.",
        "Tout dans Jarz sera remplacé par cet instantané. Votre état actuel est d’abord enregistré comme nouvel instantané.",
        "Alles in Jarz wird durch diesen Schnappschuss ersetzt. Dein aktueller Stand wird vorher als neuer Schnappschuss gesichert."],
    "Before deleting %@": ["Перед удалением «%@»", "Pre brisanja „%@“", "Antes de eliminar %@",
                           "Prima di eliminare %@", "Avant la suppression de %@", "Vor dem Löschen von %@"],
    "Before import": ["Перед импортом", "Pre uvoza", "Antes de importar", "Prima dell’importazione",
                      "Avant l’importation", "Vor dem Import"],
    "Before food recalculation": ["Перед пересчётом еды", "Pre preračuna hrane", "Antes de recalcular la comida",
                                  "Prima del ricalcolo del cibo", "Avant le recalcul de la nourriture", "Vor der Neuberechnung des Essens"],
    "Before restore": ["Перед восстановлением", "Pre vraćanja", "Antes de restaurar", "Prima del ripristino",
                       "Avant la restauration", "Vor der Wiederherstellung"],
    "Recalculate from today": ["Пересчитать от сегодня", "Preračunaj od danas", "Recalcular desde hoy",
                               "Ricalcola da oggi", "Recalculer à partir d’aujourd’hui", "Ab heute neu berechnen"],
    "Recalculate from today?": ["Пересчитать от сегодня?", "Preračunati od danas?", "¿Recalcular desde hoy?",
                                "Ricalcolare da oggi?", "Recalculer à partir d’aujourd’hui ?", "Ab heute neu berechnen?"],
    "Recalculate": ["Пересчитать", "Preračunaj", "Recalcular", "Ricalcola", "Recalculer", "Neu berechnen"],
    "The plan end date is recalculated from the current balance: today keeps at most one daily budget, the rest is spread over the following days.": [
        "Дата конца плана пересчитается по текущему балансу: на сегодня останется не больше дневной нормы, остальное распределится по следующим дням.",
        "Datum kraja plana se preračunava prema trenutnom stanju: za danas ostaje najviše jedan dnevni budžet, ostatak se raspoređuje na naredne dane.",
        "La fecha de fin del plan se recalcula con el saldo actual: hoy se queda como máximo un presupuesto diario y el resto se reparte en los días siguientes.",
        "La data di fine piano viene ricalcolata dal saldo attuale: oggi resta al massimo un budget giornaliero, il resto si distribuisce sui giorni seguenti.",
        "La date de fin du plan est recalculée à partir du solde actuel : aujourd’hui garde au plus un budget quotidien, le reste est réparti sur les jours suivants.",
        "Das Planende wird aus dem aktuellen Saldo neu berechnet: Heute bleibt höchstens ein Tagesbudget, der Rest verteilt sich auf die folgenden Tage."],
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
