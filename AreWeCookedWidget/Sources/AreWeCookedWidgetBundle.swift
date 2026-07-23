import WidgetKit
import SwiftUI

struct AreWeCookedWidget: Widget {
    let kind = "AreWeCookedWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AreWeCookedTimelineProvider()) { entry in
            AreWeCookedWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(red: 0.11, green: 0.11, blue: 0.12)
                }
        }
        .configurationDisplayName("Are We Cooked?")
        .description("Shows your API spend and token usage across providers.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct AreWeCookedWidgetBundle: WidgetBundle {
    var body: some Widget {
        AreWeCookedWidget()
    }
}
