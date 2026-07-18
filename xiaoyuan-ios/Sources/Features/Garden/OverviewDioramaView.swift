import SwiftUI
import SceneKit
import UIKit

/// 3D 俯瞰:整座园子做成一本摊开的毛毡立体书。
/// 圆角毡绿底座,毛毡素材立成小纸片,柔光、微俯视;
/// 只许小幅左右环视(±25°)与捏合缩放,其余一切安安静静。
/// 点立体书里的建筑,与 2D 场景走同样的导航闭包。
/// 背景透明,身后仍是同一幅 SkyView 的天。
struct OverviewDioramaView: UIViewRepresentable {
    var phase: DayPhase
    var onOpen: (GardenPlace) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onOpen: onOpen)
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.antialiasingMode = .multisampling4X
        view.allowsCameraControl = false
        view.rendersContinuously = false
        view.preferredFramesPerSecond = 60

        let scene = SCNScene()
        scene.background.contents = UIColor.clear
        view.scene = scene

        context.coordinator.view = view
        context.coordinator.build(in: scene)
        context.coordinator.apply(phase: phase, animated: false)

        view.addGestureRecognizer(UIPanGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.handlePan(_:))))
        view.addGestureRecognizer(UIPinchGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.handlePinch(_:))))
        view.addGestureRecognizer(UITapGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.handleTap(_:))))
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.onOpen = onOpen
        context.coordinator.apply(phase: phase, animated: true)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject {
        var onOpen: (GardenPlace) -> Void
        weak var view: SCNView?

        private let rig = SCNNode()          // 只绕 y 轴小幅环视
        private let cameraNode = SCNNode()
        private let ambientLight = SCNLight()
        private let sunLight = SCNLight()
        private var greenhouseMaterial: SCNMaterial?
        private var cottageMaterial: SCNMaterial?
        private var appliedPhase: DayPhase?

        private let slabTop: Float = 0.8
        private var yaw: Float = 0
        private var yawAtPanStart: Float = 0
        private var distance: Float = 19
        private var distanceAtPinchStart: Float = 19
        private let maxYaw: Float = 25 * .pi / 180
        private let pitch: Float = -28 * .pi / 180          // 约 28° 俯视
        private let dirY: Float = sin(28 * Float.pi / 180)
        private let dirZ: Float = cos(28 * Float.pi / 180)

        private static let placeByName: [String: GardenPlace] = [
            "greenhouse": .greenhouse,
            "flowerbed": .flowerbed,
            "mailbox": .mailbox,
            "cottage": .dollhouse,
        ]

        init(onOpen: @escaping (GardenPlace) -> Void) {
            self.onOpen = onOpen
        }

        // MARK: 搭台

        func build(in scene: SCNScene) {
            let root = scene.rootNode

            // 纸底 + 圆角毡绿草坪(小小的立体书底座)
            let base = SCNBox(width: 28.4, height: 0.55, length: 9.2, chamferRadius: 0.28)
            base.firstMaterial = feltMaterial(rgb(0xFFF6E3))
            let baseNode = SCNNode(geometry: base)
            baseNode.position = SCNVector3(0, -0.275, 0)
            baseNode.name = "ground"
            root.addChildNode(baseNode)

            let slab = SCNBox(width: 27, height: 0.8, length: 8, chamferRadius: 0.4)
            slab.firstMaterial = feltMaterial(rgb(0x9CC08A))
            let slabNode = SCNNode(geometry: slab)
            slabNode.position = SCNVector3(0, 0.4, 0)
            slabNode.name = "ground"
            root.addChildNode(slabNode)

            // 立起来的毛毡纸片(x 按 2D 场景横坐标折算:(cx-1300)/100)
            root.addChildNode(billboard("gate-frame", w: 2.5, h: 2.5, x: -11.0, z: -0.5, sink: 0.17))
            root.addChildNode(billboard("mailbox", w: 1.25, h: 1.87, x: -9.4, z: 0.3, sink: 0.17,
                                        name: "mailbox"))
            root.addChildNode(billboard("flowerbed", w: 4.1, h: 2.73, x: -6.4, z: 0.9, sink: 0.91,
                                        name: "flowerbed"))
            let greenhouse = billboard("greenhouse", w: 4.2, h: 2.8, x: -2.25, z: -0.2, sink: 0.19,
                                       name: "greenhouse")
            greenhouseMaterial = greenhouse.geometry?.firstMaterial
            root.addChildNode(greenhouse)
            root.addChildNode(billboard("tree", w: 3.47, h: 5.2, x: 2.94, z: -0.7, sink: 0.57))
            root.addChildNode(billboard("swing", w: 1.18, h: 1.76, x: 3.92, z: -0.2, sink: 0.17))
            let cottage = billboard("cottage", w: 4.0, h: 2.67, x: 7.85, z: 0.1, sink: 0.22,
                                    name: "cottage")
            cottageMaterial = cottage.geometry?.firstMaterial
            root.addChildNode(cottage)

            // 小溪平贴在草坪上
            let streamPlane = SCNPlane(width: 2.1, height: 3.1)
            streamPlane.firstMaterial = spriteMaterial("stream")
            let streamNode = SCNNode(geometry: streamPlane)
            streamNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
            streamNode.position = SCNVector3(11.0, slabTop + 0.02, 0.8)
            streamNode.renderingOrder = 600
            streamNode.castsShadow = false
            root.addChildNode(streamNode)

            // 两朵云浮在半空(静静的,不飘)
            let cloudA = billboard("cloud-a", w: 2.4, h: 2.4, x: -4.5, z: -2.6)
            cloudA.position = SCNVector3(-4.5, 6.0, -2.6)
            root.addChildNode(cloudA)
            let cloudB = billboard("cloud-b", w: 1.7, h: 1.7, x: 5.5, z: -2.8)
            cloudB.position = SCNVector3(5.5, 5.2, -2.8)
            root.addChildNode(cloudB)

            // 柔和环境光 + 一盏暖的方向光,不投影
            ambientLight.type = .ambient
            let ambientNode = SCNNode()
            ambientNode.light = ambientLight
            root.addChildNode(ambientNode)

            sunLight.type = .directional
            sunLight.castsShadow = false
            let sunNode = SCNNode()
            sunNode.light = sunLight
            sunNode.eulerAngles = SCNVector3(-0.95, -0.55, 0)
            root.addChildNode(sunNode)

            // 相机吊臂:rig 管环视,cameraNode 管俯角与距离
            let camera = SCNCamera()
            camera.fieldOfView = 34
            camera.zNear = 0.5
            camera.zFar = 120
            cameraNode.camera = camera
            cameraNode.eulerAngles = SCNVector3(pitch, 0, 0)
            rig.addChildNode(cameraNode)
            root.addChildNode(rig)
            setDistance(distance)
            view?.pointOfView = cameraNode
        }

        /// 昼夜:换亮灯素材、调光(在 2D 场景里对应 spriteDimming)
        func apply(phase: DayPhase, animated: Bool) {
            guard phase != appliedPhase else { return }
            appliedPhase = phase
            if animated {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 1.2
            }
            let night = phase == .night
            cottageMaterial?.diffuse.contents = UIImage(named: night ? "cottage-night" : "cottage")
            greenhouseMaterial?.diffuse.contents = UIImage(named: night ? "greenhouse-night" : "greenhouse")
            switch phase {
            case .day:
                ambientLight.color = rgb(0xFFF7E9); ambientLight.intensity = 750
                sunLight.color = rgb(0xFFEBD2); sunLight.intensity = 850
            case .dawn:
                ambientLight.color = rgb(0xFFE9DC); ambientLight.intensity = 680
                sunLight.color = rgb(0xFFD9BE); sunLight.intensity = 700
            case .dusk:
                ambientLight.color = rgb(0xF7DCC8); ambientLight.intensity = 620
                sunLight.color = rgb(0xFFC9A0); sunLight.intensity = 650
            case .night:
                ambientLight.color = rgb(0xA9B2CF); ambientLight.intensity = 400
                sunLight.color = rgb(0xB9C3E6); sunLight.intensity = 350
            }
            if animated {
                SCNTransaction.commit()
            }
        }

        // MARK: 手势

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            switch gesture.state {
            case .began:
                yawAtPanStart = yaw
            case .changed:
                let dx = Float(gesture.translation(in: gesture.view).x)
                yaw = max(-maxYaw, min(maxYaw, yawAtPanStart + dx * 0.0045))
                rig.eulerAngles.y = yaw
            default:
                break
            }
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .began:
                distanceAtPinchStart = distance
            case .changed:
                setDistance(distanceAtPinchStart / Float(gesture.scale))
            default:
                break
            }
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view else { return }
            let point = gesture.location(in: view)
            for result in view.hitTest(point, options: nil) {
                var node: SCNNode? = result.node
                while let current = node {
                    if let name = current.name, let place = Self.placeByName[name] {
                        onOpen(place)
                        return
                    }
                    node = current.parent
                }
            }
        }

        // MARK: 小工具

        private func setDistance(_ d: Float) {
            distance = max(13, min(26, d))
            cameraNode.position = SCNVector3(0, 1.2 + dirY * distance, dirZ * distance)
        }

        private func billboard(_ imageName: String, w: CGFloat, h: CGFloat,
                               x: Float, z: Float, sink: CGFloat = 0,
                               name: String? = nil) -> SCNNode {
            let plane = SCNPlane(width: w, height: h)
            plane.firstMaterial = spriteMaterial(imageName)
            let node = SCNNode(geometry: plane)
            node.position = SCNVector3(x, slabTop + Float(h / 2 - sink), z)
            node.renderingOrder = Int((z + 10) * 100)   // 手排前后,避免透明排序破绽
            node.castsShadow = false
            node.name = name
            return node
        }

        private func spriteMaterial(_ imageName: String) -> SCNMaterial {
            let material = SCNMaterial()
            material.diffuse.contents = UIImage(named: imageName)
            material.isDoubleSided = true
            material.lightingModel = .lambert
            material.writesToDepthBuffer = false
            return material
        }

        private func feltMaterial(_ color: UIColor) -> SCNMaterial {
            let material = SCNMaterial()
            material.diffuse.contents = color
            material.lightingModel = .lambert
            return material
        }

        private func rgb(_ hex: UInt32) -> UIColor {
            UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                    green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255,
                    alpha: 1)
        }
    }
}
