import Foundation

enum L10n {

    private static var isRussian: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ru") == true
    }

    private static func s(_ ru: String, _ en: String) -> String {
        isRussian ? ru : en
    }

    // MARK: - Tabs
    static var tabToday: String      { s("Сегодня", "Today") }
    static var tabCalendar: String   { s("Календарь", "Calendar") }
    static var tabAll: String        { s("Все", "All") }

    // MARK: - Common
    static var save: String          { s("Сохранить", "Save") }
    static var cancel: String        { s("Отмена", "Cancel") }
    static var delete: String        { s("Удалить", "Delete") }
    static var edit: String          { s("Редактировать", "Edit") }
    static var share: String         { s("Поделиться", "Share") }
    static var done: String          { s("Готово", "Done") }
    static var openLink: String      { s("Открыть ссылку", "Open Link") }

    // MARK: - Card types
    static var newCard: String       { s("Новая карточка", "New Card") }
    static var cardText: String      { s("Текст", "Text") }
    static var cardPhoto: String     { s("Фото + аннотации", "Photo + Notes") }
    static var cardCamera: String    { s("Снять фото", "Take Photo") }
    static var cardLink: String      { s("Ссылка", "Link") }

    // MARK: - Text editor
    static var newNote: String       { s("Новая заметка", "New Note") }
    static var titlePlaceholder: String { s("Заголовок", "Title") }
    static var commentPlaceholder: String { s("Комментарий...", "Comment...") }

    // MARK: - Image editor
    static var newPhoto: String      { s("Новое фото", "New Photo") }
    static var photoName: String     { s("Название", "Name") }
    static var annotationHint: String { s("Коснитесь изображения — поставьте метку", "Tap the image to place a pin") }
    static var noAnnotations: String { s("Нет аннотаций", "No annotations") }

    // MARK: - Annotation input
    static var addAnnotation: String { s("Новая метка", "New Pin") }
    static var editAnnotationTitle: String { s("Редактировать метку", "Edit Pin") }
    static var annotationPlaceholder: String { s("Заметка к этому месту...", "Note for this spot...") }

    // MARK: - Link editor
    static var newLink: String       { s("Новая ссылка", "New Link") }
    static var editLinkTitle: String { s("Редактировать ссылку", "Edit Link") }
    static var urlPlaceholder: String { s("https://...", "https://...") }
    static var linkNamePlaceholder: String { s("Название (необязательно)", "Name (optional)") }

    // MARK: - Calendar
    static var today: String         { s("Сегодня", "Today") }
    static var yesterday: String     { s("Вчера", "Yesterday") }
    static var emptyDay: String      { s("Нет заметок", "No notes") }
    static var emptyDayHint: String  { s("Нажмите + чтобы добавить", "Tap + to add") }

    // MARK: - Tasks
    static var todaySection: String  { s("СЕГОДНЯ", "TODAY") }
    static var yesterdaySection: String { s("ВЧЕРА", "YESTERDAY") }

    // MARK: - Pin list
    static var pinList: String { s("Метки", "Pins") }
    static func pinNumber(_ n: Int) -> String { s("Метка \(n)", "Pin \(n)") }

    // MARK: - Filter chips
    static var filterAll:   String { s("Все", "All") }
    static var filterText:  String { s("Текст", "Text") }
    static var filterImage: String { s("Фото", "Photo") }
    static var filterLink:  String { s("Ссылки", "Links") }

    // MARK: - Tags
    static var tags:    String { s("Теги", "Tags") }
    static var addTag:  String { s("Добавить тег", "Add tag") }
    static var newTag:  String { s("Новый тег", "New tag") }

    // MARK: - Search
    static var searchPlaceholder: String { s("Поиск заметок...", "Search notes...") }
    static var searchNoResults:   String { s("Ничего не найдено", "No results") }

    // MARK: - Card type sections
    static var sectionText:  String { s("ЗАМЕТКИ", "NOTES") }
    static var sectionImage: String { s("ФОТО", "PHOTOS") }
    static var sectionLink:  String { s("ССЫЛКИ", "LINKS") }

    // MARK: - Theme
    static var themeSystem: String { s("Системная", "System") }
    static var themeLight:  String { s("Светлая", "Light") }
    static var themeDark:   String { s("Тёмная", "Dark") }
    static var theme:       String { s("Тема", "Theme") }

    // MARK: - Reminders
    static var reminder:            String { s("Напоминание", "Reminder") }
    static var reminderSet:         String { s("Напомнить в", "Reminder at") }
    static var removeReminder:      String { s("Убрать напоминание", "Remove reminder") }
    static var setReminder:         String { s("Установить", "Set") }
    static var remindMe:            String { s("Напомнить", "Remind me") }
    static var reminderDefaultBody: String { s("Напоминание о заметке", "Note reminder") }

    // MARK: - Annotation count
    static func annotationCount(_ n: Int) -> String {
        if isRussian {
            switch n % 10 {
            case 1 where n % 100 != 11: return "1 метка"
            case 2...4 where !(n % 100 >= 12 && n % 100 <= 14): return "\(n) метки"
            default: return "\(n) меток"
            }
        } else {
            return n == 1 ? "1 pin" : "\(n) pins"
        }
    }
}
