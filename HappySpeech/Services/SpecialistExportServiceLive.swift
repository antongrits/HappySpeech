import Foundation
import OSLog
#if canImport(UIKit)
import UIKit
#endif

// MARK: - SpecialistExportService Protocol

/// Сервис экспорта данных специалиста. CSV — чистый текст (живёт в
/// `ReportsDocumentFormatter`), PDF — рендер через PDFKit / UIKit.
///
/// Выделен в отдельный протокол, чтобы можно было:
///   • Подменять на стуб в тестах (`SpecialistExportServiceMock`).
///   • Не тянуть UIKit в чистый Foundation-код аггрегатора.
public protocol SpecialistExportService: Sendable {
    func generatePDF(childId: String, sessions: [SessionDTO]) async throws -> URL
    func generateCSV(childId: String, sessions: [SessionDTO]) async throws -> URL
}

// MARK: - SpecialistExportServiceLive
//
// Оборачивает `ReportsDocumentFormatter` (plaintext + CSV) и рендерит
// `makePlainTextReport` в многостраничный PDF формата A4 через UIGraphicsPDFRenderer.
// Header: «HappySpeech — отчёт о прогрессе» + дата.
// Body: форматированный текст + per-sound-столбчатая диаграмма через UIBezierPath.
// Footer: номер страницы.
//
// Все строки — на русском через String Catalog.

public final class SpecialistExportServiceLive: SpecialistExportService, @unchecked Sendable {

    // MARK: - Layout

    /// ISO 216 A4 в points (1pt = 1/72 дюйма, 210×297 мм).
    private enum Layout {
        static let pageWidth: CGFloat = 595.2
        static let pageHeight: CGFloat = 841.8
        static let margin: CGFloat = 36
        static let headerHeight: CGFloat = 64
        static let footerHeight: CGFloat = 36
        static let chartHeight: CGFloat = 160
        static let lineHeight: CGFloat = 16
    }

    private let fileManager: FileManager
    private let directoryName: String

    public init(
        fileManager: FileManager = .default,
        directoryName: String = "hs-reports"
    ) {
        self.fileManager = fileManager
        self.directoryName = directoryName
    }

    // MARK: - CSV (проксируется на ReportsDocumentFormatter)

    public func generateCSV(childId: String, sessions: [SessionDTO]) async throws -> URL {
        let csv = ReportsDocumentFormatter.makeCSV(sessions: sessions)
        let url = try destinationURL(childId: childId, ext: "csv")
        try csv.data(using: .utf8)?.write(to: url, options: .atomic)
        HSLogger.app.info("CSV export written: \(url.lastPathComponent)")
        return url
    }

    // MARK: - PDF

    public func generatePDF(childId: String, sessions: [SessionDTO]) async throws -> URL {
        let plainText = ReportsDocumentFormatter.makePlainTextReport(
            childId: childId,
            sessions: sessions
        )
        let breakdown = ReportsAggregator.soundBreakdown(sessions: sessions)
        let url = try destinationURL(childId: childId, ext: "pdf")

        #if canImport(UIKit)
        try await renderPDF(
            to: url,
            plainText: plainText,
            breakdown: breakdown
        )
        #else
        // Fallback для non-UIKit окружений (unit-тесты на macOS CLI).
        try plainText.data(using: .utf8)?.write(to: url, options: .atomic)
        #endif

        HSLogger.app.info("PDF export written: \(url.lastPathComponent)")
        return url
    }

    // MARK: - Private

    private func destinationURL(childId: String, ext: String) throws -> URL {
        let dir = fileManager.temporaryDirectory
            .appendingPathComponent(directoryName, isDirectory: true)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        let timestamp = Int(Date().timeIntervalSince1970)
        return dir.appendingPathComponent("report-\(childId)-\(timestamp).\(ext)")
    }

    #if canImport(UIKit)
    @MainActor
    private func renderPDF(
        to url: URL,
        plainText: String,
        breakdown: [SoundBreakdownRow]
    ) throws {
        let pageRect = CGRect(x: 0, y: 0, width: Layout.pageWidth, height: Layout.pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        // Предварительно разобьём plaintext на строки, подходящие под ширину страницы.
        let bodyFont = UIFont.systemFont(ofSize: 11, weight: .regular)
        let bodyLines = Self.wrapLines(
            text: plainText,
            font: bodyFont,
            maxWidth: Layout.pageWidth - Layout.margin * 2
        )

        let maxBodyY = Layout.pageHeight - Layout.footerHeight - Layout.margin
        let linesPerPage = Int(
            (maxBodyY - Layout.headerHeight - Layout.margin) / Layout.lineHeight
        )
        guard linesPerPage > 0 else {
            throw AppError.unknown("PDF layout: no vertical space for body")
        }

        // Разбиваем строки на страницы. Диаграмма рендерится только на 1-й странице.
        var pages: [[String]] = []
        var cursor = 0
        while cursor < bodyLines.count {
            // На первой странице резервируем место под диаграмму, если данные есть.
            let capacity: Int
            if pages.isEmpty, !breakdown.isEmpty {
                let reserved = Int(Layout.chartHeight / Layout.lineHeight) + 2
                capacity = max(1, linesPerPage - reserved)
            } else {
                capacity = linesPerPage
            }
            let end = min(bodyLines.count, cursor + capacity)
            pages.append(Array(bodyLines[cursor..<end]))
            cursor = end
        }
        if pages.isEmpty { pages = [[]] }

        let totalPages = pages.count

        try renderer.writePDF(to: url) { context in
            for (index, lines) in pages.enumerated() {
                context.beginPage()
                drawHeader(in: context.pdfContextBounds)
                let bodyStart = Layout.headerHeight + Layout.margin / 2
                drawBody(lines: lines, topY: bodyStart, font: bodyFont)

                if index == 0, !breakdown.isEmpty {
                    let usedLines = CGFloat(lines.count)
                    let chartY = bodyStart + usedLines * Layout.lineHeight + Layout.margin / 2
                    drawBarChart(rows: breakdown, topY: chartY)
                }

                drawFooter(pageIndex: index, pageCount: totalPages)
            }
        }
    }

    @MainActor
    private func drawHeader(in bounds: CGRect) {
        let title = String(localized: "reports.pdf.title")
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        let dateString = dateFormatter.string(from: Date())

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor.black,
        ]
        let dateAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor.darkGray,
        ]

        title.draw(
            at: CGPoint(x: Layout.margin, y: Layout.margin / 2),
            withAttributes: titleAttrs
        )
        dateString.draw(
            at: CGPoint(x: Layout.margin, y: Layout.margin / 2 + 22),
            withAttributes: dateAttrs
        )

        // Разделительная линия под header.
        let separator = UIBezierPath()
        separator.move(to: CGPoint(x: Layout.margin, y: Layout.headerHeight))
        separator.addLine(to: CGPoint(x: bounds.width - Layout.margin, y: Layout.headerHeight))
        UIColor.lightGray.setStroke()
        separator.lineWidth = 0.5
        separator.stroke()
    }

    @MainActor
    private func drawBody(lines: [String], topY: CGFloat, font: UIFont) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black,
        ]
        for (offset, line) in lines.enumerated() {
            let y = topY + CGFloat(offset) * Layout.lineHeight
            line.draw(at: CGPoint(x: Layout.margin, y: y), withAttributes: attrs)
        }
    }

    @MainActor
    private func drawBarChart(rows: [SoundBreakdownRow], topY: CGFloat) {
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 12),
            .foregroundColor: UIColor.black,
        ]
        String(localized: "reports.pdf.chart.title").draw(
            at: CGPoint(x: Layout.margin, y: topY),
            withAttributes: titleAttrs
        )

        let chartOriginY = topY + 20
        let chartWidth = Layout.pageWidth - Layout.margin * 2
        let barCount = max(1, rows.count)
        let spacing: CGFloat = 8
        let barWidth = (chartWidth - spacing * CGFloat(barCount - 1)) / CGFloat(barCount)
        let chartMaxHeight = Layout.chartHeight - 40

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .medium),
            .foregroundColor: UIColor.black,
        ]

        for (index, row) in rows.enumerated() {
            let confidence = max(0, min(1, row.averageConfidence))
            let barHeight = chartMaxHeight * CGFloat(confidence)
            let x = Layout.margin + CGFloat(index) * (barWidth + spacing)
            let y = chartOriginY + (chartMaxHeight - barHeight)

            let bar = UIBezierPath(
                roundedRect: CGRect(x: x, y: y, width: barWidth, height: barHeight),
                cornerRadius: 3
            )
            colorForConfidence(confidence).setFill()
            bar.fill()

            // Подпись: звук + проценты.
            let label = "\(row.sound) \(Int(confidence * 100))%"
            label.draw(
                at: CGPoint(x: x, y: chartOriginY + chartMaxHeight + 4),
                withAttributes: labelAttrs
            )
        }
    }

    @MainActor
    private func drawFooter(pageIndex: Int, pageCount: Int) {
        let footerY = Layout.pageHeight - Layout.footerHeight
        let format = String(localized: "reports.pdf.footer.pageOf")
        let text = String(format: format, pageIndex + 1, pageCount)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .regular),
            .foregroundColor: UIColor.darkGray,
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let x = (Layout.pageWidth - size.width) / 2
        text.draw(at: CGPoint(x: x, y: footerY), withAttributes: attrs)
    }

    private func colorForConfidence(_ value: Double) -> UIColor {
        switch value {
        case ..<0.5:
            return UIColor.systemRed.withAlphaComponent(0.75)
        case ..<0.8:
            return UIColor.systemOrange.withAlphaComponent(0.75)
        default:
            return UIColor.systemGreen.withAlphaComponent(0.75)
        }
    }

    // MARK: - Text wrapping (pure, MainActor-agnostic)

    nonisolated static func wrapLines(
        text: String,
        font: UIFont,
        maxWidth: CGFloat
    ) -> [String] {
        var out: [String] = []
        let rawLines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        for rawLine in rawLines {
            let line = String(rawLine)
            if line.isEmpty { out.append(""); continue }

            let width = (line as NSString).size(withAttributes: attrs).width
            if width <= maxWidth {
                out.append(line)
                continue
            }

            // Жадный word-wrap.
            var current = ""
            for word in line.split(separator: " ") {
                let candidate = current.isEmpty ? String(word) : current + " " + String(word)
                let candidateWidth = (candidate as NSString).size(withAttributes: attrs).width
                if candidateWidth > maxWidth {
                    if !current.isEmpty { out.append(current) }
                    current = String(word)
                } else {
                    current = candidate
                }
            }
            if !current.isEmpty { out.append(current) }
        }
        return out
    }
    #endif
}
