import SwiftUI
import SwiftData

/// A fast, dateless list for groceries and errands — reached from the
/// cart button on the Tasks tab. Type, return, repeat; tick things off in
/// the shop; "Clear" empties the basket afterwards.
struct ShoppingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShoppingItem.createdAt) private var items: [ShoppingItem]
    @State private var newItemName = ""
    @FocusState private var addFieldFocused: Bool

    private var toBuy: [ShoppingItem] { items.filter { !$0.isChecked } }
    private var inBasket: [ShoppingItem] { items.filter(\.isChecked) }

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.secondary)
                    TextField("Add an item", text: $newItemName)
                        .focused($addFieldFocused)
                        .onSubmit(addItem)
                        .submitLabel(.done)
                }
            }

            if !toBuy.isEmpty {
                Section("To buy") {
                    ForEach(toBuy) { item in
                        itemRow(item)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            modelContext.delete(toBuy[index])
                        }
                    }
                }
            }

            if !inBasket.isEmpty {
                Section {
                    ForEach(inBasket) { item in
                        itemRow(item)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            modelContext.delete(inBasket[index])
                        }
                    }
                } header: {
                    HStack {
                        Text("In the basket")
                        Spacer()
                        Button("Clear") {
                            withAnimation {
                                for item in inBasket {
                                    modelContext.delete(item)
                                }
                            }
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .monogramWatermark()
        .navigationTitle("Shopping List")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if items.isEmpty {
                ContentUnavailableView("Nothing on the list",
                    systemImage: "cart",
                    description: Text("Add items above — they stay out of your tasks"))
            }
        }
    }

    @ViewBuilder
    private func itemRow(_ item: ShoppingItem) -> some View {
        HStack {
            CompletionToggleButton(isCompleted: item.isChecked,
                                   itemTitle: item.name) {
                withAnimation {
                    item.isChecked.toggle()
                }
            }
            Text(item.name)
                .strikethrough(item.isChecked)
                .foregroundStyle(item.isChecked ? .secondary : .primary)
        }
    }

    private func addItem() {
        let name = newItemName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        modelContext.insert(ShoppingItem(name: name))
        newItemName = ""
        addFieldFocused = true
    }
}
