import SwiftUI
import VideoToolbox

struct ContentView: View {
    @State private var width = 1920
    @State private var height = 1080
    @State private var encoders: [VideoEncoder] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            List {
                Section("Resolution") {
                    HStack {
                        Text("Width")
                        Spacer()
                        TextField("Width", value: $width, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        Text("Height")
                        Spacer()
                        TextField("Height", value: $height, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button("Refresh") {
                        loadEncoders()
                    }
                    .disabled(isLoading)
                }

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
        guard width > 0, height > 0 else {
            return
        }

        isLoading = true

        let requestedWidth = Int32(width)
        let requestedHeight = Int32(height)

        Task.detached {
            let result = VideoToolboxInspector.inspect(
                width: requestedWidth,
                height: requestedHeight
            )

            await MainActor.run {
                encoders = result
                isLoading = false
            }
        }
    }
}

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

enum VideoToolboxInspector {
    static func inspect(width: Int32, height: Int32) -> [VideoEncoder] {
        var encoderList: CFArray?

        guard VTCopyVideoEncoderList(nil, &encoderList) == noErr,
              let encoderList
        else {
            return []
        }

        let encoders = encoderList as NSArray

        return encoders.compactMap { object in
            guard let dictionary = object as? NSDictionary,
                  let codecType = dictionary.object(
                    forKey: kVTVideoEncoderList_CodecType
                  ) as? NSNumber,
                  let encoderID = dictionary.object(
                    forKey: kVTVideoEncoderList_EncoderID
                  ) as? String
            else {
                return nil
            }

            let codecName = dictionary.object(
                forKey: kVTVideoEncoderList_CodecName
            ) as? String ?? "Unknown"

            let displayName = dictionary.object(
                forKey: kVTVideoEncoderList_DisplayName
            ) as? String ?? "Unknown"

            let isHardwareAccelerated = (dictionary.object(
                forKey: kVTVideoEncoderList_IsHardwareAccelerated
            ) as? NSNumber)?.boolValue ?? false

            let properties = inspectProperties(
                width: width,
                height: height,
                codecType: CMVideoCodecType(codecType.uint32Value),
                encoderID: encoderID
            )

            return VideoEncoder(
                codecName: codecName,
                displayName: displayName,
                encoderID: encoderID,
                codecType: codecType.uint32Value,
                isHardwareAccelerated: isHardwareAccelerated,
                properties: properties
            )
        }
    }

    private static func inspectProperties(
        width: Int32,
        height: Int32,
        codecType: CMVideoCodecType,
        encoderID: String
    ) -> [VideoEncoderProperty] {
        let encoderSpecification: CFDictionary = [
            kVTVideoEncoderSpecification_EncoderID as String: encoderID
        ] as CFDictionary

        var selectedEncoderID: CFString?
        var supportedProperties: CFDictionary?

        let status = VTCopySupportedPropertyDictionaryForEncoder(
            width: width,
            height: height,
            codecType: codecType,
            encoderSpecification: encoderSpecification,
            encoderIDOut: &selectedEncoderID,
            supportedPropertiesOut: &supportedProperties
        )

        guard status == noErr, let supportedProperties else {
            return [
                VideoEncoderProperty(
                    key: "Error",
                    details: "OSStatus: \(status)"
                )
            ]
        }

        let properties = supportedProperties as NSDictionary

        return properties.allKeys
            .compactMap { key in
                guard let key = key as? String else {
                    return nil
                }

                let value = properties.object(forKey: key) as Any
                return VideoEncoderProperty(
                    key: key,
                    details: describeProperty(value)
                )
            }
            .sorted {
                $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending
            }
    }

    private static func describeProperty(_ value: Any) -> String {
        guard let property = value as? NSDictionary else {
            return String(describing: value)
        }

        var lines: [String] = []

        if let type = property.object(forKey: kVTPropertyTypeKey) {
            lines.append("Type: \(type)")
        }

        if let readWriteStatus = property.object(forKey: kVTPropertyReadWriteStatusKey) {
            lines.append("Read/write: \(readWriteStatus)")
        }

        if let minimum = property.object(forKey: kVTPropertySupportedValueMinimumKey) {
            lines.append("Minimum: \(minimum)")
        }

        if let maximum = property.object(forKey: kVTPropertySupportedValueMaximumKey) {
            lines.append("Maximum: \(maximum)")
        }

        if let values = property.object(forKey: kVTPropertySupportedValueListKey) {
            lines.append("Values: \(values)")
        }

        if let documentation = property.object(forKey: kVTPropertyDocumentationKey) {
            lines.append("Documentation: \(documentation)")
        }

        return lines.isEmpty ? String(describing: value) : lines.joined(separator: "\n")
    }
}
