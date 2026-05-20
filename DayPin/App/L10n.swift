import Foundation

extension Notification.Name {
    static let dayPinLanguageChanged = Notification.Name("dayPinLanguageChanged")
}

enum L10n {

    // MARK: - In-app language override (nil = follow device)
    static var languageOverride: String? {
        get { UserDefaults.standard.string(forKey: "daypin.langOverride") }
        set {
            if let v = newValue { UserDefaults.standard.set(v, forKey: "daypin.langOverride") }
            else { UserDefaults.standard.removeObject(forKey: "daypin.langOverride") }
            NotificationCenter.default.post(name: .dayPinLanguageChanged, object: nil)
        }
    }

    /// `true` when the active language is Russian (device or override).
    static var isRussian: Bool {
        if let override = languageOverride { return override == "ru" }
        return Locale.preferredLanguages.first?.hasPrefix("ru") == true
    }

    /// Locale object matching the active language — use this in DateFormatters.
    static var activeLocale: Locale {
        Locale(identifier: isRussian ? "ru_RU" : "en_US")
    }

    private static func s(_ ru: String, _ en: String) -> String {
        isRussian ? ru : en
    }

    // MARK: - Language names
    static var language:     String { s("Язык", "Language") }
    static var langRussian:  String { "Русский" }
    static var langEnglish:  String { "English" }
    static var langSystem:   String { s("Системный", "System") }

    // MARK: - Tabs
    static var tabToday: String      { s("Сегодня", "Today") }
    static var tabCalendar: String   { s("Календарь", "Calendar") }
    static var tabFolders: String    { s("Папки", "Folders") }
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
    static var cardPhotoPin: String  { s("Фотопин", "Photo Pin") }
    static var cardCameraShort: String { s("Камера", "Camera") }
    static var cardLink: String      { s("Ссылка", "Link") }

    // MARK: - Text editor
    static var newNote: String       { s("Новая заметка", "New Note") }
    static var titlePlaceholder: String { s("Заголовок", "Title") }
    static var commentPlaceholder: String { s("Комментарий...", "Comment...") }
    static var listBullet: String    { s("Маркер (•)", "Bullet (•)") }
    static var listNumbered: String  { s("Нумерация (1.)", "Numbered (1.)") }
    static var listDash: String      { s("Тире (-)", "Dash (-)") }

    // MARK: - Image editor
    static var newPhoto: String      { s("Новое фото", "New Photo") }
    static var photoName: String     { s("Название", "Name") }
    static var annotationHint: String { s("Коснитесь изображения - поставьте метку", "Tap the image to place a pin") }
    static var noAnnotations: String { s("Нет аннотаций", "No annotations") }

    // MARK: - Annotation input
    static var addAnnotation: String { s("Новая метка", "New Pin") }
    static var editAnnotationTitle: String { s("Редактировать метку", "Edit Pin") }
    static var annotationPlaceholder: String { s("Заметка к этому месту...", "Note for this spot...") }
    static var commentOptionalPlaceholder: String { s("Комментарий (необязательно)", "Comment (optional)") }

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

    // MARK: - Navigation / Actions
    static var copyAction: String   { s("Скопировать", "Copy") }
    static var close: String        { s("Закрыть", "Close") }
    static var add: String          { s("Добавить", "Add") }
    static var clearAll: String     { s("Очистить всё", "Clear All") }
    static var emptyTrashTitle: String   { s("Очистить всю корзину?", "Empty Trash?") }
    static var emptyTrashMessage: String { s("Все заметки будут удалены навсегда. Это действие нельзя отменить.", "All notes will be permanently deleted. This cannot be undone.") }
    static var emptyTrashConfirm: String { s("Очистить", "Empty") }
    static var back: String              { s("Назад", "Back") }
    static var deletePin: String         { s("Удалить пин", "Delete pin") }
    static var pinTitlePlaceholder: String { s("Название", "Title") }
    static var selectNotes: String  { s("Выбрать заметки", "Select Notes") }
    static var copyToDay: String    { s("Скопировать в день", "Copy to Day") }
    static var addNotes: String     { s("Добавить заметки", "Add Notes") }
    static func addNotesCount(_ n: Int) -> String { s("Добавить \(n) заметок", "Add \(n) notes") }
    static var noNotesForPicker: String     { s("Заметок пока нет", "No notes yet") }
    static var noNotesForPickerHint: String { s("Добавьте заметки на главном экране", "Add notes from the main screen") }
    static var addToFolder: String       { s("Добавить в папку", "Add to Folder") }
    static var inFolder: String          { s("В папку", "To Folder") }
    static var noFoldersHint: String     { s("Нет папок - создайте во вкладке «Папки»", "No folders - create one in the Folders tab") }
    static var noFolders: String         { s("Нет папок", "No folders") }
    static var noFoldersMessage: String  { s("Создайте папку в разделе «Папки»", "Create a folder in the Folders section") }
    static var chooseFolderTitle: String { s("Выберите папку", "Choose Folder") }
    static var selectNote: String        { s("Выбрать", "Select") }
    static var selectNotesPrompt: String { s("Выберите заметки", "Select notes") }
    static func selectedCount(_ n: Int) -> String { s("Выбрано: \(n)", "Selected: \(n)") }
    static func deleteNotesTitle(_ n: Int) -> String { s("Удалить \(n) заметок?", "Delete \(n) notes?") }
    static var newFolder: String         { s("Новая папка", "New Folder") }
    static var editFolder: String        { s("Изменить папку", "Edit Folder") }
    static var folderNamePlaceholder: String { s("Название папки", "Folder name") }
    static var folderColorLabel: String  { s("ЦВЕТ ПАПКИ", "FOLDER COLOR") }
    static var emoji: String             { s("Эмодзи", "Emoji") }
    static var defaultIcon: String       { s("По умолч.", "Default") }
    static var chooseEmoji: String       { s("Выберите эмодзи", "Choose Emoji") }
    static var emojiHint: String         { s("Введите или вставьте один эмодзи", "Enter or paste one emoji") }
    static var imageLabel: String        { s("Изображение", "Image") }
    static var addExisting: String       { s("Добавить существующие", "Add Existing") }
    static var removeFromFolder: String  { s("Убрать из папки", "Remove from Folder") }
    static var deleteFolderTitle: String { s("Удалить папку?", "Delete Folder?") }
    static var deleteFolderMessage: String { s("Заметки останутся, но будут откреплены от папки.", "Notes will remain but be detached from the folder.") }
    static var allNotesInFolder: String  { s("Все заметки уже в этой папке", "All notes are already in this folder") }
    static var noNotesLabel: String      { s("нет заметок", "no notes") }
    static var colorBlue: String         { s("Синий", "Blue") }
    static var colorRed: String          { s("Красный", "Red") }
    static var colorGreen: String        { s("Зелёный", "Green") }
    static var colorOrange: String       { s("Оранж.", "Orange") }
    static var colorPurple: String       { s("Фиолет.", "Purple") }
    static var colorYellow: String       { s("Жёлтый", "Yellow") }
    static var colorTeal: String         { s("Бирюза", "Teal") }
    static var colorPink: String         { s("Роз.", "Pink") }
    static var noteSection: String       { s("ЗАМЕТКА", "NOTE") }
    static var pinsSection: String       { s("ПИНЫ", "PINS") }
    static var addPinButton: String      { s("+ Добавить пин", "+ Add pin") }
    static var tapForFullView: String    { s("Нажмите - полный просмотр", "Tap for full view") }
    static var tapToAddNote: String      { s("Нажмите ✎, чтобы добавить заметку...", "Tap ✎ to add a note...") }

    // MARK: - Card type labels (short, used in search pills)
    static var cardTypeNote: String  { s("Заметка", "Note") }
    static var cardTypePhoto: String { s("Фото", "Photo") }
    static var cardTypeLink: String  { s("Ссылка", "Link") }

    // MARK: - Calendar
    static var calendarTitle: String       { s("Календарь", "Calendar") }
    static var calendarTodayBtn: String    { s("  Сегодня", "  Today") }
    static var calendarSelectMonth: String { s("Выбор месяца", "Select Month") }
    static var calendarNotesSection: String { s("ЗАМЕТКИ", "NOTES") }
    static var calendarNoNotes: String     { s("Нет заметок за этот день", "No notes for this day") }
    static var bgApplied: String           { s("✓ Применено", "✓ Applied") }

    // MARK: - Undo
    static var noteDeleted: String  { s("Заметка удалена", "Note deleted") }
    static var undo: String         { s("Отменить", "Undo") }

    // MARK: - Recently Deleted
    static var recentlyDeleted: String    { s("Недавно удалённые", "Recently Deleted") }
    static var noDeletedNotes: String     { s("Нет удалённых заметок", "No deleted notes") }
    static var autoDeleteNote: String     { s("Заметки удаляются автоматически через 30 дней", "Notes are automatically deleted after 30 days") }
    static var deleteForever: String      { s("Удалить навсегда", "Delete Forever") }
    static var deletedToday: String       { s("Сегодня", "Today") }
    static func daysRemaining(_ n: Int) -> String { s("ещё \(n) д.", "\(n) d. left") }
    static func deletedNotePrefix(_ date: String) -> String { s("Удалена: \(date)", "Deleted: \(date)") }

    // MARK: - Backup
    static var backup: String             { s("Резервная копия", "Backup") }
    static var backupSave: String         { s("Сохранить копию", "Save Backup") }
    static var backupRestore: String      { s("Восстановить", "Restore") }
    static var backupStats: String        { s("Статистика", "Statistics") }
    static var backupCreate: String       { s("Создать резервную копию", "Create Backup") }
    static var backupRestoreFromFile: String { s("Восстановить из файла", "Restore from File") }
    static var backupChooseFile: String   { s("Выбрать .json файл резервной копии", "Choose .json backup file") }
    static var backupDescription: String  { s("Включает ВСЕ заметки за все дни, изображения и папки. Сохраняется как .json - откройте в Files, сохраните в iCloud Drive или отправьте на другое устройство.", "Includes ALL notes for all days, images and folders. Saved as .json - open in Files, save to iCloud Drive or send to another device.") }
    static var restoreDescription: String { s("Текущие данные будут полностью заменены. Выберите файл .json, созданный этим приложением.", "Current data will be completely replaced. Choose a .json file created by this app.") }
    static var restoreDataTitle: String   { s("Восстановить данные?", "Restore Data?") }
    static var restoring: String          { s("Восстанавливаем…", "Restoring…") }
    static var restoreDone: String        { s("Готово", "Done") }
    static var restoreError: String       { s("Ошибка восстановления", "Restore Error") }
    static var exportError: String        { s("Ошибка экспорта", "Export Error") }
    static var readingFile: String        { s("Читаем файл…", "Reading file…") }
    static var fileError: String          { s("Ошибка файла", "File Error") }
    static var fileCorrupted: String      { s("Файл повреждён или имеет неверный формат.", "File is corrupted or has an invalid format.") }
    static func restoreSuccess(cards: Int, folders: Int) -> String {
        s("Восстановлено:\nЗаметок: \(cards)\nПапок: \(folders)", "Restored:\nNotes: \(cards)\nFolders: \(folders)")
    }
    static func restoreConfirmMessage(date: String, cards: Int, imgCards: Int, folders: Int) -> String {
        s(
            "Файл создан: \(date)\n\nЗаметок: \(cards) (\(imgCards) с фото)\nПапок: \(folders)\n\n⚠️ Текущие данные будут полностью заменены.",
            "File created: \(date)\n\nNotes: \(cards) (\(imgCards) with photo)\nFolders: \(folders)\n\n⚠️ Current data will be completely replaced."
        )
    }
    static func backupSummary(cards: Int, days: Int, imgs: Int, folders: Int) -> String {
        s(
            "Заметок всего: \(cards)\nДней с заметками: \(days)\nС изображениями: \(imgs)\nПапок: \(folders)",
            "Total notes: \(cards)\nDays with notes: \(days)\nWith images: \(imgs)\nFolders: \(folders)"
        )
    }
    static func notesDayCount(notes: Int, days: Int) -> String {
        if isRussian {
            let dayWord: String
            let m10 = days % 10; let m100 = days % 100
            if m100 >= 11 && m100 <= 19 { dayWord = "дней" }
            else if m10 == 1 { dayWord = "день" }
            else if (2...4).contains(m10) { dayWord = "дня" }
            else { dayWord = "дней" }
            return "\(notes) заметок за \(days) \(dayWord)"
        } else {
            return "\(notes) notes over \(days) \(days == 1 ? "day" : "days")"
        }
    }

    // MARK: - Appearance / Theme
    static var appearance: String         { s("Оформление", "Appearance") }
    static var background: String         { s("Фон", "Background") }
    static var brightness: String         { s("Яркость", "Brightness") }
    static var colorScheme: String        { s("Цветовая схема", "Color Scheme") }
    static var apply: String              { s("Применить", "Apply") }
    static var bgStandard: String         { s("Стандарт", "Standard") }
    static var bgColor: String            { s("Цвет", "Color") }
    static var bgGradient: String         { s("Градиент", "Gradient") }
    static var bgColorLabel: String       { s("Цвет фона", "Background color") }
    static var bgStartColor: String       { s("Начальный цвет", "Start color") }
    static var bgEndColor: String         { s("Конечный цвет", "End color") }
    static var bgAngle: String            { s("Угол", "Angle") }

    // MARK: - Photo / Link editor extras
    static var showAllPhotos: String      { s("  Показать все фото", "  Show All Photos") }
    static var recentPhotos: String       { s("Последние фото", "Recent Photos") }
    static var addCover: String           { s("Добавить обложку", "Add Cover") }
    static var cover: String              { s("Обложка", "Cover") }
    static var linkNameLabel: String      { s("Название", "Name") }
    static var titleOptionalPlaceholder: String { s("Заголовок (необязательно)", "Title (optional)") }
    static var urlPastePlaceholder: String { s("Вставьте ссылку…", "Paste a link…") }
    static var untitledNote: String       { s("Заметка", "Note") }

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
