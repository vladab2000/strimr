//
//  APIResponse.swift
//  StreamCinema
//
//  Created by Vladimír Bárta on 21.02.2026.
//

/*struct ApiFolderResponse: Decodable {
    let requested: ApiRequestedInfo
    let count: Int
    let items: [any MediaItem]
    
    enum CodingKeys: String, CodingKey {
        case requested
        case count
        case items
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.requested = try container.decode(ApiRequestedInfo.self, forKey: .requested)
        self.count = try container.decode(Int.self, forKey: .count)
        
        // Dekóduj raw dictionaries a transformuj je na správné typy
        var itemsArray: [any MediaItem] = []
        var itemsContainer = try container.nestedUnkeyedContainer(forKey: .items)
        
        while !itemsContainer.isAtEnd {
            let item = try itemsContainer.decode([String: AnyCodable].self)
            
            if let type = item["type"]?.value as? String {
                switch type {
                case "video":
                    let video = try Video(from: decoder)
                    itemsArray.append(video)
                case "folder":
                    let folder = try Folder(from: decoder)
                    itemsArray.append(folder)
                case "stream":
                    let stream = try Stream(from: decoder)
                    itemsArray.append(stream)
                default:
                    break
                }
            }
        }
        
        self.items = itemsArray
    }
}*/


struct ApiFolderResponse: Decodable {
    let requested: ApiRequestedInfo
    let count: Int
    let items: [any MediaItem]
    
    enum CodingKeys: String, CodingKey {
        case requested
        case count
        case items
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.requested = try container.decode(ApiRequestedInfo.self, forKey: .requested)
        self.count = try container.decode(Int.self, forKey: .count)
        
        var items: [any MediaItem] = []
        var itemsContainer = try container.nestedUnkeyedContainer(forKey: .items)
        
        while !itemsContainer.isAtEnd {
            let itemDecoder = try itemsContainer.superDecoder()
            
            // Dekóduj jen type bez volání self
            let typeWrapper = try TypeWrapper(from: itemDecoder)
            
            switch typeWrapper.type {
            case "video":
                items.append(try Video(from: itemDecoder))
            case "tvshow":
                items.append(try TvShow(from: itemDecoder))
            case "season":
                items.append(try Season(from: itemDecoder))
            case "episode":
                items.append(try Episode(from: itemDecoder))
            case "folder":
                items.append(try Folder(from: itemDecoder))
            case "stream":
                items.append(try Stream(from: itemDecoder))
            default:
                break
            }
        }
        
        self.items = items
    }
    
    private struct TypeWrapper: Decodable {
        let type: String
    }
}
