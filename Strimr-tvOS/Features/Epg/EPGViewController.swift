//
//  EPGViewController.swift
//  Strimr
//
//  Created by Vladimír Bárta on 28.04.2026.
//

import SwiftUI
import UIKit

class EPGViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    
    var collectionView: UICollectionView!
    let epgLayout = EPGAbsoluteLayout()

    let viewModel: LiveTVViewModel
    var onProgramSelected: ((Media, Media) -> Void)?
    var onProgramFocused: ((Media?, Media?) -> Void)?

    private var hasScrolledToCurrentTime = false

    @Binding var horizontalOffset: CGFloat
    @Binding var verticalOffset: CGFloat
        
    init(viewModel: LiveTVViewModel, horizontalOffset: Binding<CGFloat>, verticalOffset: Binding<CGFloat>) {
        self.viewModel = viewModel
        self._horizontalOffset = horizontalOffset
        self._verticalOffset = verticalOffset
        super.init(nibName: nil, bundle: nil)
    }
    
    // Tento init vyžaduje Swift pro případ načítání ze Storyboardu
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        epgLayout.epgDataSource = self

        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: epgLayout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self

        collectionView.isUserInteractionEnabled = true
        collectionView.remembersLastFocusedIndexPath = true

        collectionView.register(EPGCell.self, forCellWithReuseIdentifier: "EPGCell")

        view.addSubview(collectionView)

        collectionView.reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Spustíme načítání dnešních programů. Scroll na aktuální čas
        // provedeme až po prvním úspěšném reloadSections (viz loadHistoryData).
        loadInitialPrograms()
    }
    
    // MARK: - Synchronizace posunu
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        DispatchQueue.main.async {
            self.horizontalOffset = scrollView.contentOffset.x
            self.verticalOffset = scrollView.contentOffset.y
        }
        
        checkDataOnScroll(scrollView)
    }
    
    // Když dojde k pohybu fokusu, vyžádáme si od layoutu plynulý přepočet pozice
    func collectionView(_ collectionView: UICollectionView, didUpdateFocusIn context: UICollectionViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        if let nextIndexPath = context.nextFocusedIndexPath {
            collectionView.scrollToItem(at: nextIndexPath, at: .centeredHorizontally, animated: true)

            let channel = nextIndexPath.section < viewModel.channels.count
                ? viewModel.channels[nextIndexPath.section] : nil
            let program = channel.flatMap { viewModel.sequentialEPGByChannel[$0.id]?[nextIndexPath.item] }
            onProgramFocused?(program, channel)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, canFocusItemAt indexPath: IndexPath) -> Bool {
        return true
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.section < viewModel.channels.count else { return }
        let channel = viewModel.channels[indexPath.section]
        guard let program = viewModel.sequentialEPGByChannel[channel.id]?[indexPath.item] else { return }
        onProgramSelected?(program, channel)
    }
    
/*    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        // Řekne systému, že po načtení má hledat fokus uvnitř kolekce
        return [collectionView]
    }*/
    
    override var preferredFocusedView: UIView? {
        return collectionView
    }
    
    // MARK: - UICollectionViewDataSource
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return viewModel.channels.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard section < viewModel.channels.count else { return 0 }
        let channel = viewModel.channels[section]
        return viewModel.sequentialEPGByChannel[channel.id]?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EPGCell", for: indexPath) as? EPGCell else {
            return UICollectionViewCell()
        }

        let channel = viewModel.channels[indexPath.section]
        if let program = viewModel.sequentialEPGByChannel[channel.id]?[indexPath.item] {
            cell.configure(with: program)
        } else {
            cell.configurePlaceholder()
        }

        return cell
    }
    
    func scrollToCurrentTime(animated: Bool = false) {
        // 🔥 Donutíme kolekci, aby si vyžádala výpočet velikosti od layoutu (pokud má data)
        collectionView.layoutIfNeeded()
        
        // 1. Zjistíme X souřadnici pro aktuální čas
        let currentMinutesFromStart = Date().timeIntervalSince(epgLayout.timelineStartDate) / 60
        let targetX = CGFloat(currentMinutesFromStart) * epgLayout.pointsPerMinute
        
        // 2. Chceme, aby byl aktuální čas uprostřed obrazovky
        let halfScreenWidth = collectionView.bounds.width / 2
        let centeredX = targetX - halfScreenWidth
        
        // 3. Ošetříme okraje, abychom nescrollovali do záporných hodnot
        let maxOffsetX = max(0, collectionView.contentSize.width - collectionView.bounds.width)
        let clampedX = max(0, min(centeredX, maxOffsetX))
        
        // 4. Provedeme posun
        collectionView.setContentOffset(CGPoint(x: clampedX, y: collectionView.contentOffset.y), animated: animated)
    }
    
    
    func checkDataOnScroll(_ scrollView: UIScrollView) {
        let thresholdOffset = 120.0 * epgLayout.pointsPerMinute

        let visibleRect = CGRect(origin: scrollView.contentOffset, size: scrollView.bounds.size)
        let minX = visibleRect.minX - thresholdOffset
        let maxX = visibleRect.maxX + thresholdOffset

        let targetDates = getTargetDates(minX: minX, maxX: maxX)

        // Viditelné sekce vypočítáme z vertikálního offsetu, ne z indexPathsForVisibleItems.
        // Kanály bez načtených programů nemají žádné buňky, takže by je indexPathsForVisibleItems vynechalo.
        let rowTotal = epgLayout.rowHeight + epgLayout.rowSpacing
        let firstSection = max(0, Int(scrollView.contentOffset.y / rowTotal))
        let lastSection = min(
            collectionView.numberOfSections - 1,
            Int((scrollView.contentOffset.y + scrollView.bounds.height) / rowTotal)
        )
        guard firstSection <= lastSection else { return }

        for section in firstSection...lastSection {
            guard section < viewModel.channels.count else { continue }
            let channel = viewModel.channels[section]
            for date in targetDates {
                loadHistoryData(channel: channel, targetDate: date)
            }
        }
    }
    
    // MARK: - Pomocné metody

    /// Načte dnešní programy pro všechny kanály viditelné po prvním zobrazení EPG.
    private func loadInitialPrograms() {
        let today = Date()
        let channelCount = viewModel.channels.count
        guard channelCount > 0 else { return }

        // Odhadneme viditelný rozsah sekcí dle výšky view a řádku
        let rowTotal = epgLayout.rowHeight + epgLayout.rowSpacing
        let visibleRowCount = Int(ceil(view.bounds.height / rowTotal)) + 1
        let lastSection = min(channelCount - 1, visibleRowCount)

        for section in 0...lastSection {
            let channel = viewModel.channels[section]
            loadHistoryData(channel: channel, targetDate: today)
        }
    }

    /// Převede rozsah X souřadnic na pole půlnočních datumů (UTC), které do rozsahu spadají.
    func getTargetDates(minX: CGFloat, maxX: CGFloat) -> [Date] {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(abbreviation: "UTC")!

        let minDate = epgLayout.dateForXOffset(max(0, minX))
        let maxDate = epgLayout.dateForXOffset(maxX)

        var dates: [Date] = []
        var current = calendar.startOfDay(for: minDate)
        let end = calendar.startOfDay(for: maxDate)

        while current <= end {
            dates.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        return dates
    }

    // MARK: - Načtení historie (Zavolá se např. při scrollování doleva)
    
    func loadHistoryData(channel: Media, targetDate: Date) {
        viewModel.loadProgramsIfNeeded(for: channel, on: targetDate, completion: { [weak self] in
            guard let self else { return }
            guard let sectionIndex = self.viewModel.channels.firstIndex(where: { $0.id == channel.id }) else { return }

            let currentCount = self.collectionView.numberOfItems(inSection: sectionIndex)
            let newCount = self.viewModel.sequentialEPGByChannel[channel.id]?.count ?? 0

            if currentCount != newCount {
                // Počet položek se změnil (0 → 1000): reload sekce je nutný.
                UIView.performWithoutAnimation {
                    self.collectionView.reloadSections(IndexSet(integer: sectionIndex))
                }
                // Po prvním úspěšném načtení scrollneme na aktuální čas.
                // Teprve teď má layout nenulovou contentSize.
                if !self.hasScrolledToCurrentTime {
                    self.hasScrolledToCurrentTime = true
                    self.scrollToCurrentTime(animated: false)
                }
            } else {
                // Počet položek stejný, změnily se jen layout atributy (přibyly programy do dne).
                // invalidateLayout() fokus neresetuje.
                self.collectionView.collectionViewLayout.invalidateLayout()
            }
        })
    }
}
