import Foundation

struct VideoEncoder: Identifiable {
	let id = UUID()
	let codecName: String
	let displayName: String
	let encoderID: String
	let codecType: UInt32
	let isHardwareAccelerated: Bool
	let properties: [VideoEncoderProperty]
}

struct VideoEncoderProperty: Identifiable {
	let id = UUID()
	let key: String
	let details: String
}
