import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Lightweight DTO (matches WidgetCardSlim written by CardStore)

struct WCard: Codable {
    let id: UUID
    let type: String        // "text" | "image" | "link"
    let title: String
    let comment: String
    let createdAt: Date
    let dayDate: Date
    let deletedAt: Date?
    let reminderDate: Date?
}

// MARK: - Widget Card Store

private enum WidgetCardStore {

    private static let key = "daypin.widget_cards"

    /// All non-deleted cards sorted newest-first (up to `limit`).
    static func recentCards(limit: Int = 30) -> [WCard] {
        decode()?
            .filter { $0.deletedAt == nil }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .map { $0 }
        ?? []
    }

    /// Non-deleted cards for today.
    static func todayCards() -> [WCard] {
        let today = Calendar.current.startOfDay(for: .now)
        return decode()?
            .filter {
                $0.deletedAt == nil &&
                Calendar.current.startOfDay(for: $0.dayDate) == today
            }
            .sorted { $0.createdAt > $1.createdAt }
        ?? []
    }

    private static func decode() -> [WCard]? {
        guard let data = AppGroup.defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode([WCard].self, from: data)
    }
}

// MARK: - App Entity

struct CardAppEntity: AppEntity {

    var id: UUID
    var title: String
    var typeName: String
    var comment: String
    var reminderDate: Date?

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Note")
    static var defaultQuery = CardEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }

    var typeIcon: String {
        switch typeName {
        case "image": return "photo"
        case "link":  return "link"
        default:      return "text.alignleft"
        }
    }

    var hasActiveReminder: Bool {
        guard let d = reminderDate else { return false }
        return d > .now
    }

    init(from c: WCard) {
        id = c.id; title = c.title; typeName = c.type
        comment = c.comment; reminderDate = c.reminderDate
    }

    init(id: UUID, title: String, typeName: String, comment: String, reminderDate: Date?) {
        self.id = id; self.title = title; self.typeName = typeName
        self.comment = comment; self.reminderDate = reminderDate
    }
}

struct CardEntityQuery: EntityQuery {

    func entities(for identifiers: [UUID]) async throws -> [CardAppEntity] {
        WidgetCardStore.recentCards()
            .filter { identifiers.contains($0.id) }
            .map(CardAppEntity.init)
    }

    func suggestedEntities() async throws -> [CardAppEntity] {
        WidgetCardStore.recentCards().map(CardAppEntity.init)
    }
}

// MARK: - Widget Configuration Intent

struct DayPinIntent: WidgetConfigurationIntent {

    static var title: LocalizedStringResource = "Настроить DayPin"
    static var description = IntentDescription("Выберите до трёх заметок для отображения в виджете. Без выбора — показывает последние заметки.")

    /// Up to 3 pinned notes. Small shows the first; Medium shows all three.
    @Parameter(title: "Заметки")
    var cards: [CardAppEntity]?
}

// MARK: - Timeline Entry

struct DayPinEntry: TimelineEntry {
    let date: Date
    let todayCount: Int
    /// Most recent 3 cards across all dates — used as fallback when no pins chosen.
    let recentCards: [CardAppEntity]
    /// Cards chosen via the intent (may be empty).
    let pinnedCards: [CardAppEntity]
    /// ColorSchemeID raw value stored in App Group by ThemeManager.
    let accentSchemeID: Int
}

// MARK: - Provider

struct DayPinProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> DayPinEntry {
        let samples: [CardAppEntity] = [
            CardAppEntity(id: UUID(), title: "Идеи на утро", typeName: "text",
                          comment: "Записать план дня", reminderDate: nil),
            CardAppEntity(id: UUID(), title: "Статья про SwiftUI", typeName: "link",
                          comment: "medium.com/swift", reminderDate: Date().addingTimeInterval(3600)),
            CardAppEntity(id: UUID(), title: "Скриншот макета", typeName: "image",
                          comment: "", reminderDate: nil)
        ]
        return DayPinEntry(date: .now, todayCount: 7,
                           recentCards: samples, pinnedCards: [],
                           accentSchemeID: 0)
    }

    func snapshot(for configuration: DayPinIntent, in context: Context) async -> DayPinEntry {
        makeEntry(configuration)
    }

    func timeline(for configuration: DayPinIntent, in context: Context) async -> Timeline<DayPinEntry> {
        let entry = makeEntry(configuration)
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func makeEntry(_ config: DayPinIntent) -> DayPinEntry {
        let recent = Array(WidgetCardStore.recentCards(limit: 3).map(CardAppEntity.init))
        let todayCount = WidgetCardStore.todayCards().count
        let schemeID = AppGroup.defaults.integer(forKey: "daypin.colorSchemeID")
        let pinned = Array((config.cards ?? []).prefix(3))
        return DayPinEntry(
            date: .now,
            todayCount: todayCount,
            recentCards: recent,
            pinnedCards: pinned,
            accentSchemeID: schemeID
        )
    }
}

// MARK: - Accent Color Helper

private func widgetAccent(for schemeID: Int) -> Color {
    switch schemeID {
    case 0: return Color(red: 0.573, green: 0.463, blue: 1.000) // violet  #9276FF
    case 1: return Color(red: 0.129, green: 0.588, blue: 0.953) // ocean   #2196F3
    case 2: return Color(red: 0.157, green: 0.525, blue: 0.831) // nature  #2886D4
    case 3: return Color(red: 0.475, green: 0.525, blue: 0.796) // healing #7986CB
    case 4: return Color(red: 0.294, green: 0.376, blue: 0.498) // retro   #4B607F
    case 5: return Color(red: 0.584, green: 0.694, blue: 0.933) // spring  #95B1EE
    case 6: return Color(red: 0.525, green: 0.082, blue: 0.098) // vintage #861519
    case 7: return Color(red: 0.631, green: 0.514, blue: 0.898) // garden  #A184E5
    default: return Color(red: 0.573, green: 0.463, blue: 1.000)
    }
}

// MARK: - Mini Card Tile (Medium widget column)

struct MiniCardTile: View {
    let card: CardAppEntity
    let accent: Color

    var body: some View {
        Link(destination: URL(string: "daypin://open?cardID=\(card.id)")!) {
            VStack(alignment: .leading, spacing: 0) {

                // Top: type icon + bell
                HStack(alignment: .top) {
                    Image(systemName: card.typeIcon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(accent)
                    Spacer(minLength: 2)
                    if card.hasActiveReminder {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(accent)
                    }
                }

                Spacer(minLength: 6)

                // Title
                Text(card.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: false)

                // Comment
                if !card.comment.isEmpty {
                    Spacer(minLength: 3)
                    Text(card.comment)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .padding(9)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(accent.opacity(0.09))
            )
        }
    }
}

// MARK: - Root Widget View

struct DayPinWidgetView: View {

    var entry: DayPinEntry
    @Environment(\.widgetFamily) var family

    private var accent: Color { widgetAccent(for: entry.accentSchemeID) }

    /// Cards to display: pinned first, then recent as fallback.
    private var displayCards: [CardAppEntity] {
        entry.pinnedCards.isEmpty ? entry.recentCards : entry.pinnedCards
    }

    var body: some View {
        switch family {
        case .systemMedium:
            mediumView
        default:
            // Small: show pinned card if any, otherwise count overview
            if let first = entry.pinnedCards.first {
                smallCardView(first)
            } else {
                smallOverviewView
            }
        }
    }

    // MARK: - Small: Overview

    var smallOverviewView: some View {
        VStack(alignment: .leading, spacing: 0) {

            HStack(spacing: 4) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accent)
                Text("DayPin")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accent)
                Spacer()
                Text(shortDate)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text("\(entry.todayCount)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(noteCountLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Link(destination: URL(string: "daypin://add")!) {
                Label("Добавить", systemImage: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(accent)
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .widgetURL(URL(string: "daypin://today"))
    }

    // MARK: - Small: Pinned card

    func smallCardView(_ card: CardAppEntity) -> some View {
        Link(destination: URL(string: "daypin://open?cardID=\(card.id)")!) {
            VStack(alignment: .leading, spacing: 0) {

                HStack {
                    Image(systemName: card.typeIcon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(accent)
                    Spacer()
                    if card.hasActiveReminder {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(accent)
                    }
                }

                Spacer()

                Text(card.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)

                if !card.comment.isEmpty {
                    Spacer(minLength: 4)
                    Text(card.comment)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                HStack(spacing: 3) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(accent)
                    Text("DayPin")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(accent)
                }
            }
            .padding(14)
        }
    }

    // MARK: - Medium: Horizontal card collection

    var mediumView: some View {
        VStack(alignment: .leading, spacing: 10) {

            // ── Header row ──────────────────────────────────────────
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accent)
                Text("DayPin")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accent)

                // Today's count badge
                Text("\(entry.todayCount)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(accent)
                    .clipShape(Capsule())

                Spacer()

                Text(shortDate)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

                // + Add button
                Link(destination: URL(string: "daypin://add")!) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(accent)
                        .clipShape(Circle())
                }
            }

            // ── Horizontal card tiles ────────────────────────────────
            if displayCards.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "note.text")
                            .font(.system(size: 22))
                            .foregroundStyle(accent.opacity(0.4))
                        Text("Нет заметок")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                HStack(spacing: 8) {
                    ForEach(Array(displayCards.prefix(3)), id: \.id) { card in
                        MiniCardTile(card: card, accent: accent)
                    }
                    // Pad remaining columns so layout stays stable
                    if displayCards.count < 3 {
                        ForEach(0 ..< (3 - min(displayCards.count, 3)), id: \.self) { _ in
                            Spacer()
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .padding(14)
        .widgetURL(URL(string: "daypin://today"))
    }

    // MARK: - Helpers

    private var shortDate: String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("MMMd")
        return f.string(from: .now)
    }

    private var noteCountLabel: String {
        let n = entry.todayCount
        let isRu = Locale.preferredLanguages.first?.hasPrefix("ru") == true
        if isRu {
            let mod10 = n % 10, mod100 = n % 100
            if mod10 == 1 && mod100 != 11                               { return "заметка сегодня" }
            if (2...4).contains(mod10) && !(12...14).contains(mod100)  { return "заметки сегодня" }
            return "заметок сегодня"
        }
        return n == 1 ? "note today" : "notes today"
    }
}

// MARK: - Widget Definition

struct DayPinWidget: Widget {

    let kind = "DayPinWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: DayPinIntent.self,
            provider: DayPinProvider()
        ) { entry in
            DayPinWidgetView(entry: entry)
                .containerBackground(Color(.systemBackground), for: .widget)
        }
        .configurationDisplayName("DayPin")
        .description("Последние заметки или быстрый доступ к выбранным.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews

private let previewCards: [CardAppEntity] = [
    CardAppEntity(id: UUID(), title: "Идеи на утро", typeName: "text",
                  comment: "Записать план дня, встреча в 10:00", reminderDate: Date().addingTimeInterval(3600)),
    CardAppEntity(id: UUID(), title: "Статья про SwiftUI", typeName: "link",
                  comment: "medium.com/swiftui", reminderDate: nil),
    CardAppEntity(id: UUID(), title: "Скриншот макета", typeName: "image",
                  comment: "", reminderDate: nil)
]

#Preview(as: .systemSmall) {
    DayPinWidget()
} timeline: {
    // Small overview — no pins
    DayPinEntry(date: .now, todayCount: 7,
                recentCards: previewCards, pinnedCards: [],
                accentSchemeID: 0)
    // Small card mode — first card pinned
    DayPinEntry(date: .now, todayCount: 3,
                recentCards: previewCards, pinnedCards: [previewCards[0]],
                accentSchemeID: 1)
}

#Preview(as: .systemMedium) {
    DayPinWidget()
} timeline: {
    // Medium with 3 recent cards, violet scheme
    DayPinEntry(date: .now, todayCount: 7,
                recentCards: previewCards, pinnedCards: [],
                accentSchemeID: 0)
    // Medium with pinned selection, ocean scheme
    DayPinEntry(date: .now, todayCount: 3,
                recentCards: previewCards, pinnedCards: Array(previewCards.prefix(2)),
                accentSchemeID: 1)
    // Empty state, garden scheme
    DayPinEntry(date: .now, todayCount: 0,
                recentCards: [], pinnedCards: [],
                accentSchemeID: 7)
}
