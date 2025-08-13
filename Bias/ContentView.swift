//
//  ContentView.swift
//  Bias
//
//  Created by Joel Savitz on 8/10/25.
//

import SwiftUI
import MarkdownUI

struct SourceListSettingsView: View {
    @AppStorage("hostname") private var hostname: String = "yeast.news"
    
    var body: some View {
        Form {
            Section(header: Text("BIAS Server Configuration")) {
                TextField("Hostname", text: $hostname)
            }
        }
    }
}

struct ReportListSettingsView: View {
    
    var body: some View {
        Text("Report list settings")
    }
}

struct ReportInfoView: View {
    var body: some View {
        Text("Report info")
    }
}
let markdownText = """
# TITLE render

hi

1. first
2. second
3. third

---

[foo](https://underground.software)
"""

struct ReportView: View {
    @ObservedObject var model: BiasModel
    let source: String
    let after: String
    let before: String
    let title: String
    
    var body: some View {
        ScrollView {
            Markdown(model.selectedReport.text)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(Text(title))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                NavigationLink(destination: ReportInfoView()) {
                    Image(systemName: "info.circle")
                }
                Spacer()
                ShareLink(
                    item: model.selectedReport.text,
                    subject: Text("Bias Report")
                ) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
        .onAppear() {
            Task {
                do {
                    let reply = try await model.fetchSelectedReport(for: self.source, after: self.after, before: self.before)
                    model.selectedReport = reply.data
                } catch {
                    print("Error fetching report: \(error)")
                }
            }
        }
        .refreshable {
            do {
                let reply = try await model.fetchSelectedReport(for: self.source, after: self.after, before: self.before)
                model.selectedReport = reply.data
            } catch {
                print("Error fetching report: \(error)")
            }
        }
    }
}

struct ReportListView: View {
    @ObservedObject var model: BiasModel
    let source: String

    var body: some View {
        Form {
            ForEach(model.selectedSourceReports) { report in
                NavigationLink(destination: ReportView(model: model, source: source, after: report.after, before: report.before, title: "From \(report.after) to \(report.before)")) {
                    Text("From \(report.after) to \(report.before)")
                }
            }
        }
        .navigationTitle(Text("\(source) reports"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                NavigationLink(destination: ReportListSettingsView()) {
                    Image(systemName: "info.circle")
                }
            }
        }
        .onAppear() {
            Task {
                do {
                    let reply = try await model.fetchSelectedReportList(for: source)
                    model.selectedSourceReports = reply.data
                } catch {
                    print("Error fetching report list: \(error)")
                }
            }
        }
        .refreshable {
            Task {
                do {
                    let reply = try await model.fetchSelectedReportList(for: source)
                    model.selectedSourceReports = reply.data
                } catch {
                    print("Error fetching report list: \(error)")
                }
            }
        }
    }
}

struct BiasError: Decodable, Error {
    let timestamp: String
    let error: String
}

struct BiasReportContent: Decodable {
    let text: String
    let after: String
    let before: String
    let timestamp: String
    
    init() {
        self.text = ""
        self.after = ""
        self.before = ""
        self.timestamp = ""
    }
}

struct BiasReportReply: Decodable {
    let timestamp: String
    let data: BiasReportContent
    
    init() {
        self.timestamp = ""
        self.data = BiasReportContent()
    }
}

struct BiasReportsListEntry: Decodable, Identifiable {
    let id = UUID()
    let after: String
    let before: String
    
    enum CodingKeys: String, CodingKey {
        case after = "after"
        case before = "before"
    }
}


struct BiasReportsListReply: Decodable {
    let timestamp: String
    let data: [BiasReportsListEntry]
}

struct BiasSourcesReply: Decodable {
    let timestamp: String
    let data: [String]
}


class BiasModel: ObservableObject {
    @AppStorage("hostname") var hostname = "yeast.news"
    @Published var sources: [String] = []
    @Published var selectedSource: String = ""
    @Published var selectedSourceReports: [BiasReportsListEntry] = []
    @Published var selectedReport: BiasReportContent = BiasReportContent()
    
    func fetchSources() async throws -> BiasSourcesReply {
        let (data, _) = try await URLSession.shared.data(from: URL(string: "https://\(hostname)/api/sources")!)
        
        do {
            return try JSONDecoder().decode(BiasSourcesReply.self, from: data)
        } catch {
            if let apiError = try? JSONDecoder().decode(BiasError.self, from: data) {
                throw apiError
            } else {
                throw error
            }
        }
    }
    
    func fetchReportList(for source: String) async throws -> BiasReportsListReply {
        let (data, _) = try await URLSession.shared.data(from: URL(string: "https://\(hostname)/api/reports/\(source)")!)
        
        do {
            return try JSONDecoder().decode(BiasReportsListReply.self, from: data)
        } catch {
            if let apiError = try? JSONDecoder().decode(BiasError.self, from: data) {
                throw apiError
            } else {
                throw error
            }
        }
    }
    
    func fetchSelectedReportList(for source: String) async throws -> BiasReportsListReply {
        return try await fetchReportList(for: source)
    }
    
    func fetchReport(for source: String, after: String, before: String) async throws -> BiasReportReply {
        let (data, _) = try await URLSession.shared.data(from: URL(string: "https://\(hostname)/api/reports/\(source)?after=\(after)&before=\(before)")!)
        
        do {
            return try JSONDecoder().decode(BiasReportReply.self, from: data)
        } catch {
            if let apiError = try? JSONDecoder().decode(BiasError.self, from: data) {
                throw apiError
            } else {
                throw error
            }
        }
        
    }
    
    func fetchSelectedReport(for source: String, after: String, before: String) async throws -> BiasReportReply {
        var afterDate: String = ""
        var beforeDate: String = ""
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime] // default ISO8601
        if let isoafter = isoFormatter.date(from: after) {
            
            // 2. Format as "YYYY-MM-DD"
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy-MM-dd"
            afterDate = displayFormatter.string(from: isoafter)
        }
        if let isobefore = isoFormatter.date(from: before) {
            
            // 2. Format as "YYYY-MM-DD"
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy-MM-dd"
            beforeDate = displayFormatter.string(from: isobefore)
        }
        return try await fetchReport(for: source, after: afterDate, before: beforeDate)
    }
}

struct SourceListView: View {
    @StateObject private var model = BiasModel()
    
    var body: some View {
        NavigationStack {
            Form {
                ForEach(model.sources, id: \.self) { source in
                    NavigationLink(destination: ReportListView(model: model, source: source)) {
                        Text(source)
                    }
                }
            }
            .navigationTitle(Text("Bias Sources"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    NavigationLink(destination: SourceListSettingsView()) {
                        Image(systemName: "info.circle")
                    }
                }
            }
        }
        .onAppear() {
            Task {
                do {
                    let reply = try await model.fetchSources()
                    model.sources = reply.data
                } catch {
                    print("Error fetching sources: \(error)")
                }
            }
        }
        .refreshable {
            Task {
                do {
                    let reply = try await model.fetchSources()
                    model.sources = reply.data
                } catch {
                    print("Error fetching sources: \(error)")
                }
            }
        }
    }
}

struct ContentView: View {
    var body: some View {
        SourceListView()
    }
}

#Preview {
    ContentView()
}
