import SwiftUI

struct UrgentBannerView: View {
    @Bindable var task: TaskItem

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
            VStack(alignment: .leading) {
                Text(task.title)
                    .fontWeight(.semibold)
                Text(task.dueDate, format: .dateTime.day().month())
                    .font(.caption)
                    .opacity(0.8)
            }
            Spacer()
            Button {
                withAnimation {
                    task.isCompleted = true
                }
            } label: {
                Image(systemName: "checkmark.circle")
                    .font(.title2)
            }
        }
        .foregroundStyle(.white)
        .padding()
        .background(.red, in: RoundedRectangle(cornerRadius: 14))
    }
}
