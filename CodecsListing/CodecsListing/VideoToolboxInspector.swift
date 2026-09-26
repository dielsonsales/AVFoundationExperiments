import VideoToolbox

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
