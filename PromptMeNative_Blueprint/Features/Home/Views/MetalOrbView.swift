import SwiftUI
import MetalKit

// MARK: - Public Entry Point

/// Metal GPU-rendered variant of OrbView.
/// Activated when `ExperimentFlags.Orb.metalOrb` (`is_metal_orb_enabled`) is true.
///
/// Falls back to the SwiftUI orb automatically if Metal is unavailable on the device.
struct MetalOrbView: View {
    var engine: OrbEngine
    let onTranscript: (String) -> Void
    @Environment(\.openURL) private var openURL

    @State private var orbState: OrbTapState = .idle

    private var engineCommands: any OrbEngineProtocol { engine }

    // MARK: - Metal availability

    private static let metalAvailable: Bool = MTLCreateSystemDefaultDevice() != nil

    var body: some View {
        if Self.metalAvailable {
            metalOrb
        } else {
            // Graceful SwiftUI fallback — device has no Metal GPU (simulator edge-case)
            swiftUIFallback
        }
    }

    // MARK: - Metal Orb

    private var metalOrb: some View {
        VStack(spacing: PromptTheme.Spacing.s) {
            GeometryReader { proxy in
                let size = min(proxy.size.width, proxy.size.height)

                OrbMTKViewRepresentable(
                    visualState: metalVisualState,
                    audioLevel: Float(engine.audioLevel)
                )
                .frame(width: size, height: size)
                .contentShape(Circle())
                .onTapGesture { handleTap() }
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 420)
            .padding(.horizontal, 8)

            permissionBanner
        }
        .preferredColorScheme(.dark)
        .onAppear  { engineCommands.onFinalTranscript = { onTranscript($0) } }
        .onDisappear { engineCommands.onFinalTranscript = nil }
        .onChange(of: engine.state) { _, state in syncOrbState(to: state) }
    }

    // MARK: - SwiftUI Fallback

    private var swiftUIFallback: some View {
        // Delegates back to the same SwiftUI visual so behaviour is identical.
        OrbView(engine: engine, onTranscript: onTranscript)
    }

    // MARK: - Shared Helpers

    private var metalVisualState: OrbMetalVisualState {
        switch engine.state {
        case .idle, .success:         return .idle
        case .listening, .ready:      return .listening
        case .transcribing, .generating: return .processing
        case .failure:                return .error
        }
    }

    @ViewBuilder
    private var permissionBanner: some View {
        if !engine.permissionMessage.isEmpty {
            VStack(spacing: 8) {
                Text(engine.permissionMessage)
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                if engine.needsPermissionSettingsAction {
                    Button("Open iOS Settings") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(url)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PromptTheme.mutedViolet.opacity(0.84))
                }
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    private func handleTap() {
        switch orbState {
        case .idle:
            HapticService.impact(.heavy)
            engineCommands.startListening()
            orbState = .listening
        case .listening:
            HapticService.impact(.light)
            if engineCommands.stopListening() { orbState = .processing }
        case .processing:
            break
        }
    }

    private func syncOrbState(to state: OrbEngine.State) {
        switch state {
        case .idle, .success, .failure:              orbState = .idle
        case .listening:                              orbState = .listening
        case .transcribing, .ready, .generating:     orbState = .processing
        }
    }
}

// MARK: - Visual State

enum OrbMetalVisualState: Int32 {
    case idle       = 0
    case listening  = 1
    case processing = 2
    case error      = 3
}

// MARK: - UIKit / Metal Bridge

struct OrbMTKViewRepresentable: UIViewRepresentable {
    var visualState: OrbMetalVisualState
    var audioLevel: Float

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.delegate = context.coordinator
        view.enableSetNeedsDisplay = false     // continuous render
        view.preferredFramesPerSecond = 30
        view.clearColor = MTLClearColorMake(0, 0, 0, 0)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.layer.isOpaque = false
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.visualState = visualState
        context.coordinator.audioLevel  = audioLevel
    }

    func makeCoordinator() -> OrbMetalRenderer {
        OrbMetalRenderer()
    }
}

// MARK: - Metal Renderer

final class OrbMetalRenderer: NSObject, MTKViewDelegate {

    var visualState: OrbMetalVisualState = .idle
    var audioLevel:  Float               = 0.0

    private var device:          MTLDevice?
    private var commandQueue:    MTLCommandQueue?
    private var pipeline:        MTLRenderPipelineState?
    private var vertexBuffer:    MTLBuffer?
    private var startDate =      Date()

    private struct Uniforms {
        var time:        Float
        var audioLevel:  Float
        var visualState: Int32
        var padding:     Int32 = 0
    }

    override init() {
        super.init()
        setupMetal()
    }

    private func setupMetal() {
        guard let dev = MTLCreateSystemDefaultDevice() else { return }
        device = dev
        commandQueue = dev.makeCommandQueue()

        // Full-screen quad (two triangles)
        let verts: [Float] = [
            -1, -1,   1, -1,  -1,  1,
             1, -1,   1,  1,  -1,  1
        ]
        vertexBuffer = dev.makeBuffer(bytes: verts,
                                      length: MemoryLayout<Float>.size * verts.count,
                                      options: .storageModeShared)

        guard
            let lib = dev.makeDefaultLibrary(),
            let vertFn = lib.makeFunction(name: "orbVertex"),
            let fragFn = lib.makeFunction(name: "orbFragment")
        else {
            #if DEBUG
            print("🌌 [MetalOrb] Shader functions not found — ensure Orb.metal is in the target.")
            #endif
            return
        }

        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction   = vertFn
        desc.fragmentFunction = fragFn
        desc.colorAttachments[0].pixelFormat              = .bgra8Unorm
        desc.colorAttachments[0].isBlendingEnabled        = true
        desc.colorAttachments[0].sourceRGBBlendFactor     = .sourceAlpha
        desc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        desc.colorAttachments[0].sourceAlphaBlendFactor   = .sourceAlpha
        desc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        pipeline = try? dev.makeRenderPipelineState(descriptor: desc)
    }

    // MARK: MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard
            let pipeline,
            let commandQueue,
            let vertexBuffer,
            let drawable     = view.currentDrawable,
            let passDesc     = view.currentRenderPassDescriptor,
            let cmdBuf       = commandQueue.makeCommandBuffer(),
            let encoder      = cmdBuf.makeRenderCommandEncoder(descriptor: passDesc)
        else { return }

        var uniforms = Uniforms(
            time:        Float(Date().timeIntervalSince(startDate)),
            audioLevel:  audioLevel,
            visualState: visualState.rawValue
        )

        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentBytes(&uniforms,
                                  length: MemoryLayout<Uniforms>.stride,
                                  index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()

        cmdBuf.present(drawable)
        cmdBuf.commit()
    }
}
