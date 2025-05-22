import UIKit
import UniformTypeIdentifiers

class USDZDocument: UIDocument {
    
    var usdzData: Data?
    
    override func contents(forType typeName: String) throws -> Any {
        // Encode your document with an instance of NSData or NSFileWrapper
        guard let data = usdzData else { 
            // If you want to create an empty document or a default one
            // you can return an empty Data() or data for a default USDZ file.
            // For now, we'll throw an error if data is nil.
            throw CocoaError(.fileReadCorruptFile) 
        }
        return data
    }
    
    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        // Load your document from contents
        guard let data = contents as? Data else {
            // This is a serious error, an invalid data type was provided.
            throw CocoaError(.fileReadCorruptFile) 
        }
        usdzData = data
        // You would typically trigger a UI update here if the document is displayed
    }
    
    // Example of how you might save changes if your app modifies USDZ files
    func updateUSDZData(newData: Data) {
        usdzData = newData
        // Notify the document that it has changed so it can be saved.
        self.updateChangeCount(.done)
    }
}
