import Foundation

/// Cache mémoire des petites valeurs JSON persistées par SwiftData.
///
/// La donnée brute reste la source de vérité. Une entrée n'est réutilisée que
/// lorsque les octets ayant servi à la produire sont strictement identiques.
/// Une modification directe des `Data` invalide donc automatiquement le cache.
final class JSONDecodingCache: @unchecked Sendable {
    static let shared = JSONDecodingCache()

    private final class Entry {
        let source: Data
        let value: Any

        init(source: Data, value: Any) {
            self.source = source
            self.value = value
        }
    }

    private let entries = NSCache<NSString, Entry>()

    private init() {
        entries.countLimit = 512
    }

    func decode<Value: Decodable>(
        _ type: Value.Type,
        namespace: String,
        ownerID: UUID,
        field: String,
        from data: Data
    ) -> Value? {
        let key = cacheKey(
            namespace: namespace,
            ownerID: ownerID,
            field: field
        )

        if let entry = entries.object(forKey: key),
           entry.source == data,
           let value = entry.value as? Value {
            return value
        }

        guard let value = try? JSONDecoder().decode(type, from: data) else {
            entries.removeObject(forKey: key)
            return nil
        }

        entries.setObject(
            Entry(source: data, value: value),
            forKey: key,
            cost: data.count
        )
        return value
    }

    func store<Value>(
        _ value: Value,
        namespace: String,
        ownerID: UUID,
        field: String,
        source: Data
    ) {
        entries.setObject(
            Entry(source: source, value: value),
            forKey: cacheKey(
                namespace: namespace,
                ownerID: ownerID,
                field: field
            ),
            cost: source.count
        )
    }

    private func cacheKey(
        namespace: String,
        ownerID: UUID,
        field: String
    ) -> NSString {
        "\(namespace).\(ownerID.uuidString).\(field)" as NSString
    }
}
