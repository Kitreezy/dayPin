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
