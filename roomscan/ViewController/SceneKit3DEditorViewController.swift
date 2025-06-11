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
    private var toolbar: UIToolbar!
    private var topToolbar: UIToolbar!
    
    // Camera control
    private var cameraNode: SCNNode!
    private var defaultCameraPosition = SCNVector3(0, 2, 5)
    
    // Gesture recognizers
    private var panGesture: UIPanGestureRecognizer!
    private var pinchGesture: UIPinchGestureRecognizer!
    private var rotationGesture: UIRotationGestureRecognizer!
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
        setupSceneView()
        setupScene()
        setupCamera()
        setupLighting()
        setupGrid()
        setupToolbars()
        setupGestures()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadModel()
    }
    
    // MARK: - Setup Methods
    private func setupSceneView() {
        sceneView = SCNView(frame: view.bounds)
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sceneView.backgroundColor = UIColor.darkGray
        sceneView.allowsCameraControl = false // We'll handle camera control manually
        sceneView.showsStatistics = true
        sceneView.debugOptions = [.showWireframe]
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
        cameraNode.position = defaultCameraPosition
        cameraNode.look(at: SCNVector3(0, 0, 0))
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
        if let gridNode = gridNode {
            gridNode.removeFromParentNode()
        }
        
        let gridNode = SCNNode()
        let gridSize = 10
        let gridSpacing: Float = 1.0
        
        // Create grid lines
        for i in -gridSize...gridSize {
            // Vertical lines (along Z-axis)
            let verticalGeometry = SCNCylinder(radius: 0.005, height: CGFloat(gridSize * 2))
            let verticalNode = SCNNode(geometry: verticalGeometry)
            verticalNode.position = SCNVector3(Float(i) * gridSpacing, 0, 0)
            verticalNode.rotation = SCNVector4(1, 0, 0, Float.pi / 2)
            
            // Horizontal lines (along X-axis)
            let horizontalGeometry = SCNCylinder(radius: 0.005, height: CGFloat(gridSize * 2))
            let horizontalNode = SCNNode(geometry: horizontalGeometry)
            horizontalNode.position = SCNVector3(0, 0, Float(i) * gridSpacing)
            horizontalNode.rotation = SCNVector4(0, 0, 1, Float.pi / 2)
            
            // Style the grid lines
            let gridMaterial = SCNMaterial()
            gridMaterial.diffuse.contents = UIColor.systemGray4.withAlphaComponent(0.3)
            verticalGeometry.materials = [gridMaterial]
            horizontalGeometry.materials = [gridMaterial]
            
            gridNode.addChildNode(verticalNode)
            gridNode.addChildNode(horizontalNode)
        }
        
        // Add a ground plane
        let groundGeometry = SCNPlane(width: CGFloat(gridSize * 2), height: CGFloat(gridSize * 2))
        let groundNode = SCNNode(geometry: groundGeometry)
        groundNode.rotation = SCNVector4(1, 0, 0, -Float.pi / 2)
        groundNode.position.y = -0.01
        
        let groundMaterial = SCNMaterial()
        groundMaterial.diffuse.contents = UIColor.systemGray6.withAlphaComponent(0.1)
        groundGeometry.materials = [groundMaterial]
        
        gridNode.addChildNode(groundNode)
        scene.rootNode.addChildNode(gridNode)
        self.gridNode = gridNode
    }
    
    private func setupToolbars() {
        // Top toolbar
        topToolbar = UIToolbar()
        topToolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topToolbar)
        
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissEditor))
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let resetButton = UIBarButtonItem(title: "Reset View", style: .plain, target: self, action: #selector(resetCameraView))
        let gridButton = UIBarButtonItem(title: "Grid", style: .plain, target: self, action: #selector(toggleGrid))
        let wireframeButton = UIBarButtonItem(title: "Wireframe", style: .plain, target: self, action: #selector(toggleWireframe))
        
        topToolbar.items = [doneButton, flexSpace, gridButton, wireframeButton, resetButton]
        
        // Bottom toolbar
        toolbar = UIToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)
        
        let deleteButton = UIBarButtonItem(title: "🗑️ Delete", style: .plain, target: self, action: #selector(deleteSelected))
        let duplicateButton = UIBarButtonItem(title: "📋 Duplicate", style: .plain, target: self, action: #selector(duplicateSelected))
        let flexSpace2 = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let transformButton = UIBarButtonItem(title: "🔄 Transform", style: .plain, target: self, action: #selector(showTransformOptions))
        
        toolbar.items = [transformButton, flexSpace2, duplicateButton, deleteButton]
        
        // Constraints
        NSLayoutConstraint.activate([
            topToolbar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func setupGestures() {
        // Pan gesture for camera rotation
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.minimumNumberOfTouches = 1
        panGesture.maximumNumberOfTouches = 1
        sceneView.addGestureRecognizer(panGesture)
        
        // Pinch gesture for camera zoom
        pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        sceneView.addGestureRecognizer(pinchGesture)
        
        // Tap gesture for selection
        tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        sceneView.addGestureRecognizer(tapGesture)
        
        // Two-finger pan for camera panning
        let twoPanGesture = UIPanGestureRecognizer(target: self, action: #selector(handleTwoPan(_:)))
        twoPanGesture.minimumNumberOfTouches = 2
        twoPanGesture.maximumNumberOfTouches = 2
        sceneView.addGestureRecognizer(twoPanGesture)
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
        
        // Center the model
        node.position = SCNVector3(-center.x, -center.y, -center.z)
        
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
    }
    
    // MARK: - Gesture Handlers
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: sceneView)
        
        // Rotate camera around the origin
        let rotationX = Float(translation.y) * 0.01
        let rotationY = Float(translation.x) * 0.01
        
        // Apply rotation to camera
        let currentTransform = cameraNode.transform
        cameraNode.transform = SCNMatrix4Rotate(currentTransform, rotationX, 1, 0, 0)
        cameraNode.transform = SCNMatrix4Rotate(cameraNode.transform, rotationY, 0, 1, 0)
        
        gesture.setTranslation(CGPoint.zero, in: sceneView)
    }
    
    @objc private func handleTwoPan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: sceneView)
        
        // Pan camera
        let panSpeed: Float = 0.01
        let moveVector = SCNVector3(
            -Float(translation.x) * panSpeed,
            Float(translation.y) * panSpeed,
            0
        )
        
        cameraNode.position = SCNVector3(
            cameraNode.position.x + moveVector.x,
            cameraNode.position.y + moveVector.y,
            cameraNode.position.z + moveVector.z
        )
        
        gesture.setTranslation(CGPoint.zero, in: sceneView)
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        let scale = gesture.scale
        let zoomSpeed: Float = 0.1
        
        // Move camera closer or further from origin
        let direction = normalize(cameraNode.position)
        let moveDistance = (1.0 - Float(scale)) * zoomSpeed
        
        cameraNode.position = SCNVector3(
            cameraNode.position.x + direction.x * moveDistance,
            cameraNode.position.y + direction.y * moveDistance,
            cameraNode.position.z + direction.z * moveDistance
        )
        
        gesture.scale = 1.0
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
    
    // MARK: - Toolbar Actions
    @objc private func dismissEditor() {
        onDismiss?()
        dismiss(animated: true)
    }
    
    @objc private func resetCameraView() {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 1.0
        cameraNode.position = defaultCameraPosition
        cameraNode.look(at: SCNVector3(0, 0, 0))
        SCNTransaction.commit()
    }
    
    @objc private func toggleGrid() {
        showGrid.toggle()
        gridNode?.isHidden = !showGrid
    }
    
    @objc private func toggleWireframe() {
        if sceneView.debugOptions.contains(.showWireframe) {
            sceneView.debugOptions.remove(.showWireframe)
        } else {
            sceneView.debugOptions.insert(.showWireframe)
        }
    }
    
    @objc private func deleteSelected() {
        guard let selectedNode = selectedNode else {
            showAlert(title: "No Selection", message: "Please select a node to delete.")
            return
        }
        
        let alert = UIAlertController(title: "Delete Node", message: "Are you sure you want to delete this node?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            selectedNode.removeFromParentNode()
            self.selectedNode = nil
        })
        
        present(alert, animated: true)
    }
    
    @objc private func duplicateSelected() {
        guard let selectedNode = selectedNode else {
            showAlert(title: "No Selection", message: "Please select a node to duplicate.")
            return
        }
        
        let duplicatedNode = selectedNode.clone()
        duplicatedNode.position = SCNVector3(
            selectedNode.position.x + 1,
            selectedNode.position.y,
            selectedNode.position.z + 1
        )
        
        selectedNode.parent?.addChildNode(duplicatedNode)
        selectNode(duplicatedNode)
    }
    
    @objc private func showTransformOptions() {
        guard let selectedNode = selectedNode else {
            showAlert(title: "No Selection", message: "Please select a node to transform.")
            return
        }
        
        let alert = UIAlertController(title: "Transform Node", message: "Choose a transformation", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Reset Position", style: .default) { _ in
            selectedNode.position = SCNVector3(0, 0, 0)
        })
        
        alert.addAction(UIAlertAction(title: "Reset Rotation", style: .default) { _ in
            selectedNode.rotation = SCNVector4(0, 1, 0, 0)
        })
        
        alert.addAction(UIAlertAction(title: "Reset Scale", style: .default) { _ in
            selectedNode.scale = SCNVector3(1, 1, 1)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    // MARK: - Utility Methods
    private func normalize(_ vector: SCNVector3) -> SCNVector3 {
        let length = sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
        if length == 0 { return SCNVector3(0, 0, 1) }
        return SCNVector3(vector.x / length, vector.y / length, vector.z / length)
    }
    
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