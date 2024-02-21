//
//  VieController.swift
//  eularity-takehome
//
//  Created by Kedan Zha on 2/20/24.
//

import UIKit

class ViewController: UIViewController, UISearchBarDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    var scrollView: UIScrollView!
    var searchBar: UISearchBar!
    var imageViews: [UIImageView] = []
    var overlayImageView: UIImageView!
    // Data model
    var images: [ImageModel] = []
    var filteredImages: [ImageModel] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        fetchImages()
        
        // Initialize the overlayImageView
        overlayImageView = UIImageView(frame: view.bounds) // Adjust frame as necessary
        overlayImageView.contentMode = .scaleAspectFit
        view.addSubview(overlayImageView)
        overlayImageView.isHidden = true // Hide it initially
    }
    
    func setupUI() {
        do {
            view.backgroundColor = .white
            
            // Search bar setup
            searchBar = UISearchBar(frame: .zero)
            searchBar.translatesAutoresizingMaskIntoConstraints = false
            searchBar.delegate = self
            view.addSubview(searchBar)
            
            // Scroll view setup
            scrollView = UIScrollView(frame: .zero)
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(scrollView)
            
            // Activate constraints
            try activateConstraints()
        } catch {
            print("Error setting up UI: \(error)")
        }
    }
    
    private func activateConstraints() throws {
        guard let searchBar = searchBar, let scrollView = scrollView else {
            throw SetupError.missingComponent
        }
        
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            scrollView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    enum SetupError: Error {
        case missingComponent
    }
    
    
    func fetchImages() {
        NetworkService().fetchImages { [weak self] result in
            switch result {
            case .success(let images):
                DispatchQueue.main.async {
                    self?.images = images
                    self?.filteredImages = images
                    self?.displayImages()
                    print("Images fetched successfully, count: \(images.count)")
                    print("Filtered images count: \(self?.filteredImages.count ?? 0)")
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    // Optionally, present a more detailed failure message based on the error type
                    print("Error fetching images: \(error)")
                    // Here you may also update your UI to reflect the loading error
                    // E.g., Display a label with an error message or show default/placeholder images
                }
            }
        }
    }
    
    
    
    func displayImages() {
        let imageWidth: CGFloat = view.frame.width - 40
        let imageHeight: CGFloat = 200
        var yOffset: CGFloat = 10
        
        for imageView in imageViews {
            imageView.removeFromSuperview()
        }
        
        imageViews.removeAll()
        
        for (index, imageModel) in filteredImages.enumerated() {
            let imageView = UIImageView(frame: CGRect(x: 20, y: yOffset, width: imageWidth, height: imageHeight))
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.tag = index
            imageView.isUserInteractionEnabled = true
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(imageTapped(_:)))
            imageView.addGestureRecognizer(tapGesture)
            
            if let url = URL(string: imageModel.imageUrl) {
                loadImage(from: url, into: imageView)
            }
            
            scrollView.addSubview(imageView)
            imageViews.append(imageView)
            
            yOffset += imageHeight + 10
        }
        
        scrollView.contentSize = CGSize(width: view.frame.width, height: yOffset)
    }
    
//    @objc func imageTapped(_ sender: UITapGestureRecognizer) {
//        guard let imageView = sender.view as? UIImageView, let image = imageView.image else {
//            print("ImageView does not contain an image")
//            return
//        }
//        
//        let alert = UIAlertController(title: "Save Image", message: "Do you want to save this image?", preferredStyle: .alert)
//        alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { [weak self] _ in
//            self?.saveImageLocally(image: image, completion: { (success) in
//                if success {
//                    print("Image saved successfully")
//                } else {
//                    print("Failed to save image")
//                }
//            })
//            self?.saveImageToServer(image: image, imageView: imageView)
//        }))
//        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
//        
//        present(alert, animated: true, completion: nil)
//    }
    @objc func imageTapped(_ sender: UITapGestureRecognizer) {
        guard let imageView = sender.view as? UIImageView,
              let image = imageView.image,
              let imageIndex = imageView.tag < filteredImages.count ? imageView.tag : nil else {
            print("ImageView does not contain an image or index out of bounds")
            return
        }
        
        let imageModel = filteredImages[imageIndex]
        showDetailOverlay(for: imageModel, withImage: image)
    }
    
    func loadImage(from url: URL, into imageView: UIImageView) {
        print("Loading image from URL: \(url)")
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error loading image from URL \(url): \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("No data received for URL \(url)")
                return
            }
            print("Received data size: \(data.count)")
            
            guard let image = UIImage(data: data) else {
                print("Failed to create UIImage from data for URL \(url)")
                return
            }
            
            DispatchQueue.main.async {
                print("Image loaded successfully for URL \(url)")
                imageView.image = image
            }
        }
        
        task.resume()
    }
    
    
    
}

extension ViewController {
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // Check if the searchText is empty or not
        if searchText.isEmpty {
            filteredImages = images // If empty, show all images
        } else {
            // Filter images based on the search text
            filteredImages = images.filter { image in
                // Lowercase search to make it case-insensitive
                return image.title.lowercased().contains(searchText.lowercased()) ||
                image.description.lowercased().contains(searchText.lowercased())
            }
        }
        
        // Refresh the UI with the filtered images
        displayImages()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = "" // Clear search bar text
        searchBar.resignFirstResponder() // Dismiss the keyboard
        
        filteredImages = images // Reset to original list
        displayImages() // Refresh the UI
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder() // Dismiss the keyboard when the search button is clicked
    }
}

extension ViewController {
    func saveImageLocally(image: UIImage, completion: @escaping (Bool) -> Void) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
        completion(true)
    }
    
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            // Handle the error case
            print("Error saving image: \(error.localizedDescription)")
            // If using a progress HUD, stop it here with a failure message
        } else {
            print("Image saved successfully")
            // If using a progress HUD, stop it here with a success message
        }
    }
    func saveImageToServer(image: UIImage, imageView: UIImageView) {
        // Assuming networkService is an instance of NetworkService you've created earlier.
        let networkService = NetworkService()
        let originalImageURL = filteredImages[imageView.tag].imageUrl
        //save image file locally to repository under directory called "images"
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent("images/\(UUID().uuidString).png")
        if let data = image.pngData() {
            do {
                try data.write(to: fileURL)
                print("Image saved locally: \(fileURL)")
            } catch {
                print("Failed to save image locally: \(error)")
            }
        }
        networkService.getUploadUrl { [weak self] result in
            switch result {
            case .success(let uploadUrl):
                networkService.uploadImage(image: image, to: uploadUrl, appID: "kz2028@nyu.edu", originalImageURL: originalImageURL) { uploadResult in
                    DispatchQueue.main.async {
                        switch uploadResult {
                        case .success(_):
                            print("Image uploaded successfully originalImageURL: \(originalImageURL)")
                        case .failure(let error):
                            print("Failed to upload image: \(error)")
                        }
                    }
                }
            case .failure(let error):
                print("Failed to get upload URL: \(error)")
            }
        }
    }

    
}
extension ViewController {
    //show detail overlay
    func showDetailOverlay(for imageModel: ImageModel, withImage image: UIImage) {
        let detailView = UIView(frame: view.bounds)
        detailView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = detailView.bounds
        detailView.addSubview(blurView)
        
        // Image View
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.frame = CGRect(x: 20, y: 100, width: detailView.frame.width - 40, height: 200)
        blurView.contentView.addSubview(imageView)
        
        // Title Label
        let titleLabel = UILabel(frame: CGRect(x: 20, y: 310, width: detailView.frame.width - 40, height: 20))
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.text = "Title: \(imageModel.title)"
        blurView.contentView.addSubview(titleLabel)
        
        // Description Label
        let descriptionLabel = UILabel(frame: CGRect(x: 20, y: 340, width: detailView.frame.width - 40, height: 20))
        descriptionLabel.textColor = .white
        descriptionLabel.textAlignment = .center
        descriptionLabel.text = "Description: \(imageModel.description)"
        blurView.contentView.addSubview(descriptionLabel)
        
        // Creation Date Label
        let dateLabel = UILabel(frame: CGRect(x: 20, y: 370, width: detailView.frame.width - 40, height: 20))
        dateLabel.textColor = .white
        dateLabel.textAlignment = .center
        dateLabel.text = "Created: \(imageModel.created)"
        blurView.contentView.addSubview(dateLabel)
        
        // Save Button
        let saveButton = UIButton(type: .system)
        saveButton.frame = CGRect(x: 100, y: detailView.frame.height - 100, width: detailView.frame.width - 200, height: 44)
        saveButton.setTitle("Save", for: .normal)
        saveButton.addTarget(self, action: #selector(saveButtonTapped(_:)), for: .touchUpInside)
        saveButton.backgroundColor = .systemBlue
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = 22
        blurView.contentView.addSubview(saveButton)
        
        // Close Button
        let closeButton = UIButton(type: .system)
        closeButton.frame = CGRect(x: detailView.frame.width - 60, y: 30, width: 30, height: 30)
        closeButton.setTitle("X", for: .normal)
        closeButton.addTarget(self, action: #selector(closeButtonTapped(_:)), for: .touchUpInside)
        closeButton.backgroundColor = .clear
        closeButton.setTitleColor(.white, for: .normal)
        blurView.contentView.addSubview(closeButton)
        
        // Tag the detailView for later removal
        detailView.tag = 999
        view.addSubview(detailView)
    }
    //save button tapped callback
    @objc func saveButtonTapped(_ sender: UIButton) {
        guard let detailView = view.viewWithTag(999),
              let imageView = detailView.subviews.compactMap({ $0 as? UIImageView }).first,
              let image = imageView.image else {
            return
        }
        
        saveImageLocally(image: image, completion: { (success) in
            if success {
                print("Image saved successfully")
            } else {
                print("Failed to save image")
            }
        })
        detailView.removeFromSuperview()
    }

    @objc func closeButtonTapped(_ sender: UIButton) {
        view.viewWithTag(999)?.removeFromSuperview()
    }

}
