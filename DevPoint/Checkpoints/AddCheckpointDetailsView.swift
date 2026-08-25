//
//  AddCheckpointDetailsView.swift
//  DevPoint
//
//  Created by mitz on 24/8/26.
//

import SwiftUI

struct AddCheckpointDetailsView: View {
    @Binding var name: String
    @Binding var urlString: String

    let isLoading: Bool
    let requestError: String?
    let normalizedURL: URL?
    let onMakeRequest: () -> Void

    @State private var showBrowser = false

    private var canMakeRequest: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && normalizedURL != nil
    }

    var body: some View {
        Form {
            detailsSection
            actionsSection

            if let requestError {
                Section {
                    Label(requestError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.subheadline)
                }
            }
        }
        .sheet(isPresented: $showBrowser) {
            if let normalizedURL {
                InAppBrowserView(url: normalizedURL)
            }
        }
    }

    private var detailsSection: some View {
        Section {
            TextField("Name", text: $name)
                .textInputAutocapitalization(.words)

            TextField("https://example.com", text: $urlString)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text("Checkpoint Details")
        } footer: {
            Text("Enter a name and URL, then open the site or fetch a live response to use as the baseline.")
        }
    }

    private var actionsSection: some View {
        Section {
            Button {
                showBrowser = true
            } label: {
                Label("Visit Website", systemImage: "safari")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .disabled(normalizedURL == nil)

            Button(action: onMakeRequest) {
                if isLoading {
                    HStack {
                        ProgressView()
                        Text("Requesting…")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Label("Make Request to Website", systemImage: "arrow.up.arrow.down")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .disabled(!canMakeRequest || isLoading)
        }
    }
}

#Preview {
    NavigationStack {
        AddCheckpointDetailsView(
            name: .constant("Example"),
            urlString: .constant("https://example.com"),
            isLoading: false,
            requestError: nil,
            normalizedURL: URL(string: "https://example.com"),
            onMakeRequest: {}
        )
        .navigationTitle("New Checkpoint")
    }
}
