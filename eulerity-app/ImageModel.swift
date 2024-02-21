//
//  ImageModel.swift
//  eularity-takehome
//
//  Created by Kedan Zha on 2/20/24.
//

import Foundation

struct ImageModel: Decodable {
    let title: String
    let description: String
    let imageUrl: String
    let created: String


    enum CodingKeys: String, CodingKey {
        case title, description, created
        case imageUrl = "url"
    }
}

