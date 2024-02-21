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
    // Data model
    var images: [ImageModel] = []
    var filteredImages: [ImageModel] = []
    
    var selectedImageCache: (image: UIImage, model: ImageModel)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        fetchImages()
        
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
            imageView.layer.cornerRadius = 10
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
        guard let imageView = sender.view as? UIImageView else { return }
        
        let index = imageView.tag
        
        // Determine if a dropdown is already present for this image
        if let existingDropdown = scrollView.viewWithTag(9999) {
            // Determine if we are closing the current dropdown or opening a new one
            let isClosingCurrentDropdown = existingDropdown.frame.origin.y == imageView.frame.maxY
            
            // Remove existing dropdown
            existingDropdown.removeFromSuperview()
            
            // Adjust layout to return subsequent images to their original position if we're closing the current dropdown
            if isClosingCurrentDropdown {
                adjustLayoutForDropdown(showing: false, atIndex: index, dropdownHeight: existingDropdown.frame.height)
            }
            
            // If closing the current dropdown, stop further processing
            if isClosingCurrentDropdown { return }
        }
        
        // If reaching this point, either no dropdown was present or we're opening a new one after closing the existing one
        let imageModel = filteredImages[index]
        createDropdownMenu(for: imageModel, below: imageView, atIndex: index)
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
    func createDropdownMenu(for imageModel: ImageModel, below imageView: UIImageView, atIndex index: Int) {
        // Calculating dropdownHeight dynamically based on content could be more complex
        let dropdownHeight: CGFloat = 120 // Example fixed height, adjust as needed
        let dropdownView = UIView(frame: CGRect(x: imageView.frame.origin.x, y: imageView.frame.maxY, width: imageView.frame.width, height: dropdownHeight))
        dropdownView.backgroundColor = .white
        dropdownView.layer.cornerRadius = 5
        dropdownView.clipsToBounds = true
        dropdownView.tag = 9999 // Unique tag
        
        let titleLabel = UILabel(frame: CGRect(x: 10, y: 5, width: dropdownView.frame.width, height: 20))
        titleLabel.text = "Title: \(imageModel.title)"
        dropdownView.addSubview(titleLabel)
        
        let descriptionLabel = UILabel(frame: CGRect(x: 10, y: 30, width: dropdownView.frame.width, height: 50))
        descriptionLabel.text = "Description: \(imageModel.description)"
        descriptionLabel.numberOfLines = 0
        dropdownView.addSubview(descriptionLabel)
        
        let saveButton = UIButton(frame: CGRect(x: 10, y: 75, width: dropdownView.frame.width - 20, height: 40))
        saveButton.setTitle("Save", for: .normal)
        saveButton.backgroundColor = .systemBlue
        saveButton.addTarget(self, action: #selector(saveButtonTapped(_:)), for: .touchUpInside)
        saveButton.layer.cornerRadius = 5
        dropdownView.addSubview(saveButton)
        
        scrollView.addSubview(dropdownView)
        adjustLayoutForDropdown(showing: true, atIndex: index, dropdownHeight: dropdownHeight)
    }
    
    func adjustLayoutForDropdown(showing: Bool, atIndex index: Int, dropdownHeight: CGFloat) {
        UIView.animate(withDuration: 0.3) {
            var adjustmentHeight = dropdownHeight
            if !showing {
                // If hiding the dropdown, adjust the height negatively
                adjustmentHeight = -dropdownHeight
            }
            
            for i in (index + 1)..<self.imageViews.count {
                let imageView = self.imageViews[i]
                imageView.frame.origin.y += adjustmentHeight
            }
            
            // Adjust scrollView content size based on the showing/hiding of the dropdown
            self.scrollView.contentSize.height += adjustmentHeight
        }
    }

    //save button tapped callback
    @objc func saveButtonTapped(_ sender: UIButton) {
        // Assuming dropdownView is the direct parent of the button, adjust the view hierarchy navigation as needed
        guard let dropdownView = sender.superview?.superview,
              let imageView = scrollView.subviews.first(where: { $0.tag == dropdownView.tag }) as? UIImageView,
              let image = imageView.image else {
            print("Failed to identify the image for saving")
            return
        }
        
        let index = dropdownView.tag - 9999
        // Check if the index is within the bounds of filteredImages
        if index >= 0 && index < filteredImages.count {
            let imageModel = filteredImages[index]
            // Now you have a valid index and imageModel, proceed with your saving logic
            saveImageLocally(image: image, completion: { success in
                if success {
                    print("Image saved successfully")
                } else {
                    print("Failed to save image")
                }
            })
        } else {
            print("Index out of bounds")
        }
    }
    
    
    
}
