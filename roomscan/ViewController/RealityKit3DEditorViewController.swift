import UIKit
import RealityKit
import ARKit
import Combine

class RealityKit3DEditorViewController: UIViewController {
    
    // MARK: - Properties
    private var arView: ARView!
    private var modelURL: URL!
    private var selectedEntity: ModelEntity?
    private var cancellables = Set<AnyCancellable>()
    private var toolbar: UIToolbar!
    private var topToolbar: UIToolbar!
    
    // Gesture recognizers
    private var panGesture: UIPanGestureRecognizer!
    private var pinchGesture: UIPinchGestureRecognizer!
    private var rotationGesture: UIRotationGestureRecognizer!
    
    // Camera control
    private var sceneAnchor: AnchorEntity!
    private var cameraDistance: Float = 3.0
    private var cameraRotationX: Float = 0.0
    private var cameraRotationY: Float = 0.0
    
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
        setupARView()
        setupVirtual3DEnvironment()
        setupToolbars()
        setupGestures()
        setupLighting()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Load model after view is in window hierarchy
        loadModelAsync()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // No AR session needed - pure 3D viewport
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // No need to pause AR session in virtual mode
    }
    
    // MARK: - Setup Methods
    private func setupARView() {
        arView = ARView(frame: view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.backgroundColor = UIColor.darkGray // Dark background like Blender
        view.addSubview(arView)
        
        // Disable ALL AR features - pure 3D viewport mode
        arView.debugOptions = []
        arView.renderOptions = [.disablePersonOcclusion, .disableDepthOfField, .disableMotionBlur, .disableCameraGrain, .disableHDR]
        
        // Disable automatic session management
        arView.automaticallyConfigureSession = false
    }
    
    private func setupVirtual3DEnvironment() {
        // Create a pure 3D viewport environment (no AR tracking)
        // This gives us full control over the camera and scene like in Blender
        
        // Set up non-AR environment lighting
        arView.environment.lighting.intensityExponent = 1.0
        
        // Create a main scene anchor that will hold all content
        sceneAnchor = AnchorEntity()
        arView.scene.anchors.append(sceneAnchor)
        
        // Add a ground plane for reference
        let groundPlane = ModelEntity(
            mesh: .generatePlane(width: 10, depth: 10),
            materials: [SimpleMaterial(color: UIColor.systemGray5.withAlphaComponent(0.3), isMetallic: false)]
        )
        groundPlane.position.y = -0.5
        sceneAnchor.addChild(groundPlane)
        
        // Add a grid for better spatial reference
        addGridSystem()
    }
    
    private func addGridSystem() {
        // Add grid lines to the main scene anchor
        for i in -5...5 {
            // Vertical lines
            let verticalLine = ModelEntity(
                mesh: .generateBox(width: 0.01, height: 0.01, depth: 10),
                materials: [SimpleMaterial(color: UIColor.systemGray4.withAlphaComponent(0.5), isMetallic: false)]
            )
            verticalLine.position = [Float(i), -0.49, 0]
            sceneAnchor.addChild(verticalLine)
            
            // Horizontal lines
            let horizontalLine = ModelEntity(
                mesh: .generateBox(width: 10, height: 0.01, depth: 0.01),
                materials: [SimpleMaterial(color: UIColor.systemGray4.withAlphaComponent(0.5), isMetallic: false)]
            )
            horizontalLine.position = [0, -0.49, Float(i)]
            sceneAnchor.addChild(horizontalLine)
        }
    }
    
    private func setupToolbars() {
        // Top toolbar
        topToolbar = UIToolbar()
        topToolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topToolbar)
        
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissEditor))
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let resetButton = UIBarButtonItem(title: "Reset View", style: .plain, target: self, action: #selector(resetCameraView))
        
        topToolbar.items = [doneButton, flexSpace, resetButton]
        
        // Bottom toolbar
        toolbar = UIToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)
        
        let deleteButton = UIBarButtonItem(title: "🗑️ Delete", style: .plain, target: self, action: #selector(deleteSelected))
        let flexSpace2 = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolbar.items = [flexSpace, flexSpace2, flexSpace2, deleteButton]
        
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
        // Pan gesture for camera movement
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.minimumNumberOfTouches = 1
        panGesture.maximumNumberOfTouches = 1
        arView.addGestureRecognizer(panGesture)
        
        // Pinch gesture for camera zoom
        pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        arView.addGestureRecognizer(pinchGesture)
        
        // Tap gesture for selection
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
    }
    
    private func setupLighting() {
        // Add ambient lighting
        let lightAnchor = AnchorEntity()
        let directionalLight = DirectionalLightComponent(color: .white, intensity: 500)
        let lightEntity = Entity()
        lightEntity.components.set(directionalLight)
        lightEntity.transform.rotation = simd_quatf(angle: -Float.pi/4, axis: [1, 1, 0])
        lightAnchor.addChild(lightEntity)
        arView.scene.anchors.append(lightAnchor)
    }
    
    private func loadModelAsync() {
        guard let modelURL = modelURL else {
            print("❌ No model URL provided")
            return
        }
        
        print("🔄 Loading USDZ model from: \(modelURL.absoluteString)")
        
        // First, ensure we can access the file (especially important for iCloud files)
        guard modelURL.startAccessingSecurityScopedResource() else {
            print("❌ Cannot access security scoped resource")
            showErrorAlert(message: "Cannot access the selected file. Please try again.")
            return
        }
        
        // Ensure file is downloaded if it's an iCloud file
        do {
            let resourceValues = try modelURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            if let downloadStatus = resourceValues.ubiquitousItemDownloadingStatus {
                if downloadStatus.rawValue != "current" {
                    print("📥 iCloud file needs to be downloaded...")
                    try FileManager.default.startDownloadingUbiquitousItem(at: modelURL)
                }
            }
        } catch {
            print("⚠️ Could not check iCloud status: \(error)")
        }
        
        // Use async loading as recommended by Apple
        ModelEntity.loadModelAsync(contentsOf: modelURL)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    modelURL.stopAccessingSecurityScopedResource()
                    
                    if case .failure(let error) = completion {
                        print("❌ Failed to load model: \(error)")
                        self?.showErrorAlert(message: "Failed to load the 3D model: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] entity in
                    print("✅ Successfully loaded model entity")
                    self?.handleLoadedModel(entity)
                }
            )
            .store(in: &cancellables)
    }
    
    private func handleLoadedModel(_ entity: ModelEntity) {
        // Calculate model bounds
        let bounds = entity.model?.mesh.bounds ?? BoundingBox()
        let size = bounds.max - bounds.min
        let maxDimension = Swift.max(size.x, Swift.max(size.y, size.z))
        
        print("📐 Model size: \(size), max dimension: \(maxDimension)")
        
        // Scale model to reasonable size
        let targetSize: Float = 1.0
        if maxDimension > targetSize {
            let scaleFactor = targetSize / maxDimension
            entity.transform.scale = [scaleFactor, scaleFactor, scaleFactor]
            print("🔄 Scaled model by factor: \(scaleFactor)")
        }
        
        // Center the model
        let center = (bounds.max + bounds.min) / 2
        entity.position = [-center.x, -center.y, -center.z]
        print("🎯 Centered model at position: \(entity.position)")
        
        // Add model to scene
        sceneAnchor.addChild(entity)
        print("✅ Added model to scene anchor")
        
        // Enable interaction
        entity.generateCollisionShapes(recursive: true)
        arView.installGestures([.translation, .rotation, .scale], for: entity)
        
        // Setup camera
        setupCameraForModel(originalMaxDimension: maxDimension)
    }
    
    private func setupCameraForModel(originalMaxDimension: Float) {
        cameraDistance = Swift.max(2.0, originalMaxDimension * 0.5)
        cameraRotationX = -0.3
        cameraRotationY = 0.5
        updateCameraPosition()
    }
    
    // MARK: - Actions
    @objc private func dismissEditor() {
        dismiss(animated: true)
    }
    
    @objc private func resetCameraView() {
        cameraRotationX = 0.0
        cameraRotationY = 0.0
        updateCameraPosition()
    }
    
    @objc private func deleteSelected() {
        guard let selected = selectedEntity else {
            showErrorAlert(message: "No object selected. Tap on an object to select it first.")
            return
        }
        
        selected.removeFromParent()
        selectedEntity = nil
    }
    
    // MARK: - Gesture Handlers
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: arView)
        
        switch gesture.state {
        case .changed:
            // Rotate camera around the scene
            cameraRotationY -= Float(translation.x) * 0.01
            cameraRotationX -= Float(translation.y) * 0.01  // Negated for natural up/down movement
            
            // Clamp vertical rotation
            cameraRotationX = Swift.max(-Float.pi/2, Swift.min(Float.pi/2, cameraRotationX))
            
            updateCameraPosition()
            gesture.setTranslation(.zero, in: arView)
            
        default:
            break
        }
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .changed:
            cameraDistance *= Float(1.0 / gesture.scale)
            cameraDistance = Swift.max(0.2, Swift.min(15.0, cameraDistance)) // Better zoom range
            updateCameraPosition()
            gesture.scale = 1.0
            
        default:
            break
        }
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: arView)
        
        if let entity = arView.entity(at: location) as? ModelEntity {
            selectEntity(entity)
        } else {
            deselectEntity()
        }
    }
    
    private func updateCameraPosition() {
        // Calculate camera position based on rotation and distance
        let x = cameraDistance * cos(cameraRotationX) * sin(cameraRotationY)
        let y = cameraDistance * sin(cameraRotationX)
        let z = cameraDistance * cos(cameraRotationX) * cos(cameraRotationY)
        
        // Since cameraTransform is read-only, we'll move the entire scene instead
        // This creates the same visual effect as moving the camera
        let sceneTransform = Transform(
            scale: [1, 1, 1],
            rotation: simd_quatf(angle: cameraRotationX, axis: [1, 0, 0]) * simd_quatf(angle: -cameraRotationY, axis: [0, 1, 0]),
            translation: [-x, -y, -z]
        )
        
        // Apply transform to the main scene anchor
        sceneAnchor.transform = sceneTransform
    }
    
    private func selectEntity(_ entity: ModelEntity) {
        // Deselect previous
        deselectEntity()
        
        // Select new entity
        selectedEntity = entity
        
        // Add selection highlight (you can customize this)
        let highlightMaterial = SimpleMaterial(color: .yellow, isMetallic: false)
        if let originalMaterial = entity.model?.materials.first {
            // Store original material if needed for deselection
        }
        
        // Visual feedback for selection
        entity.transform.scale *= 1.1
    }
    
    private func deselectEntity() {
        if let selected = selectedEntity {
            // Remove selection highlight
            selected.transform.scale /= 1.1
        }
        selectedEntity = nil
    }
    
    private func showErrorAlert(message: String) {
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(alert, animated: true)
        }
    }
} 

