//
//  EPGLayout.swift
//  Strimr
//
//  Created by Vladimír Bárta on 26.04.2026.
//

import UIKit
import OSLog

class EPGAbsoluteLayout: UICollectionViewLayout {
    
    // MARK: - Konfigurace
    // Fixní počátek osy (např. 7 dní zpět od prvního spuštění)
    var timelineStartDate: Date = Date().addingTimeInterval(-7 * 24 * 60 * 60)
    
    let pointsPerMinute: CGFloat = 15.0
    let rowHeight: CGFloat = 80.0
    let rowSpacing: CGFloat = 4.0
    
    // Cache pro uchování pozic buněk
    private var layoutCache: [IndexPath: UICollectionViewLayoutAttributes] = [:]
    private var contentSize: CGSize = .zero
        
    weak var epgDataSource: EPGViewController?
    
    override func prepare() {
        super.prepare()

        guard let collectionView = collectionView,
              let dataSource = epgDataSource else { return }

        let channels = dataSource.viewModel.channels
        let sequentialEPG = dataSource.viewModel.sequentialEPGByChannel

        layoutCache.removeAll()
        var maxRightEdge: CGFloat = 0

        let numberOfSections = collectionView.numberOfSections

        for section in 0..<numberOfSections {
            let channel = channels[section]
            guard let programs = sequentialEPG[channel.id] else { continue }

            let yPosition = CGFloat(section) * (rowHeight + rowSpacing)

            for item in 0..<programs.count {
                guard let program = programs[item],
                      let start = program.programStart,
                      let end = program.programEnd else { continue }

                let minutesFromStart = start.timeIntervalSince(timelineStartDate) / 60
                let xPosition = CGFloat(minutesFromStart) * pointsPerMinute
                let durationMinutes = end.timeIntervalSince(start) / 60
                let width = max(CGFloat(durationMinutes) * pointsPerMinute, 1)

                let attributes = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: item, section: section))
                attributes.frame = CGRect(x: xPosition, y: yPosition, width: width, height: rowHeight)
                layoutCache[IndexPath(item: item, section: section)] = attributes
                maxRightEdge = max(maxRightEdge, xPosition + width)
            }
        }

        let totalHeight = CGFloat(numberOfSections) * (rowHeight + rowSpacing)
        contentSize = CGSize(width: maxRightEdge, height: totalHeight)
    }
    
    // Tato metoda vrací cílový posun (offset) mřížky po změně fokusu
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        guard let collectionView = collectionView else { return proposedContentOffset }
        
        // Zjistíme, která buňka má aktuálně fokus
        guard let focusedCell = collectionView.window?.windowScene?.focusSystem?.focusedItem as? UICollectionViewCell,
              let focusedIndexPath = collectionView.indexPath(for: focusedCell),
              let attributes = layoutAttributesForItem(at: focusedIndexPath) else {
            return proposedContentOffset
        }
        
        // Chceme, aby byl označený pořad vycentrovaný na střed obrazovky (na ose X)
        let collectionViewWidth = collectionView.bounds.width
        let targetX = attributes.frame.origin.x - (collectionViewWidth / 2) + (attributes.frame.width / 2)
        
        // Ošetříme okraje (aby nešlo scrollovat do prázdna před začátek EPG)
        let maxOffsetX = max(0, collectionView.contentSize.width - collectionViewWidth)
        let clampedX = max(0, min(targetX, maxOffsetX))
        
        // Vertikální posun necháme navržený systémem, změníme jen osu X
        return CGPoint(x: clampedX, y: proposedContentOffset.y)
    }
    
    override var collectionViewContentSize: CGSize {
        return contentSize
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        // Vracíme pouze ty prvky, které jsou zrovna viditelné na obrazovce
        return layoutCache.values.filter { $0.frame.intersects(rect) }
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return layoutCache[indexPath]
    }
    
    // Důležité: Kolekce se nebude dotazovat na změnu pozic při dotažení dat, pokud se nezměnil viditelný obdélník
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return collectionView?.bounds.size != newBounds.size
    }
    
    // Převod X souřadnice na konkrétní datum
    func dateForXOffset(_ xOffset: CGFloat) -> Date {
        let minutes = xOffset / pointsPerMinute
        return timelineStartDate.addingTimeInterval(TimeInterval(minutes * 60))
    }
    
    // Převod data na X souřadnici
    func xOffsetForDate(_ date: Date) -> CGFloat {
        let minutes = date.timeIntervalSince(timelineStartDate) / 60
        return CGFloat(minutes) * pointsPerMinute
    }
    
}


/*class EPGLayout: UICollectionViewLayout {
    
    weak var epgDataSource: EPGCollectionViewDataSource?

    // Definice rozměrů mřížky
    let hourWidth: CGFloat = 400.0
    let rowHeight: CGFloat = 100.0
    let spacing: CGFloat = 4.0
    
    private var cache: [IndexPath: UICollectionViewLayoutAttributes] = [:]
    private var contentSize: CGSize = .zero
        
    private var logger = Logger(subsystem: "com.strimr.app", category: "EPG-Grid")
    
    override func prepare() {
        cache.removeAll()
        
        guard let _ = collectionView,
              let dataSource = epgDataSource else { return }
        
        let channels = dataSource.viewModel.channels
        let programsByChannel = dataSource.viewModel.programsByChannel
        
        logger.debug("Prepara EPGLayout")
        
        // 1. Nastavíme nulu naší časové osy (půlnoc před 7 dny) 🚀
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(abbreviation: "UTC")!
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let epgStartDate = calendar.startOfDay(for: sevenDaysAgo)

        var maxTotalWidth: CGFloat = 0
        
        // Procházíme všechny kanály (Sekce v UICollectionView)
        for channelIndex in 0..<channels.count {
            let channel = channels[channelIndex]
            
            if let programs = programsByChannel[channel.id], !programs.isEmpty {
                // Vykreslení reálných programů
                for programIndex in 0..<programs.count {
                    let program = programs[programIndex]
                    let indexPath = IndexPath(item: programIndex, section: channelIndex)
                    
                    // 2. Výpočet X pozice podle času začátku 🚀
                    let hoursFromStart = program.programStart!.timeIntervalSince(epgStartDate) / 3600.0
                    let xPosition = CGFloat(hoursFromStart) * hourWidth
                    
                    // Výpočet šířky na základě času
                    let durationInHours = program.programEnd!.timeIntervalSince(program.programStart!) / 3600.0
                    let width = max(CGFloat(durationInHours) * hourWidth - spacing, 10)
                    
                    let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
                    attributes.frame = CGRect(
                        x: xPosition,
                        y: CGFloat(channelIndex) * (rowHeight + spacing),
                        width: width,
                        height: rowHeight
                    )
                    
                    cache[indexPath] = attributes
                    maxTotalWidth = max(maxTotalWidth, xPosition + width)
                }
            } else {
                // ZÁCHRANNÁ MŘÍŽKA: Pokud data pro kanál nejsou stažena,
                // vytvoříme fiktivní buňku přes celý den (např. 24h), aby se mřížka nerozpadla.
                let indexPath = IndexPath(item: 0, section: channelIndex)
                let hoursFromStart = Date().timeIntervalSince(epgStartDate) / 3600.0
                let xPosition = CGFloat(hoursFromStart) * hourWidth
                let fallbackWidth = 24.0 * hourWidth
                
                let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
                attributes.frame = CGRect(
                    x: xPosition,
                    y: CGFloat(channelIndex) * (rowHeight + spacing),
                    width: fallbackWidth,
                    height: rowHeight
                )
                
                cache[indexPath] = attributes
                maxTotalWidth = max(maxTotalWidth, xPosition + fallbackWidth)
            }
        }
        
        // Nastavení celkové velikosti scrollu
        contentSize = CGSize(
            width: maxTotalWidth,
            height: CGFloat(channels.count) * (rowHeight + spacing)
        )
    }
    
    override var collectionViewContentSize: CGSize {
        return contentSize
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        // Vrátíme všechny buňky z cache bez ohledu na doručený rect
        logger.debug("layoutAttributesForElements EPGLayout")

        return cache.values.filter { attributes in
            return attributes.frame.intersects(rect)
        }
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return cache[indexPath]
    }
}
*/
