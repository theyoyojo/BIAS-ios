//
//  BiasModel.swift
//  Bias
//
//  Created by Joel Savitz on 8/13/25.
//

import SwiftUI

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

