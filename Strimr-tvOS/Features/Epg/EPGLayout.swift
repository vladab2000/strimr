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
    // Fixní počátek osy: půlnoc UTC 7 dní zpět (shodné s výpočtem v timelineLabel)
    var timelineStartDate: Date = {
        var cal = Calendar.current
        cal.timeZone = TimeZone(abbreviation: "UTC")!
        let sevenDaysAgo = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return cal.startOfDay(for: sevenDaysAgo)
    }()
    
    let pointsPerMinute = EPGConstants.pointsPerMinute
    let rowHeight = EPGConstants.rowHeight
    let rowSpacing = EPGConstants.rowSpacing
    let cellSpacing = EPGConstants.cellSpacing
    
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
                let width = max(CGFloat(durationMinutes) * pointsPerMinute - cellSpacing, 1)

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
