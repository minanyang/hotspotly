import Foundation

/// The two status lights in the menu, matching the two lights on the logo's router.
public enum Light {
    case green, amber, red, off
}

extension Status {
    /// Green while keepalive pings come back, amber with loss or delay, red when the gateway stops
    /// answering, off when it never answers pings at all. Thresholds are a first guess; an iPhone
    /// may drop the odd ping on its own.
    public var connectionLight: Light {
        guard gateway != nil else { return .off }
        if gatewaySilent { return .red }
        if gatewayIgnoresPings { return .off }
        guard let loss = packetLoss else { return .off }
        if loss >= 0.15 || (latencyMs ?? 0) >= 150 { return .amber }
        return .green
    }

    /// Green while Hotspotly is doing its job, amber while something is relaxed or off target,
    /// off when paused or when there is nothing to do (AWDL left alone here, nothing pinned).
    public func protectionLight(_ config: Config) -> Light {
        let awdlHere = config.turnsOffAWDL(onHotspot: onHotspot)
        if config.paused || (!onHotspot && !awdlHere && onPin == nil) { return .off }
        if onPin == false || (awdlHere && !awdlDown) { return .amber }
        return .green
    }
}
