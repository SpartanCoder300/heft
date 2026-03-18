// iOS 26+ only. No #available guards.

import SwiftUI

/// A bottom sheet presenting a native wheel Picker for precise value selection.
struct WheelPickerSheet: View {
    @Binding var value: Double
    let values: [Double]
    let format: (Double) -> String
    let onDone: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel", action: onCancel)
                    .foregroundStyle(Color.textMuted)
                Spacer()
                Button("Done", action: onDone)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xs)

            Picker("", selection: $value) {
                ForEach(values, id: \.self) { v in
                    Text(format(v)).tag(v)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 180)
        }
    }
}
