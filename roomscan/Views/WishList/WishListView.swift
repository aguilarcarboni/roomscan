//
//  WishListView.swift
//  storage
//
//  Created by Andrés on 28/6/2025.
//

import SwiftUI
import SwiftData

struct WishListView: View {
    let wishListItems: [WishListItem]
    @Environment(\.modelContext) private var modelContext
    @State private var showingCreateItem = false
    @State private var searchText = ""
    
    // Computed property to filter items based on search text
    private var filteredItems: [WishListItem] {
        if searchText.isEmpty {
            return wishListItems
        } else {
            return wishListItems.filter { item in
                item.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if wishListItems.isEmpty {
                    // Empty state
                    ContentUnavailableView(
                        "No Wish List Items",
                        systemImage: "heart",
                        description: Text("Add items to your wish list or import from CSV")
                    )
                } else if filteredItems.isEmpty && !searchText.isEmpty {
                    // No search results
                    ContentUnavailableView.search
                } else {
                    VStack(spacing: 0) {
                        List {
                            ForEach(filteredItems) { item in
                                WishListItemView(item: item)
                            }
                            .onDelete(perform: deleteItems)
                            Text("Total items: \(filteredItems.count)" + (!searchText.isEmpty ? " of \(wishListItems.count)" : ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        }
                    }
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("Wish List")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateItem = true
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateItem) {
            CreateWishListItemView()
        }
    }
    
    // MARK: - Delete Functions
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let item = filteredItems[index]
                modelContext.delete(item)
            }
            
            do {
                try modelContext.save()
            } catch {
                print("Failed to delete items: \(error)")
            }
        }
    }
}
