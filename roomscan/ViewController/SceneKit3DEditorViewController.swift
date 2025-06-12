import UIKit
import SceneKit
import ModelIO
import SceneKit.ModelIO

// MARK: - Editor State
enum EditorState {
    case general        // No selection, general tools
    case meshSelected   // Mesh selected, show info and transform tools
    case transforming   // Transform mode, move selected object with gestures
    case rotating      // Rotation mode, rotate selected object with gestures
    case scaling       // Scale mode, scale selected object with gestures
    // Future states can be added here (e.g., .materialEditor, .animationMode, etc.)
}


class SceneKit3DEditorViewController: UIViewController {
    
    // MARK: - Properties
    private var sceneView: SCNView!
    private var scene: SCNScene!
    private var modelURL: URL!
    private var selectedNode: SCNNode?
    // Simple top toolbar
    private var topToolbar: UIToolbar!
    
    // Bottom toolbar for adding items
    private var bottomToolbar: UIToolbar!
    
    // Editor state management
    private var editorState: EditorState = .general {
        didSet {
            updateBottomToolbar()
            updateGesturesAndCamera()
        }
    }
    
    // Camera will be handled by SceneKit's built-in controls
    private var cameraNode: SCNNode!
    
    // Gesture recognizers
    private var tapGesture: UITapGestureRecognizer!
    private var panGesture: UIPanGestureRecognizer!
    private var rotationGesture: UIRotationGestureRecognizer!
    private var pinchGesture: UIPinchGestureRecognizer!
    
    // Transform axis locking
    private enum AxisLock {
        case none, x, y, z
    }
    private var currentAxisLock: AxisLock = .none
    
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
        setupBottomBar()
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
        sceneView.showsStatistics = false
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
        gridNode = SCNNode()
        
        // Create grid lines
        let gridSize: Float = 10.0
        let gridSpacing: Float = 0.5
        let lineCount = Int(gridSize / gridSpacing) + 1
        
        // Create material for grid lines
        let gridMaterial = SCNMaterial()
        gridMaterial.diffuse.contents = UIColor.systemGray3
        gridMaterial.emission.contents = UIColor.systemGray5.withAlphaComponent(0.3)
        
        // Create vertical lines (along Z-axis)
        for i in 0..<lineCount {
            let x = -gridSize/2 + Float(i) * gridSpacing
            let lineGeometry = SCNBox(width: 0.01, height: 0.01, length: CGFloat(gridSize), chamferRadius: 0)
            lineGeometry.materials = [gridMaterial]
            
            let lineNode = SCNNode(geometry: lineGeometry)
            lineNode.position = SCNVector3(x, 0, 0)
            gridNode!.addChildNode(lineNode)
        }
        
        // Create horizontal lines (along X-axis)
        for i in 0..<lineCount {
            let z = -gridSize/2 + Float(i) * gridSpacing
            let lineGeometry = SCNBox(width: CGFloat(gridSize), height: 0.01, length: 0.01, chamferRadius: 0)
            lineGeometry.materials = [gridMaterial]
            
            let lineNode = SCNNode(geometry: lineGeometry)
            lineNode.position = SCNVector3(0, 0, z)
            gridNode!.addChildNode(lineNode)
        }
        
        // Add a subtle ground plane for better visual reference
        let groundPlane = SCNPlane(width: CGFloat(gridSize), height: CGFloat(gridSize))
        let groundMaterial = SCNMaterial()
        groundMaterial.diffuse.contents = UIColor.black.withAlphaComponent(0.1)
        groundMaterial.isDoubleSided = true
        groundPlane.materials = [groundMaterial]
        
        let groundNode = SCNNode(geometry: groundPlane)
        groundNode.rotation = SCNVector4(1, 0, 0, -Float.pi/2) // Rotate to be horizontal
        groundNode.position = SCNVector3(0, -0.005, 0) // Slightly below grid lines
        
        // Physics removed - no collision detection needed
        
        gridNode!.addChildNode(groundNode)
        
        scene.rootNode.addChildNode(gridNode!)
        print("✅ Created grid with \(lineCount)x\(lineCount) lines")
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
        
        // Create Close button (X)
        let closeButton = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(dismissEditor)
        )
        // Create Done button
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissEditor))
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        topToolbar.items = [closeButton, flexSpace, doneButton]
        
        // Constraints
        NSLayoutConstraint.activate([
            topToolbar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func setupBottomBar() {
        // Create a bottom toolbar with liquid glass effect
        bottomToolbar = UIToolbar()
        bottomToolbar.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure with liquid glass appearance
        let appearance = UIToolbarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor.clear
        
        bottomToolbar.standardAppearance = appearance
        bottomToolbar.compactAppearance = appearance
        bottomToolbar.scrollEdgeAppearance = appearance
        
        view.addSubview(bottomToolbar)
        
        // Constraints
        NSLayoutConstraint.activate([
            bottomToolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        // Set initial toolbar state
        updateBottomToolbar()
    }
    
    private func updateBottomToolbar() {
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        switch editorState {
        case .general:
            // General tools - Add objects, etc.
            let addButton = UIBarButtonItem(
                image: UIImage(systemName: "plus"),
                style: .plain,
                target: self,
                action: #selector(showAssetCatalog)
            )
            addButton.title = "Add"
            
            bottomToolbar.items = [flexSpace, addButton, flexSpace]
            
        case .meshSelected:
            // Mesh selected tools - Info, Transform, Rotation, Scale, and Delete
            let infoButton = UIBarButtonItem(
                image: UIImage(systemName: "info.circle"),
                style: .plain,
                target: self,
                action: #selector(showNodeInfo)
            )
            infoButton.title = "Info"
            
            let transformButton = UIBarButtonItem(
                image: UIImage(systemName: "move.3d"),
                style: .plain,
                target: self,
                action: #selector(showTransformTools)
            )
            transformButton.title = "Transform"
            
            let rotationButton = UIBarButtonItem(
                image: UIImage(systemName: "rotate.3d"),
                style: .plain,
                target: self,
                action: #selector(showRotationTools)
            )
            rotationButton.title = "Rotate"
            
            let scaleButton = UIBarButtonItem(
                image: UIImage(systemName: "scale.3d"),
                style: .plain,
                target: self,
                action: #selector(showScaleTools)
            )
            scaleButton.title = "Scale"
            
            let deleteButton = UIBarButtonItem(
                image: UIImage(systemName: "trash"),
                style: .plain,
                target: self,
                action: #selector(deleteSelectedMesh)
            )
            deleteButton.title = "Delete"
            deleteButton.tintColor = UIColor.systemRed
            
            bottomToolbar.items = [infoButton, flexSpace, transformButton, flexSpace, rotationButton, flexSpace, scaleButton, flexSpace, deleteButton]
            
        case .transforming:
            // Transform mode - show axis lock buttons and done button
            let xLockButton = UIBarButtonItem(
                title: "X",
                style: .plain,
                target: self,
                action: #selector(toggleXAxisLock)
            )
            xLockButton.tintColor = currentAxisLock == .x ? UIColor.systemRed : UIColor.systemRed.withAlphaComponent(0.3)
            
            let yLockButton = UIBarButtonItem(
                title: "Y",
                style: .plain,
                target: self,
                action: #selector(toggleYAxisLock)
            )
            yLockButton.tintColor = currentAxisLock == .y ? UIColor.systemGreen : UIColor.systemGreen.withAlphaComponent(0.3)
            
            let zLockButton = UIBarButtonItem(
                title: "Z",
                style: .plain,
                target: self,
                action: #selector(toggleZAxisLock)
            )
            zLockButton.tintColor = currentAxisLock == .z ? UIColor.systemBlue : UIColor.systemBlue.withAlphaComponent(0.3)
            
            let doneTransformButton = UIBarButtonItem(
                title: "Done",
                style: .done,
                target: self,
                action: #selector(exitTransformMode)
            )
            
            let helpButton = UIBarButtonItem(
                image: UIImage(systemName: "questionmark.circle"),
                style: .plain,
                target: self,
                action: #selector(showTransformHelp)
            )
            
            bottomToolbar.items = [helpButton, flexSpace, xLockButton, yLockButton, zLockButton, flexSpace, doneTransformButton]
        case .rotating:
            // Rotation mode - show axis lock buttons and done button
            let xLockButton = UIBarButtonItem(
                title: "X",
                style: .plain,
                target: self,
                action: #selector(toggleXAxisLock)
            )
            xLockButton.tintColor = currentAxisLock == .x ? UIColor.systemRed : UIColor.systemRed.withAlphaComponent(0.3)
            
            let yLockButton = UIBarButtonItem(
                title: "Y",
                style: .plain,
                target: self,
                action: #selector(toggleYAxisLock)
            )
            yLockButton.tintColor = currentAxisLock == .y ? UIColor.systemGreen : UIColor.systemGreen.withAlphaComponent(0.3)
            
            let zLockButton = UIBarButtonItem(
                title: "Z",
                style: .plain,
                target: self,
                action: #selector(toggleZAxisLock)
            )
            zLockButton.tintColor = currentAxisLock == .z ? UIColor.systemBlue : UIColor.systemBlue.withAlphaComponent(0.3)
            
            let doneRotationButton = UIBarButtonItem(
                title: "Done",
                style: .done,
                target: self,
                action: #selector(exitRotationMode)
            )
            
            let helpButton = UIBarButtonItem(
                image: UIImage(systemName: "questionmark.circle"),
                style: .plain,
                target: self,
                action: #selector(showRotationHelp)
            )
            
            bottomToolbar.items = [helpButton, flexSpace, xLockButton, yLockButton, zLockButton, flexSpace, doneRotationButton]
        case .scaling:
            // Scale mode - show axis lock buttons and done button
            let xLockButton = UIBarButtonItem(
                title: "X",
                style: .plain,
                target: self,
                action: #selector(toggleXAxisLock)
            )
            xLockButton.tintColor = currentAxisLock == .x ? UIColor.systemRed : UIColor.systemRed.withAlphaComponent(0.3)
            
            let yLockButton = UIBarButtonItem(
                title: "Y",
                style: .plain,
                target: self,
                action: #selector(toggleYAxisLock)
            )
            yLockButton.tintColor = currentAxisLock == .y ? UIColor.systemGreen : UIColor.systemGreen.withAlphaComponent(0.3)
            
            let zLockButton = UIBarButtonItem(
                title: "Z",
                style: .plain,
                target: self,
                action: #selector(toggleZAxisLock)
            )
            zLockButton.tintColor = currentAxisLock == .z ? UIColor.systemBlue : UIColor.systemBlue.withAlphaComponent(0.3)
            
            let doneScaleButton = UIBarButtonItem(
                title: "Done",
                style: .done,
                target: self,
                action: #selector(exitScaleMode)
            )
            
            let helpButton = UIBarButtonItem(
                image: UIImage(systemName: "questionmark.circle"),
                style: .plain,
                target: self,
                action: #selector(showScaleHelp)
            )
            
            bottomToolbar.items = [helpButton, flexSpace, xLockButton, yLockButton, zLockButton, flexSpace, doneScaleButton]
        }
    }
    
    private func updateGesturesAndCamera() {
        switch editorState {
        case .general, .meshSelected:
            // Enable camera controls, disable all manipulation gestures
            sceneView.allowsCameraControl = true
            tapGesture.isEnabled = true
            panGesture.isEnabled = false
            rotationGesture.isEnabled = false
            pinchGesture.isEnabled = false
            
        case .transforming:
            // Disable camera controls, enable pan gesture only
            sceneView.allowsCameraControl = false
            tapGesture.isEnabled = false
            panGesture.isEnabled = true
            rotationGesture.isEnabled = false
            pinchGesture.isEnabled = false
            
        case .rotating:
            // Disable camera controls, enable pan gesture for rotation
            sceneView.allowsCameraControl = false
            tapGesture.isEnabled = false
            panGesture.isEnabled = true
            rotationGesture.isEnabled = false
            pinchGesture.isEnabled = false
            
        case .scaling:
            // Disable camera controls, enable pinch gesture only
            sceneView.allowsCameraControl = false
            tapGesture.isEnabled = false
            panGesture.isEnabled = false
            rotationGesture.isEnabled = false
            pinchGesture.isEnabled = true
        }
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
                
                // Physics removed - no collision detection needed
                
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
        // Get the accurate bounding box for the entire model hierarchy
        let (min, max) = getAccurateBoundingBox(for: node)
        
        // Check if we got valid bounds
        guard min != max else {
            print("⚠️ Invalid bounding box, using default positioning")
            node.position = SCNVector3(0, 0, 0)
            return
        }
        
        let center = SCNVector3(
            (min.x + max.x) / 2,
            (min.y + max.y) / 2,
            (min.z + max.z) / 2
        )
        
        // Calculate the model's size
        let size = SCNVector3(
            max.x - min.x,
            max.y - min.y,
            max.z - min.z
        )
        let maxDimension = Swift.max(size.x, Swift.max(size.y, size.z))
        
        // Scale the model to fit within a reasonable size first
        let targetSize: Float = 2.0
        var scaleFactor: Float = 1.0
        if maxDimension > targetSize {
            scaleFactor = targetSize / maxDimension
            node.scale = SCNVector3(scaleFactor, scaleFactor, scaleFactor)
        }
        
        // After scaling, recalculate the effective bounds
        let scaledMinY = min.y * scaleFactor
        let scaledCenter = SCNVector3(
            center.x * scaleFactor,
            center.y * scaleFactor,
            center.z * scaleFactor
        )
        
        // Position model: center horizontally, place bottom at floor level
        let floorOffset: Float = 0.01 // Slightly more offset for better visual separation
        node.position = SCNVector3(-scaledCenter.x, -scaledMinY + floorOffset, -scaledCenter.z)
        
        print("🏠 Model positioned at: \(node.position)")
        print("📐 Original bounds: min=\(min), max=\(max)")
        print("📐 Scale factor: \(scaleFactor)")
        print("📐 Scaled minY: \(scaledMinY)")
        
        // Position camera to look at the scaled model
        let scaledHeight = size.y * scaleFactor
        let modelCenter = SCNVector3(0, scaledHeight / 2, 0)
        
        // Position camera at a good distance based on model size
        let cameraDistance = Swift.max(scaledHeight * 2, targetSize * 1.5)
        cameraNode.position = SCNVector3(0, modelCenter.y, cameraDistance)
        cameraNode.look(at: modelCenter)
    }
    
    private func getAccurateBoundingBox(for node: SCNNode) -> (min: SCNVector3, max: SCNVector3) {
        var minX: Float = Float.greatestFiniteMagnitude
        var minY: Float = Float.greatestFiniteMagnitude
        var minZ: Float = Float.greatestFiniteMagnitude
        var maxX: Float = -Float.greatestFiniteMagnitude
        var maxY: Float = -Float.greatestFiniteMagnitude
        var maxZ: Float = -Float.greatestFiniteMagnitude
        
        var foundGeometry = false
        
        // Recursively find all nodes with geometry and accumulate their bounds
        func accumulateBounds(node: SCNNode, transform: SCNMatrix4) {
            let nodeTransform = SCNMatrix4Mult(transform, node.transform)
            
            if let geometry = node.geometry {
                foundGeometry = true
                let (nodeMin, nodeMax) = node.boundingBox
                
                // Transform the 8 corners of the bounding box
                let corners = [
                    SCNVector3(nodeMin.x, nodeMin.y, nodeMin.z),
                    SCNVector3(nodeMax.x, nodeMin.y, nodeMin.z),
                    SCNVector3(nodeMin.x, nodeMax.y, nodeMin.z),
                    SCNVector3(nodeMax.x, nodeMax.y, nodeMin.z),
                    SCNVector3(nodeMin.x, nodeMin.y, nodeMax.z),
                    SCNVector3(nodeMax.x, nodeMin.y, nodeMax.z),
                    SCNVector3(nodeMin.x, nodeMax.y, nodeMax.z),
                    SCNVector3(nodeMax.x, nodeMax.y, nodeMax.z)
                ]
                
                for corner in corners {
                    let transformedCorner = SCNVector3(
                        nodeTransform.m11 * corner.x + nodeTransform.m21 * corner.y + nodeTransform.m31 * corner.z + nodeTransform.m41,
                        nodeTransform.m12 * corner.x + nodeTransform.m22 * corner.y + nodeTransform.m32 * corner.z + nodeTransform.m42,
                        nodeTransform.m13 * corner.x + nodeTransform.m23 * corner.y + nodeTransform.m33 * corner.z + nodeTransform.m43
                    )
                    
                    minX = Swift.min(minX, transformedCorner.x)
                    minY = Swift.min(minY, transformedCorner.y)
                    minZ = Swift.min(minZ, transformedCorner.z)
                    maxX = Swift.max(maxX, transformedCorner.x)
                    maxY = Swift.max(maxY, transformedCorner.y)
                    maxZ = Swift.max(maxZ, transformedCorner.z)
                }
            }
            
            // Recursively process child nodes
            for child in node.childNodes {
                accumulateBounds(node: child, transform: nodeTransform)
            }
        }
        
        // Start with identity transform
        accumulateBounds(node: node, transform: SCNMatrix4Identity)
        
        if !foundGeometry {
            print("⚠️ No geometry found in model hierarchy")
            return (SCNVector3Zero, SCNVector3Zero)
        }
        
        return (
            min: SCNVector3(minX, minY, minZ),
            max: SCNVector3(maxX, maxY, maxZ)
        )
    }
    
    // MARK: - Gesture Setup
    private func setupTapGesture() {
        // Tap gesture for selection
        tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        sceneView.addGestureRecognizer(tapGesture)
        
        // Pan gesture for moving objects in transform mode
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.isEnabled = false // Initially disabled
        sceneView.addGestureRecognizer(panGesture)
        
        // Rotation gesture for rotating objects in rotation mode
        rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        rotationGesture.isEnabled = false // Initially disabled
        sceneView.addGestureRecognizer(rotationGesture)
        
        // Pinch gesture for scaling objects in scale mode
        pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinchGesture.isEnabled = false // Initially disabled
        sceneView.addGestureRecognizer(pinchGesture)
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
        
        // Update editor state
        editorState = .meshSelected
        
        print("Selected node: \(node.name ?? "unnamed")")
    }
    
    private func deselectNode() {
        if let selectedNode = selectedNode {
            removeHighlight(from: selectedNode)
        }
        selectedNode = nil
        
        // Update editor state
        editorState = .general
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
    
    @objc private func showAssetCatalog() {
        // Use native iOS action sheet style like the info card
        let alert = UIAlertController(title: "Asset Catalog", message: "Select an object to add to the scene", preferredStyle: .actionSheet)
        
        // Add all asset options
        alert.addAction(UIAlertAction(title: "Cube", style: .default) { _ in
            self.addCube()
        })
        
        alert.addAction(UIAlertAction(title: "Sphere", style: .default) { _ in
            self.addSphere()
        })
        
        alert.addAction(UIAlertAction(title: "Cylinder", style: .default) { _ in
            self.addCylinder()
        })
        
        // For iPad
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = bottomToolbar.items?.first { $0.image == UIImage(systemName: "plus") }
        }
        
        present(alert, animated: true)
    }

    
    @objc private func addCube() {
        let cubeGeometry = SCNBox(width: 0.2, height: 0.2, length: 0.2, chamferRadius: 0.02)
        
        // Create material for the cube
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.systemBlue
        material.metalness.contents = 0.2
        material.roughness.contents = 0.8
        cubeGeometry.materials = [material]
        
        // Create node
        let cubeNode = SCNNode(geometry: cubeGeometry)
        cubeNode.name = "Cube"
        
        // Place cube at origin (no physics)
        cubeNode.position = SCNVector3(0, 0.1, 0) // Slightly above grid to be visible
        
        // Add to scene
        scene.rootNode.addChildNode(cubeNode)
        
        print("✅ Added cube at origin: \(cubeNode.position)")
    }
    
    private func addSphere() {
        let sphereGeometry = SCNSphere(radius: 0.1)
        
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.systemRed
        material.metalness.contents = 0.3
        material.roughness.contents = 0.7
        sphereGeometry.materials = [material]
        
        let sphereNode = SCNNode(geometry: sphereGeometry)
        sphereNode.name = "Sphere"
        sphereNode.position = SCNVector3(0, 0.1, 0)
        
        scene.rootNode.addChildNode(sphereNode)
        print("✅ Added sphere at origin: \(sphereNode.position)")
    }
    
    private func addCylinder() {
        let cylinderGeometry = SCNCylinder(radius: 0.1, height: 0.2)
        
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.systemGreen
        material.metalness.contents = 0.4
        material.roughness.contents = 0.6
        cylinderGeometry.materials = [material]
        
        let cylinderNode = SCNNode(geometry: cylinderGeometry)
        cylinderNode.name = "Cylinder"
        cylinderNode.position = SCNVector3(0, 0.1, 0)
        
        scene.rootNode.addChildNode(cylinderNode)
        print("✅ Added cylinder at origin: \(cylinderNode.position)")
    }
    
    @objc private func showNodeInfo() {
        guard let selectedNode = selectedNode else { return }
        
        let nodeName = selectedNode.name ?? "Unnamed Node"
        let position = selectedNode.position
        let scale = selectedNode.scale
        let rotation = selectedNode.rotation
        
        // Create action sheet for node information
        let alert = UIAlertController(title: "\(nodeName)", message: "Current position: \(position)", preferredStyle: .actionSheet)
        
        // For iPad
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = bottomToolbar.items?.first { $0.image == UIImage(systemName: "info.circle") }
        }
        
        present(alert, animated: true)
    }
    
        @objc private func showTransformTools() {
        // Directly enter transform mode when transform button is tapped
        enterTransformMode()
    }
    
    @objc private func showRotationTools() {
        // Enter rotation mode when rotation button is tapped
        enterRotationMode()
    }
    
    @objc private func showScaleTools() {
        // Enter scale mode when scale button is tapped
        enterScaleMode()
    }
    
    @objc private func enterTransformMode() {
        guard selectedNode != nil else { return }
        currentAxisLock = .none // Reset axis lock when entering transform mode
        editorState = .transforming
        print("🎯 Entered transform mode - swipe to move object")
    }
    
    @objc private func exitTransformMode() {
        editorState = .meshSelected
        print("✅ Exited transform mode")
    }
    
    @objc private func enterRotationMode() {
        guard selectedNode != nil else { return }
        currentAxisLock = .none // Reset axis lock when entering rotation mode
        editorState = .rotating
        print("🔄 Entered rotation mode - swipe to rotate object (default: Y-axis)")
    }
    
    @objc private func exitRotationMode() {
        editorState = .meshSelected
        print("✅ Exited rotation mode")
    }
    
    @objc private func enterScaleMode() {
        guard selectedNode != nil else { return }
        currentAxisLock = .none // Reset axis lock when entering scale mode
        editorState = .scaling
        print("📏 Entered scale mode - pinch to scale object")
    }
    
    @objc private func exitScaleMode() {
        editorState = .meshSelected
        print("✅ Exited scale mode")
    }
    
    @objc private func showTransformHelp() {
        let message = """
        Swipe on the screen to move the selected object.
        
        Tap X (red) to lock movement to X-axis only
        Tap Y (green) to lock movement to Y-axis only  
        Tap Z (blue) to lock movement to Z-axis only
        
        Tap 'Done' when finished.
        """
        showAlert(title: "Transform Mode", message: message)
    }
    
    @objc private func showRotationHelp() {
        let message = """
        Swipe with one finger to rotate the selected object.
        Default: horizontal swipe rotates around Y-axis (spin left/right)
        
        Tap X (red) to lock rotation to X-axis only (vertical swipe)
        Tap Y (green) to lock rotation to Y-axis only (horizontal swipe)
        Tap Z (blue) to lock rotation to Z-axis only (diagonal movement)
        
        Tap 'Done' when finished.
        """
        showAlert(title: "Rotation Mode", message: message)
    }
    
    @objc private func showScaleHelp() {
        let message = """
        Pinch with two fingers to scale the selected object.
        
        Tap X (red) to lock scaling to X-axis only
        Tap Y (green) to lock scaling to Y-axis only  
        Tap Z (blue) to lock scaling to Z-axis only
        
        Tap 'Done' when finished.
        """
        showAlert(title: "Scale Mode", message: message)
    }
    
    @objc private func toggleXAxisLock() {
        currentAxisLock = currentAxisLock == .x ? .none : .x
        updateBottomToolbar() // Refresh toolbar to update button colors
        print("🔴 X-axis lock: \(currentAxisLock == .x ? "ON" : "OFF")")
    }
    
    @objc private func toggleYAxisLock() {
        currentAxisLock = currentAxisLock == .y ? .none : .y
        updateBottomToolbar() // Refresh toolbar to update button colors
        print("🟢 Y-axis lock: \(currentAxisLock == .y ? "ON" : "OFF")")
    }
    
    @objc private func toggleZAxisLock() {
        currentAxisLock = currentAxisLock == .z ? .none : .z
        updateBottomToolbar() // Refresh toolbar to update button colors
        print("🔵 Z-axis lock: \(currentAxisLock == .z ? "ON" : "OFF")")
    }
    
    @objc private func deleteSelectedMesh() {
        guard let selectedNode = selectedNode else { return }
        
        let nodeName = selectedNode.name ?? "Unnamed Node"
        
        // Show confirmation alert before deleting
        let alert = UIAlertController(
            title: "Delete Mesh", 
            message: "Are you sure you want to delete '\(nodeName)'? This action cannot be undone.", 
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            // Remove the node from the scene
            selectedNode.removeFromParentNode()
            print("🗑️ Deleted mesh: \(nodeName)")
            
            // Clear selection and return to general state
            self.selectedNode = nil
            self.editorState = .general
        })
        
        present(alert, animated: true)
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let selectedNode = selectedNode else { return }
        
        let translation = gesture.translation(in: sceneView)
        
        switch gesture.state {
        case .changed:
            if editorState == .transforming {
                // Handle position transformation
                let currentPosition = selectedNode.position
                
                // Scale the translation to make movement feel natural
                let movementScale: Float = 0.01
                let deltaX = Float(translation.x) * movementScale
                let deltaY = -Float(translation.y) * movementScale // For Y-axis movement
                let deltaZ = Float(translation.y) * movementScale // Z movement (swipe up = away from camera)
                
                // Apply axis locks
                var newPosition = currentPosition
                
                switch currentAxisLock {
                case .none:
                    // Free movement on X and Z axes (original behavior)
                    newPosition = SCNVector3(
                        currentPosition.x + deltaX,
                        currentPosition.y,
                        currentPosition.z + deltaZ
                    )
                    
                case .x:
                    // Only move along X-axis
                    newPosition = SCNVector3(
                        currentPosition.x + deltaX,
                        currentPosition.y,
                        currentPosition.z
                    )
                    
                case .y:
                    // Only move along Y-axis (up/down)
                    newPosition = SCNVector3(
                        currentPosition.x,
                        currentPosition.y + deltaY,
                        currentPosition.z
                    )
                    
                case .z:
                    // Only move along Z-axis
                    newPosition = SCNVector3(
                        currentPosition.x,
                        currentPosition.y,
                        currentPosition.z + deltaZ
                    )
                }
                
                selectedNode.position = newPosition
                
            } else if editorState == .rotating {
                // Handle rotation with pan gesture for 360-degree rotation
                let currentRotation = selectedNode.rotation
                
                // Scale the translation to rotation values (more sensitive for rotation)
                let rotationScale: Float = 0.01
                let deltaX = Float(translation.x) * rotationScale
                let deltaY = Float(translation.y) * rotationScale
                
                // Apply rotation based on axis lock
                var newRotation = currentRotation
                
                switch currentAxisLock {
                case .none:
                    // Default to Y-axis rotation (horizontal swipe - most natural)
                    newRotation = SCNVector4(
                        0, 1, 0,
                        currentRotation.w + deltaX
                    )
                    selectedNode.rotation = newRotation
                    
                case .x:
                    // Only rotate around X-axis (vertical swipe)
                    newRotation = SCNVector4(
                        1, 0, 0,
                        currentRotation.w + deltaY
                    )
                    selectedNode.rotation = newRotation
                    
                case .y:
                    // Only rotate around Y-axis (horizontal swipe)
                    newRotation = SCNVector4(
                        0, 1, 0,
                        currentRotation.w + deltaX
                    )
                    selectedNode.rotation = newRotation
                    
                case .z:
                    // Only rotate around Z-axis (diagonal movement)
                    let combinedDelta = deltaX + deltaY
                    newRotation = SCNVector4(
                        0, 0, 1,
                        currentRotation.w + combinedDelta
                    )
                    selectedNode.rotation = newRotation
                }
            }
            
            // Reset translation for next frame
            gesture.setTranslation(CGPoint.zero, in: sceneView)
            
        case .ended, .cancelled:
            if editorState == .transforming {
                let lockStatus = currentAxisLock == .none ? "free" : "\(currentAxisLock)-axis locked"
                print("🎯 Object moved to position: \(selectedNode.position) (\(lockStatus))")
            } else if editorState == .rotating {
                let lockStatus = currentAxisLock == .none ? "Y-axis default" : "\(currentAxisLock)-axis locked"
                print("🔄 Object rotated (\(lockStatus))")
            }
            
        default:
            break
        }
    }
    
    @objc private func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        guard let selectedNode = selectedNode else { return }
        
        let rotation = gesture.rotation
        
        switch gesture.state {
        case .changed:
            // Apply rotation based on axis lock
            var rotationAxis: SCNVector3
            
            switch currentAxisLock {
            case .none:
                // Default Z-axis rotation for natural feel
                rotationAxis = SCNVector3(0, 0, 1)
                
            case .x:
                // Rotate around X-axis
                rotationAxis = SCNVector3(1, 0, 0)
                
            case .y:
                // Rotate around Y-axis (vertical)
                rotationAxis = SCNVector3(0, 1, 0)
                
            case .z:
                // Rotate around Z-axis
                rotationAxis = SCNVector3(0, 0, 1)
            }
            
            // Apply rotation incrementally
            selectedNode.rotation = SCNVector4(
                rotationAxis.x,
                rotationAxis.y,
                rotationAxis.z,
                selectedNode.rotation.w + Float(rotation)
            )
            
            // Reset gesture rotation for next frame
            gesture.rotation = 0
            
        case .ended, .cancelled:
            let lockStatus = currentAxisLock == .none ? "Z-axis default" : "\(currentAxisLock)-axis locked"
            print("🔄 Object rotated (\(lockStatus))")
            
        default:
            break
        }
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let selectedNode = selectedNode else { return }
        
        let scale = gesture.scale
        
        switch gesture.state {
        case .changed:
            // Get current scale
            let currentScale = selectedNode.scale
            
            // Calculate scale factor (increased sensitivity)
            let scaleFactor = Float(scale - 1.0) * 0.15
            
            // Apply scaling based on axis lock
            var newScale = currentScale
            
            switch currentAxisLock {
            case .none:
                // Uniform scaling
                let uniformScale = 1.0 + scaleFactor
                newScale = SCNVector3(
                    currentScale.x * uniformScale,
                    currentScale.y * uniformScale,
                    currentScale.z * uniformScale
                )
                
            case .x:
                // Scale only on X-axis
                newScale = SCNVector3(
                    currentScale.x * (1.0 + scaleFactor),
                    currentScale.y,
                    currentScale.z
                )
                
            case .y:
                // Scale only on Y-axis
                newScale = SCNVector3(
                    currentScale.x,
                    currentScale.y * (1.0 + scaleFactor),
                    currentScale.z
                )
                
            case .z:
                // Scale only on Z-axis
                newScale = SCNVector3(
                    currentScale.x,
                    currentScale.y,
                    currentScale.z * (1.0 + scaleFactor)
                )
            }
            
            // Prevent negative or extremely small scaling
            newScale = SCNVector3(
                max(0.1, newScale.x),
                max(0.1, newScale.y),
                max(0.1, newScale.z)
            )
            
            selectedNode.scale = newScale
            
            // Reset gesture scale for next frame
            gesture.scale = 1.0
            
        case .ended, .cancelled:
            let lockStatus = currentAxisLock == .none ? "uniform" : "\(currentAxisLock)-axis locked"
            print("📏 Object scaled to: \(selectedNode.scale) (\(lockStatus))")
            
        default:
            break
        }
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

