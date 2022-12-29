//
//  StickerView.swift
//  StickerView
//
//  Copyright © All rights reserved.
//

import UIKit

public enum StickerViewHandler: Int {
    case close = 0
    case rotate
    case flip
}

public enum StickerViewPosition: Int {
    case topLeft = 0
    case topRight
    case bottomLeft
    case bottomRight
}

@inline(__always) func CGRectGetCenter(_ rect: CGRect) -> CGPoint {
    CGPoint(x: rect.midX, y: rect.midY)
}

@inline(__always) func CGRectScale(_ rect: CGRect, wScale: CGFloat, hScale: CGFloat) -> CGRect {
    CGRect(x: rect.origin.x, y: rect.origin.y, width: rect.size.width * wScale, height: rect.size.height * hScale)
}

@inline(__always) func CGAffineTransformGetAngle(_ t: CGAffineTransform) -> CGFloat {
    atan2(t.b, t.a)
}

@inline(__always) func CGPointGetDistance(point1: CGPoint, point2: CGPoint) -> CGFloat {
    let fx = point2.x - point1.x
    let fy = point2.y - point1.y
    return sqrt(fx * fx + fy * fy)
}

@objc public protocol StickerViewDelegate {
    @objc func stickerViewDidBeginMoving(_ stickerView: StickerView)
    @objc func stickerViewDidChangeMoving(_ stickerView: StickerView)
    @objc func stickerViewDidEndMoving(_ stickerView: StickerView)
    @objc func stickerViewDidBeginRotating(_ stickerView: StickerView)
    @objc func stickerViewDidChangeRotating(_ stickerView: StickerView)
    @objc func stickerViewDidEndRotating(_ stickerView: StickerView)
    @objc func stickerViewDidClose(_ stickerView: StickerView)
    @objc func stickerViewDidTap(_ stickerView: StickerView)
}

open class StickerView: UIView {
    public weak var delegate: StickerViewDelegate?
    /// The contentView inside the sticker view.
    public var contentView: UIView!
    /// Enable the close handler or not. Default value is YES.
    public var enableClose: Bool = true {
        didSet {
            isCloseEnabled = showEditingHandlers ? enableClose : false
        }
    }
    /// Enable the rotate/resize handler or not. Default value is YES.
    public var enableRotate: Bool = true {
        didSet {
            isRotateEnabled = showEditingHandlers ? enableRotate : false
        }
    }
    /// Enable the flip handler or not. Default value is YES.
    public var enableFlip: Bool = true {
        didSet {
            isFlipEnabled = showEditingHandlers ? enableFlip : false
        }
    }
    /// Show close and rotate/resize handlers or not. Default value is YES.
    public var showEditingHandlers: Bool = true {
        didSet {
            isCloseEnabled = showEditingHandlers ? enableClose : false
            isRotateEnabled = showEditingHandlers ? enableRotate : false
            isFlipEnabled = showEditingHandlers ? enableFlip : false
            contentView?.layer.borderWidth = showEditingHandlers ? 1 : 0
            setNeedsLayout()
            layoutIfNeeded()
        }
    }
    
    /// Minimum value for the shorter side while resizing. Default value will be used if not set.
    private var _minimumSize: CGFloat = 0
    public var minimumSize: CGFloat {
        set {
            _minimumSize = max(newValue, defaultMinimumSize)
        }
        get {
            _minimumSize
        }
    }
    /// Color of the outline border. Default: brown color.
    private var _outlineBorderColor: UIColor = .clear
    public var outlineBorderColor: UIColor {
        set {
            _outlineBorderColor = newValue
            contentView?.layer.borderColor = _outlineBorderColor.cgColor
        }
        get {
            _outlineBorderColor
        }
    }
    /// A convenient property for you to store extra information.
    public var userInfo: Any?
    
    /**
     * Initialize a sticker view. This is the designated initializer.
     *
     * @param contentView The contentView inside the sticker view.
     *    You can access it via the `contentView` property.
     *
     * @return The sticker view.
     */
    public init(contentView: UIView) {
        defaultInset = 11
        defaultMinimumSize = 4 * defaultInset
        
        var frame = contentView.frame
        frame = CGRect(x: 0, y: 0, width: frame.size.width + defaultInset * 2, height: frame.size.height + defaultInset * 2)
        super.init(frame: frame)
        backgroundColor = .clear
        addGestureRecognizer(moveGesture)
        addGestureRecognizer(tapGesture)
        
        // Setup content view
        self.contentView = contentView
        contentView.center = CGRectGetCenter(bounds)
        contentView.isUserInteractionEnabled = false
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.layer.allowsEdgeAntialiasing = true
        addSubview(contentView)
        
        // Setup editing handlers
        setPosition(.topRight, forHandler: .close)
        addSubview(closeImageView)
        setPosition(.bottomRight, forHandler: .rotate)
        addSubview(rotateImageView)
        setPosition(.topLeft, forHandler: .flip)
        addSubview(flipImageView)
        
        showEditingHandlers = true
        enableClose = true
        enableRotate = true
        enableFlip = true
        
        minimumSize = defaultMinimumSize
        outlineBorderColor = .brown
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /**
     * Use image to customize each editing handler.
     * It is your responsibility to set image for every editing handler.
     *
     * @param image The image to be used.
     * @param handler The editing handler.
     */
    public func setImage(_ image: UIImage, forHandler handler: StickerViewHandler) {
        switch handler {
        case .close:
            closeImageView.image = image
        case .rotate:
            rotateImageView.image = image
        case .flip:
            flipImageView.image = image
        }
    }
    
    /**
     * Customize each editing handler's position.
     * If not set, default position will be used.
     * @note It is your responsibility not to set duplicated position.
     *
     * @param position The position for the handler.
     * @param handler The editing handler.
     */
    
    public func setPosition(_ position: StickerViewPosition, forHandler handler: StickerViewHandler) {
        let origin = contentView.frame.origin
        let size = contentView.frame.size
        
        let handlerView: UIImageView
        
        switch handler {
        case .close:
            handlerView = closeImageView
        case .rotate:
            handlerView = rotateImageView
        case .flip:
            handlerView = flipImageView
        }
        
        let handlerSize = handlerView.frame.size
        
        switch position {
        case .topLeft:
            handlerView.center = origin
            handlerView.autoresizingMask = [.flexibleRightMargin, .flexibleBottomMargin]
        case .topRight:
            handlerView.center = CGPoint(x: origin.x + size.width + handlerSize.width / 2, y: origin.y - handlerSize.height / 2)
            handlerView.autoresizingMask = [.flexibleLeftMargin, .flexibleBottomMargin]
        case .bottomLeft:
            handlerView.center = CGPoint(x: origin.x, y: origin.y + size.height)
            handlerView.autoresizingMask = [.flexibleRightMargin, .flexibleTopMargin]
        case .bottomRight:
            handlerView.center = CGPoint(x: origin.x + size.width, y: origin.y + size.height)
            handlerView.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin]
        }
        
        handlerView.tag = position.rawValue
    }
    
    /**
     * Customize handler's size
     *
     * @param size Handler's size
     */
    public func setHandlerSize(_ size: CGFloat) {
        guard size > 0 else { return }
        
        defaultInset = size / 2
        defaultMinimumSize = 4 * defaultInset
        minimumSize = max(minimumSize, defaultMinimumSize)
        
        let originalCenter = center
        let originalTransform = transform
        var frame = contentView.frame
        frame = CGRect(x: 0, y: 0, width: frame.size.width + defaultInset * 2, height: frame.size.height + defaultInset * 2)
        
        contentView.removeFromSuperview()
        
        transform = .identity
        self.frame = frame
        
        contentView.center = CGRectGetCenter(bounds)
        addSubview(contentView)
        sendSubviewToBack(contentView)
        
        let handlerFrame = CGRect(x: 0, y: 0, width: defaultInset * 2, height: defaultInset * 2)
        closeImageView.frame = handlerFrame
        setPosition(StickerViewPosition(rawValue: closeImageView.tag)!, forHandler: .close)
        rotateImageView.frame = handlerFrame
        setPosition(StickerViewPosition(rawValue: rotateImageView.tag)!, forHandler: .rotate)
        flipImageView.frame = handlerFrame
        setPosition(StickerViewPosition(rawValue: flipImageView.tag)!, forHandler: .flip)
        
        center = originalCenter
        transform = originalTransform
    }
    
    /**
     * Default value
     */
    private var defaultInset: CGFloat
    private var defaultMinimumSize: CGFloat
    
    /**
     * Variables for moving viewes
     */
    private var beginningPoint = CGPoint.zero
    private var beginningCenter = CGPoint.zero
    
    /**
     * Variables for rotating and resizing viewes
     */
    private var initialBounds = CGRect.zero
    private var initialDistance: CGFloat = 0
    private var deltaAngle: CGFloat = 0
    
    private lazy var moveGesture = {
        UIPanGestureRecognizer(target: self, action: #selector(handleMoveGesture(_:)))
    }()
    private lazy var rotateImageView: UIImageView = {
        let rotateImageView = UIImageView(frame: CGRect(x: 0, y: 0, width: defaultInset * 2, height: defaultInset * 2))
        rotateImageView.contentMode = .scaleAspectFit
        rotateImageView.backgroundColor = .clear
        rotateImageView.isUserInteractionEnabled = true
        rotateImageView.addGestureRecognizer(rotateGesture)
        return rotateImageView
    }()
    private lazy var rotateGesture = {
        UIPanGestureRecognizer(target: self, action: #selector(handleRotateGesture(_:)))
    }()
    private lazy var closeImageView: UIImageView = {
        let closeImageview = UIImageView(frame: CGRect(x: 0, y: 0, width: defaultInset * 2, height: defaultInset * 2))
        closeImageview.contentMode = .scaleAspectFit
        closeImageview.backgroundColor = .clear
        closeImageview.isUserInteractionEnabled = true
        closeImageview.addGestureRecognizer(closeGesture)
        return closeImageview
    }()
    private lazy var closeGesture = {
        UITapGestureRecognizer(target: self, action: #selector(handleCloseGesture(_:)))
    }()
    private lazy var flipImageView: UIImageView = {
        let flipImageView = UIImageView(frame: CGRect(x: 0, y: 0, width: defaultInset * 2, height: defaultInset * 2))
        flipImageView.contentMode = .scaleAspectFit
        flipImageView.backgroundColor = .clear
        flipImageView.isUserInteractionEnabled = true
        flipImageView.addGestureRecognizer(flipGesture)
        return flipImageView
    }()
    private lazy var flipGesture = {
        UITapGestureRecognizer(target: self, action: #selector(handleFlipGesture(_:)))
    }()
    private lazy var tapGesture = {
        UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
    }()
    // MARK: - Gesture Handlers
    @objc
    func handleMoveGesture(_ recognizer: UIPanGestureRecognizer) {
        let touchLocation = recognizer.location(in: superview)
        switch recognizer.state {
        case .began:
            beginningPoint = touchLocation
            beginningCenter = center
            delegate?.stickerViewDidBeginMoving(self)
        case .changed:
            center = CGPoint(x: beginningCenter.x + (touchLocation.x - beginningPoint.x), y: beginningCenter.y + (touchLocation.y - beginningPoint.y))
            delegate?.stickerViewDidChangeMoving(self)
        case .ended:
            center = CGPoint(x: beginningCenter.x + (touchLocation.x - beginningPoint.x), y: beginningCenter.y + (touchLocation.y - beginningPoint.y))
            delegate?.stickerViewDidEndMoving(self)
        default:
            break
        }
    }
    
    @objc
    func handleRotateGesture(_ recognizer: UIPanGestureRecognizer) {
        let touchLocation = recognizer.location(in: superview)
        
        switch recognizer.state {
        case .began:
            deltaAngle = atan2(touchLocation.y - center.y, touchLocation.x - center.x) - CGAffineTransformGetAngle(transform)
            initialBounds = bounds
            initialDistance = CGPointGetDistance(point1: center, point2: touchLocation)
            delegate?.stickerViewDidBeginRotating(self)
        case .changed:
            let angle = atan2(touchLocation.y - center.y, touchLocation.x - center.x)
            let angleDiff = deltaAngle - angle
            transform = CGAffineTransform(rotationAngle: -angleDiff)
            
            var scale = CGPointGetDistance(point1: center, point2: touchLocation) / initialDistance
            let minimumScale = minimumSize / min(initialBounds.size.width, initialBounds.size.height)
            scale = max(scale, minimumScale)
            let scaledBounds = CGRectScale(initialBounds, wScale: scale, hScale: scale)
            bounds = scaledBounds
            setNeedsDisplay()
            delegate?.stickerViewDidChangeRotating(self)
        case .ended:
            delegate?.stickerViewDidEndRotating(self)
        default:
            break
        }
    }
    
    @objc
    func handleCloseGesture(_ recognizer: UITapGestureRecognizer) {
        delegate?.stickerViewDidClose(self)
        removeFromSuperview()
    }
    
    @objc
    func handleFlipGesture(_ recognizer: UITapGestureRecognizer) {
        UIView.animate(withDuration: 0.3) {
            self.contentView.transform = self.contentView.transform.scaledBy(x: -1, y: 1)
        }
    }
    
    @objc
    func handleTapGesture(_ recognizer: UITapGestureRecognizer) {
        delegate?.stickerViewDidTap(self)
    }
    
    // MARK: - Private Methods
    private var isCloseEnabled: Bool = false {
        didSet {
            closeImageView.isHidden = !isCloseEnabled
            closeImageView.isUserInteractionEnabled = isCloseEnabled
        }
    }
    
    private var isRotateEnabled: Bool = false {
        didSet {
            rotateImageView.isHidden = !isRotateEnabled
            rotateImageView.isUserInteractionEnabled = isRotateEnabled
        }
    }
    
    private var isFlipEnabled: Bool = false {
        didSet {
            flipImageView.isHidden = !isFlipEnabled
            flipImageView.isUserInteractionEnabled = isFlipEnabled
        }
    }
    
//    open override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
//        print(#function)
//        for subview in subviews.reversed() {
//            let point = subview.convert(point, from: self)
//            if let result = subview.hitTest(point, with: event) {
//                switch result {
//                case closeImageView:
//                    handleCloseGesture(closeGesture)
//                    return result
//                default:
//                    break
//                }
//            }
//        }
//        return super.hitTest(point, with: event)
//    }
}

//extension StickerView: UIGestureRecognizerDelegate {
//    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
//}
