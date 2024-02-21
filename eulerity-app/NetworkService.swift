//
//  NetworkService.swift
//  eularity-takehome
//
//  Created by Kedan Zha on 2/20/24.
//

import Foundation
import UIKit

enum NetworkError: Error {
    case invalidUrl
    case requestFailed(Error)
    case decodingFailed(Error)
    case invalidImageData
    case other(Error)
}

class NetworkService {
    //fetches images from the '/pets' endpoint
    func fetchImages(completion: @escaping (Result<[ImageModel], NetworkError>) -> Void) {
        guard let url = URL(string: "https://eulerity-hackathon.appspot.com/pets") else {
            completion(.failure(.invalidUrl))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(.requestFailed(error)))
                return
            }
            
            guard let data = data else {
                completion(.failure(.invalidImageData))
                return
            }
            
            do {
                let images = try JSONDecoder().decode([ImageModel].self, from: data)
                completion(.success(images))
            } catch {
                completion(.failure(.decodingFailed(error)))
            }
        }.resume()
    }
    //retrives url for uploading image
    func getUploadUrl(completion: @escaping (Result<URL, NetworkError>) -> Void) {
        let urlString = "https://eulerity-hackathon.appspot.com/upload"
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidUrl))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(.requestFailed(error)))
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data, options: []),
                  let dictionary = json as? [String: Any],
                  let uploadUrlString = dictionary["url"] as? String,
                  let uploadUrl = URL(string: uploadUrlString) else {
                completion(.failure(.decodingFailed(NSError(domain: "Invalid JSON", code: 0))))
                return
            }
            
            completion(.success(uploadUrl))
        }.resume()
    }
    
    //uploads image to the server
    func uploadImage(image: UIImage, to uploadUrl: URL, appID: String, originalImageURL: String, completion: @escaping (Result<Bool, NetworkError>) -> Void) {
        var request = URLRequest(url: uploadUrl)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        guard let imageData = image.jpegData(compressionQuality: 0.75) else {
            completion(.failure(.invalidImageData))
            return
        }
        
        var body = Data()
        
        // Add the appID field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"appid\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(appID)\r\n".data(using: .utf8)!)
        
        // Add the originalImageURL field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"original\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(originalImageURL)\r\n".data(using: .utf8)!)
        
        // Add the image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.requestFailed(error)))
                return
            }
            
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                completion(.failure(.requestFailed(NSError(domain: "Invalid response", code: 0))))
                return
            }
            
            completion(.success(true))
        }.resume()
    }
    
}
extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
