import SwiftUI
import WidgetKit

struct DeadlinerWidgetEntryView: View {
    var entry: DeadlinerWidgetProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryInline:
            InlineWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        case .accessoryCircular:
            CircularWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        case .accessoryRectangular:
            if entry.task != nil {
                RectangularWidgetView(entry: entry)
                    .containerBackground(.clear, for: .widget)
            } else {
                Text("所有任务已完成")
                    .font(.system(size: 14, weight: .medium).monospaced())
                    .foregroundStyle(.secondary)
                    .containerBackground(.clear, for: .widget)
            }
        case .systemSmall:
            SmallHomeWidgetView(entry: entry)
        case .systemMedium:
            MediumHomeWidgetView(entry: entry)
        default:
            EmptyView()
        }
    }
}

private struct InlineWidgetView: View {
    let entry: DeadlinerEntry

    private var urgentText: Text {
        Text(Image(systemName: "alarm.fill"))
        + Text(" \(entry.urgentCount) 任务 \(entry.nearestUrgentHours ?? 1) 小时内到期")
    }

    private var summaryText: Text {
        Text(Image(systemName: "checklist"))
        + Text(" 任务 \(entry.remainingCount)/\(entry.totalActiveCount) ")
        + Text(Image(systemName: "leaf.fill"))
        + Text(" 习惯 \(entry.habitRemainingCount)/\(entry.habitTotalCount)")
    }

    var body: some View {
        Group {
            if entry.urgentCount > 0, entry.nearestUrgentHours != nil {
                urgentText
            } else {
                summaryText
            }
        }
        .font(.system(size: 13, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}
