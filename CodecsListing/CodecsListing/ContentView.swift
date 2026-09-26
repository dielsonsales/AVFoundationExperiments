import SwiftUI

struct ContentView: View {
	@State private var encoders: [VideoEncoder] = []
	@State private var isLoading = false

	var body: some View {
		NavigationStack {
			List {
				Section("Encoders") {
					if isLoading {
						ProgressView()
					} else if encoders.isEmpty {
						Text("No encoders found.")
							.foregroundStyle(.secondary)
					} else {
						ForEach(encoders) { encoder in
							DisclosureGroup {
								ForEach(encoder.properties) { property in
									VStack(alignment: .leading, spacing: 4) {
										Text(property.key)
											.font(.headline)

										Text(property.details)
											.font(.caption)
											.foregroundStyle(.secondary)
											.textSelection(.enabled)
									}
									.padding(.vertical, 4)
								}
							} label: {
								VStack(alignment: .leading, spacing: 4) {
									Text(encoder.codecName)
										.font(.headline)

									Text(encoder.displayName)
										.foregroundStyle(.secondary)

									HStack {
										Text(encoder.encoderID)

										Spacer()

										if encoder.isHardwareAccelerated {
											Text("Hardware")
												.foregroundStyle(.green)
										}

										Text("\(encoder.properties.count) properties")
											.foregroundStyle(.secondary)
									}
									.font(.caption)
								}
							}
						}
					}
				}
			}
			.navigationTitle("VideoToolbox")
			.task {
				loadEncoders()
			}
		}
	}

	private func loadEncoders() {
		isLoading = true

		Task.detached {
			let result = await VideoToolboxInspector.inspect(
				width: 1920,
				height: 1080
			)
			await MainActor.run {
				encoders = result
				isLoading = false
			}
		}
	}
}
