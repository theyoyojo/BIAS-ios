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

func formatDateRangeLabel(_ after: String, _ before: String) -> String {
    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [.withInternetDateTime] // default ISO8601
    if let isoafter = isoFormatter.date(from: after) {
        if let isobefore = isoFormatter.date(from: before) {
            let afteryear = Calendar.current.component(.year, from: isoafter)
            let aftermonth = Calendar.current.component(.month, from: isoafter)
            let afterday = Calendar.current.component(.day, from: isoafter)
            let beforeyear = Calendar.current.component(.year, from: isobefore)
            let beforemonth = Calendar.current.component(.month, from: isobefore)
            let beforeday = Calendar.current.component(.day, from: isobefore)
            
            if afterday == 1 && beforeday == 1 {
                if aftermonth + 1 == beforemonth || (afteryear + 1 == beforeyear && aftermonth == 12 && beforemonth == 1) {
                    let monthnameformatter = DateFormatter()
                    monthnameformatter.dateFormat = "LLLL"
                    let monthname = monthnameformatter.string(from: isoafter)
                    return "\(monthname) \(afteryear)"
                }
            }
            
        }
    }
    return "From \(after) to \(before)"
}

struct ReportListView: View {
    @ObservedObject var model: BiasModel
    let source: String

    var body: some View {
        Form {
            ForEach(model.selectedSourceReports) { report in
                NavigationLink(destination: ReportView(model: model, source: source, after: report.after, before: report.before, title: formatDateRangeLabel(report.after, report.before))) {
                    Text(formatDateRangeLabel(report.after, report.before))
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
