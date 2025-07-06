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
                } else {
                    VStack(spacing: 0) {
                        List {
                            ForEach(wishListItems) { item in
                                WishListItemView(item: item)
                            }
                            .onDelete(perform: deleteItems)
                            Text("Total items: \(wishListItems.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        }
                    }
                }
            }
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
                let item = wishListItems[index]
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
