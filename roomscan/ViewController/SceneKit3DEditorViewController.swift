import UIKit
import SceneKit
import ModelIO
import SceneKit.ModelIO

class SceneKit3DEditorViewController: UIViewController {
    
    // MARK: - Properties
    private var sceneView: SCNView!
    private var scene: SCNScene!
    private var modelURL: URL!
    private var selectedNode: SCNNode?
    // Simple top toolbar
    private var topToolbar: UIToolbar!
    
    // Camera will be handled by SceneKit's built-in controls
    private var cameraNode: SCNNode!
    
    // Only tap gesture for selection
    private var tapGesture: UITapGestureRecognizer!
    
    // Lighting nodes
    private var ambientLightNode: SCNNode!
    private var directionalLightNode: SCNNode!
    
    // Grid and reference system
    private var gridNode: SCNNode?
    private var showGrid = true
    
    // Model manipulation
    private var originalModelTransform: SCNMatrix4 = SCNMatrix4Identity
    
    // Callback for dismissal
    var onDismiss: (() -> Void)?
    
    // MARK: - Initialization
    init(modelURL: URL) {
        self.modelURL = modelURL
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Make view fullscreen
        modalPresentationStyle = .fullScreen
        
        setupSceneView()
        setupScene()
        setupCamera()
        setupLighting()
        setupGrid()
                setupTopBar()
        setupTapGesture()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadModel()
    }
    
    // MARK: - Setup Methods
    private func setupSceneView() {
        // Make the view fullscreen
        sceneView = SCNView(frame: view.bounds)
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sceneView.backgroundColor = UIColor.black
        sceneView.allowsCameraControl = true // Use built-in SceneKit camera controls
        sceneView.showsStatistics = true
        sceneView.debugOptions = []
        view.addSubview(sceneView)
        

    }
    
    private func setupScene() {
        scene = SCNScene()
        sceneView.scene = scene
        
        // Enable physics for potential interactions
        scene.physicsWorld.gravity = SCNVector3(0, -9.8, 0)
    }
    
    private func setupCamera() {
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 100
        
        // Set initial camera position (SceneKit will handle controls from here)
        cameraNode.position = SCNVector3(0, 2, 5)
        
        scene.rootNode.addChildNode(cameraNode)
        sceneView.pointOfView = cameraNode
    }
    
    private func setupLighting() {
        // Ambient light
        ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light?.type = .ambient
        ambientLightNode.light?.color = UIColor.white
        ambientLightNode.light?.intensity = 200
        scene.rootNode.addChildNode(ambientLightNode)
        
        // Directional light
        directionalLightNode = SCNNode()
        directionalLightNode.light = SCNLight()
        directionalLightNode.light?.type = .directional
        directionalLightNode.light?.color = UIColor.white
        directionalLightNode.light?.intensity = 800
        directionalLightNode.position = SCNVector3(2, 2, 2)
        directionalLightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(directionalLightNode)
        
        // Add a subtle fill light
        let fillLightNode = SCNNode()
        fillLightNode.light = SCNLight()
        fillLightNode.light?.type = .directional
        fillLightNode.light?.color = UIColor.white
        fillLightNode.light?.intensity = 300
        fillLightNode.position = SCNVector3(-2, 1, 1)
        fillLightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(fillLightNode)
    }
    
    private func setupGrid() {
        createGrid()
    }
    
    private func createGrid() {
        // Grid is now disabled - no ground plane or grid lines
        gridNode = SCNNode()
        scene.rootNode.addChildNode(gridNode!)
    }
    
    private func setupTopBar() {
        // Create a simple top toolbar with liquid glass effect
        topToolbar = UIToolbar()
        topToolbar.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure with liquid glass appearance
        let appearance = UIToolbarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor.clear
        
        topToolbar.standardAppearance = appearance
        topToolbar.compactAppearance = appearance
        topToolbar.scrollEdgeAppearance = appearance
        
        view.addSubview(topToolbar)
        
        // Create Done button
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissEditor))
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        topToolbar.items = [flexSpace, doneButton]
        
        // Constraints
        NSLayoutConstraint.activate([
            topToolbar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    

    
    // MARK: - Model Loading
    private func loadModel() {
        guard let modelURL = modelURL else {
            print("❌ No model URL provided")
            return
        }
        
        print("🔄 Loading USDZ model from: \(modelURL.absoluteString)")
        
        // Ensure we can access the file
        guard modelURL.startAccessingSecurityScopedResource() else {
            print("❌ Cannot access security scoped resource")
            showErrorAlert(message: "Cannot access the selected file. Please try again.")
            return
        }
        
        defer {
            modelURL.stopAccessingSecurityScopedResource()
        }
        
        do {
            // Load the USDZ model using ModelIO and SceneKit
            let asset = MDLAsset(url: modelURL)
            
            // Convert to SceneKit scene
            let loadedScene = SCNScene(mdlAsset: asset)
            
            // Add the loaded model to our scene
            for child in loadedScene.rootNode.childNodes {
                
                // Store original transform
                originalModelTransform = child.transform
                
                // Add to scene
                scene.rootNode.addChildNode(child)
                
                // Center and scale the model appropriately
                centerAndScaleModel(child)
            }
            
            print("✅ Successfully loaded USDZ model")
            
        } catch {
            print("❌ Error loading USDZ model: \(error.localizedDescription)")
            showErrorAlert(message: "Failed to load the 3D model: \(error.localizedDescription)")
        }
    }
    
    private func centerAndScaleModel(_ node: SCNNode) {
        // Get the bounding box of the model
        let (min, max) = node.boundingBox
        let center = SCNVector3(
            (min.x + max.x) / 2,
            (min.y + max.y) / 2,
            (min.z + max.z) / 2
        )
        
        // Position the model on top of the ground plane with padding
        // Center it horizontally (X,Z) and lift it above ground level
        let groundPadding: Float = 0.1 // Small padding above ground
        node.position = SCNVector3(-center.x, -min.y + groundPadding, -center.z)
        
        // With built-in camera controls, just position the camera to look at the model
        let modelHeight = max.y - min.y
        let modelCenter = SCNVector3(0, modelHeight / 2 + groundPadding, 0)
        
        // Position camera to look at the model center
        cameraNode.position = SCNVector3(0, modelCenter.y, 5)
        cameraNode.look(at: modelCenter)
        
        // Calculate the model's size
        let size = SCNVector3(
            max.x - min.x,
            max.y - min.y,
            max.z - min.z
        )
        let maxDimension = Swift.max(size.x, Swift.max(size.y, size.z))
        
        // Scale the model to fit within a reasonable size (e.g., 2 units)
        let targetSize: Float = 2.0
        if maxDimension > targetSize {
            let scale = targetSize / maxDimension
            node.scale = SCNVector3(scale, scale, scale)
        }
        
        // SceneKit's built-in camera controls will handle the rest automatically
    }
    
    // MARK: - Gesture Setup (only for selection)
    private func setupTapGesture() {
        // Tap gesture for selection
        tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        sceneView.addGestureRecognizer(tapGesture)
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: sceneView)
        let hitResults = sceneView.hitTest(location, options: nil)
        
        if let hitResult = hitResults.first {
            selectNode(hitResult.node)
        } else {
            deselectNode()
        }
    }
    

    
    // MARK: - Selection Management
    private func selectNode(_ node: SCNNode) {
        // Deselect previous
        deselectNode()
        
        // Select new node
        selectedNode = node
        highlightSelectedNode()
        
        print("Selected node: \(node.name ?? "unnamed")")
    }
    
    private func deselectNode() {
        if let selectedNode = selectedNode {
            removeHighlight(from: selectedNode)
        }
        selectedNode = nil
    }
    
    private func highlightSelectedNode() {
        guard let selectedNode = selectedNode else { return }
        
        // Add a wireframe overlay to show selection
        let (min, max) = selectedNode.boundingBox
        let boundingBoxGeometry = SCNBox(
            width: CGFloat(max.x - min.x),
            height: CGFloat(max.y - min.y),
            length: CGFloat(max.z - min.z),
            chamferRadius: 0
        )
        
        let wireframeMaterial = SCNMaterial()
        wireframeMaterial.fillMode = .lines
        wireframeMaterial.diffuse.contents = UIColor.systemBlue
        boundingBoxGeometry.materials = [wireframeMaterial]
        
        let wireframeNode = SCNNode(geometry: boundingBoxGeometry)
        wireframeNode.name = "selectionWireframe"
        selectedNode.addChildNode(wireframeNode)
    }
    
    private func removeHighlight(from node: SCNNode) {
        node.childNodes.first { $0.name == "selectionWireframe" }?.removeFromParentNode()
    }
    
    // MARK: - Menu Actions
    @objc private func dismissEditor() {
        onDismiss?()
        dismiss(animated: true)
    }
    

    

    
    // MARK: - Utility Methods
    
    private func showErrorAlert(message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
} 
