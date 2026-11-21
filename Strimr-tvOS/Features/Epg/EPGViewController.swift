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
    var onProgramLongPressed: ((Media, Media) -> Void)?

    private var hasScrolledToCurrentTime = false

    /// Pořad podle kanálu a začátku vysílání. Index pořadu v řadě kanálu není stálý — posune se, když se
    /// dočte dřívější den (např. po odrolování o několik dní zpět a sjetí na další kanály) nebo když se
    /// po uspání změní dnešní den. Fokus podle indexu by pak přeskočil na pořad o den vedle.
    private struct ProgramKey: Equatable {
        let channelId: String
        let start: Date
    }

    /// Kam má jít fokus po programovém scrollu (scrollToDate)
    private var focusTarget: ProgramKey? = nil
    private var lastFocused: ProgramKey? = nil
    /// Po probuzení: kanál, na kterém má fokus přejít na právě vysílaný pořad, až budou programy načtené
    private var pendingNowFocusChannelId: String?

    private var indexPathToFocus: IndexPath? { indexPath(for: focusTarget) }
    private var lastFocusedIndexPath: IndexPath? { indexPath(for: lastFocused) }

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
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self

        collectionView.isScrollEnabled = false
        collectionView.isUserInteractionEnabled = true
        collectionView.remembersLastFocusedIndexPath = false

        collectionView.register(EPGCell.self, forCellWithReuseIdentifier: "EPGCell")

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.8
        collectionView.addGestureRecognizer(longPress)

        view.addSubview(collectionView)

        collectionView.reloadData()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionView.frame = view.bounds
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Spustíme načítání dnešních programů. Scroll na aktuální čas
        // provedeme až po prvním úspěšném reloadSections (viz loadHistoryData).
        loadInitialPrograms()
    }
    
    // MARK: - Long press
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began,
              let indexPath = lastFocusedIndexPath,
              indexPath.section < viewModel.channels.count
        else { return }
        let channel = viewModel.channels[indexPath.section]
        guard let program = (collectionView.cellForItem(at: indexPath) as? EPGCell)?.program
                ?? viewModel.sequentialEPGByChannel[channel.id]?[indexPath.item] else { return }
        onProgramLongPressed?(program, channel)
    }

    // MARK: - Synchronizace posunu
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let newX = scrollView.contentOffset.x
        let newY = scrollView.contentOffset.y
        DispatchQueue.main.async {
            if self.horizontalOffset != newX { self.horizontalOffset = newX }
            if self.verticalOffset != newY { self.verticalOffset = newY }
        }
        checkDataOnScroll(scrollView)
    }
    
    // Když dojde ke změně fokusu, provedu případně vlastní rolování a zavolám onProgramFocused
    func collectionView(_ collectionView: UICollectionView, didUpdateFocusIn context: UICollectionViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        if let nextIndexPath = context.nextFocusedIndexPath {

            // Pokud focus dorazil na cílovou buňku z programatického scrollu, neuvolňujeme
            // scrollToItem — pozici viewportu nastaví setContentOffset ve scrollToDate.
            // Zavoláme scrollToItem pouze při přirozeném pohybu focusu uživatelem.
            let wasTargeted = nextIndexPath == self.indexPathToFocus
            if wasTargeted {
                self.focusTarget = nil
            } else if let frame = collectionView.layoutAttributesForItem(at: nextIndexPath)?.frame {
                let bounds = collectionView.bounds
                var scrollPosition: UICollectionView.ScrollPosition = [.centeredVertically]
                if frame.width > bounds.width {
                    scrollPosition.insert(.left)
                } else if frame.minX < bounds.minX || frame.maxX > bounds.maxX {
                    scrollPosition.insert(.centeredHorizontally)
                }
                collectionView.scrollToItem(at: nextIndexPath, at: scrollPosition, animated: false)
            }

            // Pořad z buňky (zobrazený), ne z dat podle indexu — data mohla být mezitím přepočítaná
            let channel = nextIndexPath.section < viewModel.channels.count
                ? viewModel.channels[nextIndexPath.section] : nil
            let program = (context.nextFocusedItem as? EPGCell)?.program
                ?? channel.flatMap { viewModel.sequentialEPGByChannel[$0.id]?[nextIndexPath.item] }
            if let channel, let start = program?.programStart {
                lastFocused = ProgramKey(channelId: channel.id, start: start)
                AppStateStore.lastChannelId = channel.id
                AppStateStore.lastProgramStart = start
            }
            onProgramFocused?(program, channel)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.section < viewModel.channels.count else { return }
        let channel = viewModel.channels[indexPath.section]
        guard let program = (collectionView.cellForItem(at: indexPath) as? EPGCell)?.program
                ?? viewModel.sequentialEPGByChannel[channel.id]?[indexPath.item] else { return }
        onProgramSelected?(program, channel)
    }
    
    func indexPathForPreferredFocusedView(in collectionView: UICollectionView) -> IndexPath? {
        return self.indexPathToFocus ?? self.lastFocusedIndexPath
    }

    // Pokud víme přesně, kam má jít focus (po scrollToDate), vrátíme přímo buňku.
    // To je spolehlivější než indexPathForPreferredFocusedView, který tvOS někdy ignoruje.
    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        if let indexPath = indexPathToFocus ?? lastFocusedIndexPath,
           let cell = collectionView.cellForItem(at: indexPath) {
            return [cell]
        }
        return [collectionView]
    }
    
/*    func collectionView(_ collectionView: UICollectionView, canFocusItemAt indexPath: IndexPath) -> Bool {
        return true // Např. True
    }
    
    override func shouldUpdateFocus(in context: UIFocusUpdateContext) -> Bool {
        return true
    }*/
    
    // MARK: - UICollectionViewDataSource
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return viewModel.channels.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard section < viewModel.channels.count else { return 0 }
        let channel = viewModel.channels[section]
        let count = viewModel.sequentialEPGByChannel[channel.id]?.count ?? 0
        return count
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
    
    func scrollToDate(_ date: Date, animated: Bool = false) {
        let channelCount = viewModel.channels.count
        guard channelCount > 0 else { return }

        if let focusedIndexPath = lastFocusedIndexPath {

            let channel = viewModel.channels[focusedIndexPath.section]

            if let programs = viewModel.sequentialEPGByChannel[channel.id] {
                if let programIndex = programs.firstIndex(where: { ($0?.programStart ?? Date()) <= date && ($0?.programEnd ?? Date()) >= date }) {

                    let newIndexPath = IndexPath(item: programIndex, section: focusedIndexPath.section)
                    focusTarget = programKey(for: newIndexPath)

                    // Synchronizace CollectionView s ViewModelem — DatePicker načetl nová data,
                    // ale CollectionView o nich nevědí. Bez reloadData by checkDataOnScroll zavolal
                    // reloadSections a přesunul focus na sekci 0.
                    UIView.performWithoutAnimation {
                        collectionView.reloadData()
                    }

                    collectionView.scrollToItem(at: newIndexPath, at: [.centeredVertically, .centeredHorizontally], animated: false)
                    collectionView.layoutIfNeeded()
                }
            }
        }

        // Cells jsou nyní viditelné — preferredFocusEnvironments vrátí přímý odkaz na buňku
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.setNeedsFocusUpdate()
            self.updateFocusIfNeeded()
        }
    }

    /// Přepočítá počátek časové osy layoutu a provede reload.
    /// Volá se po probuzení Apple TV, kdy se mohl změnit den.
    func refreshTimeline() {
        epgLayout.refreshTimelineStartDate()
        collectionView.collectionViewLayout.invalidateLayout()
        UIView.performWithoutAnimation {
            collectionView.reloadData()
        }

        // Fokus zůstane na pořadu, který ho měl před uspáním. Po změně dne jsou programy zahozené,
        // proto se pořad nejdřív znovu načte (restoreFocus).
        if let key = lastFocused, isInTimeline(key.start) {
            restoreFocus(key)
            return
        }

        // Pořad už z časové osy vypadl (starší než 7 dní) — právě vysílaný pořad stejného kanálu
        pendingNowFocusChannelId = lastFocused?.channelId
        applyPendingNowFocus()

        scrollToCurrentTime(animated: false)
        // Načte programy viditelné oblasti (po změně dne jsou zahozené)
        checkDataOnScroll(collectionView)

        DispatchQueue.main.async { [weak self] in
            self?.setNeedsFocusUpdate()
            self?.updateFocusIfNeeded()
        }
    }

    /// Načte programy dne pořadu, odroluje na něj a dá mu fokus. Když pořad v datech není
    /// (program se mezitím změnil), dostane fokus právě vysílaný pořad stejného kanálu.
    private func restoreFocus(_ key: ProgramKey) {
        guard let channel = viewModel.channels.first(where: { $0.id == key.channelId }) else {
            scrollToCurrentTime(animated: false)
            checkDataOnScroll(collectionView)
            return
        }

        // Pořad je v datech pod svým UTC dnem nebo dnem před ním (vysílací den začíná večer)
        var utcCal = Calendar.current
        utcCal.timeZone = TimeZone(abbreviation: "UTC")!
        let day = utcCal.startOfDay(for: key.start)
        let previousDay = utcCal.date(byAdding: .day, value: -1, to: day)!

        let group = DispatchGroup()
        for date in [day, previousDay] {
            group.enter()
            loadHistoryData(channel: channel, targetDate: date) { group.leave() }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            UIView.performWithoutAnimation {
                self.collectionView.reloadData()
            }
            self.collectionView.layoutIfNeeded()

            if let indexPath = self.indexPath(for: key) {
                self.lastFocused = key
                self.focusTarget = key
                self.scrollToProgram(at: indexPath)
            } else {
                self.pendingNowFocusChannelId = key.channelId
                self.applyPendingNowFocus()
                self.scrollToCurrentTime(animated: false)
            }
            // Načte programy okolí (ostatní kanály v zobrazené oblasti)
            self.checkDataOnScroll(self.collectionView)

            DispatchQueue.main.async {
                self.setNeedsFocusUpdate()
                self.updateFocusIfNeeded()
            }
        }
    }

    /// Odroluje tak, aby byl pořad uprostřed (dlouhý pořad začátkem vlevo)
    private func scrollToProgram(at indexPath: IndexPath) {
        var position: UICollectionView.ScrollPosition = [.centeredVertically]
        if let frame = collectionView.layoutAttributesForItem(at: indexPath)?.frame,
           frame.width > collectionView.bounds.width {
            position.insert(.left)
        } else {
            position.insert(.centeredHorizontally)
        }
        collectionView.scrollToItem(at: indexPath, at: position, animated: false)
        collectionView.layoutIfNeeded()
    }

    private func isInTimeline(_ date: Date) -> Bool {
        date >= epgLayout.timelineStartDate && date <= Date().addingTimeInterval(7 * 24 * 3600)
    }

    private func applyPendingNowFocus() {
        guard let channelId = pendingNowFocusChannelId,
              let now = viewModel.sequentialEPGByChannel[channelId]?.lazy.compactMap({ $0 }).first(where: {
                  guard let start = $0.programStart, let end = $0.programEnd else { return false }
                  return start <= Date() && end > Date()
              }),
              let start = now.programStart else { return }
        let key = ProgramKey(channelId: channelId, start: start)
        lastFocused = key
        focusTarget = key
        pendingNowFocusChannelId = nil
    }

    func scrollToCurrentTime(animated: Bool = false) {
        collectionView.layoutIfNeeded()
        let nowUTC = Date()
        let targetX = epgLayout.xOffsetForDate(nowUTC) - EPGConstants.pointsPerMinute * 30
        collectionView.setContentOffset(CGPoint(x: targetX, y: collectionView.contentOffset.y), animated: animated)
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

        let group = DispatchGroup()
        for section in firstSection...lastSection {
            guard section < viewModel.channels.count else { continue }
            let channel = viewModel.channels[section]
            for date in targetDates {
                group.enter()
                loadHistoryData(channel: channel, targetDate: date) { group.leave() }
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self else { return }

            applyPendingNowFocus()
            UIView.performWithoutAnimation {
                self.collectionView.reloadData()
                self.setNeedsFocusUpdate()
                self.updateFocusIfNeeded()
            }

        }
    }
    
    // MARK: - Pomocné metody

    private func programKey(for indexPath: IndexPath) -> ProgramKey? {
        guard indexPath.section < viewModel.channels.count else { return nil }
        let channelId = viewModel.channels[indexPath.section].id
        guard let programs = viewModel.sequentialEPGByChannel[channelId],
              indexPath.item < programs.count,
              let start = programs[indexPath.item]?.programStart else { return nil }
        return ProgramKey(channelId: channelId, start: start)
    }

    /// Aktuální index pořadu (po dočtení dalších dnů může být jiný než při uložení)
    private func indexPath(for key: ProgramKey?) -> IndexPath? {
        guard let key,
              let section = viewModel.channels.firstIndex(where: { $0.id == key.channelId }),
              let item = viewModel.sequentialEPGByChannel[key.channelId]?.firstIndex(where: { $0?.programStart == key.start }),
              section < collectionView.numberOfSections,
              item < collectionView.numberOfItems(inSection: section) else { return nil }
        return IndexPath(item: item, section: section)
    }

    /// Načte dnešní programy pro všechny kanály viditelné po prvním zobrazení EPG,
    /// a až po jejich načtení provede jednorázový scroll na aktuální čas.
    private func loadInitialPrograms() {
        let today = Date()
        let channelCount = viewModel.channels.count
        guard channelCount > 0 else { return }

        let rowTotal = epgLayout.rowHeight + epgLayout.rowSpacing
        let visibleRowCount = Int(ceil(view.bounds.height / rowTotal)) + 1

        // Po novém spuštění se EPG vrátí na kanál z minula (řádek nahoře, fokus na právě vysílaném pořadu)
        let restoreSection = hasScrolledToCurrentTime ? nil : AppStateStore.lastChannelId.flatMap { id in
            viewModel.channels.firstIndex { $0.id == id }
        }
        // …a je-li uložený i pořad, který byl s fokusem (Apple TV aplikaci ve spánku často ukončí), tak na něj
        let restoreProgram: ProgramKey? = restoreSection.flatMap { section in
            guard let start = AppStateStore.lastProgramStart, isInTimeline(start) else { return nil }
            return ProgramKey(channelId: viewModel.channels[section].id, start: start)
        }
        let firstSection = restoreSection ?? 0
        let lastSection = min(channelCount - 1, firstSection + visibleRowCount)

        // Načítáme dnešní UTC den i včerejší UTC den: česká vysílací den začíná ~22:00 CEST
        // (20:00 UTC) a pokrývá celé odpoledne/večer lokálního dne. Programy z tohoto
        // vysílacího dne jsou v API pod klíčem D-1 UTC, ne D UTC.
        var utcCal = Calendar.current
        utcCal.timeZone = TimeZone(abbreviation: "UTC")!
        let yesterday = utcCal.date(byAdding: .day, value: -1, to: today)!

        let group = DispatchGroup()
        for section in firstSection...lastSection {
            let channel = viewModel.channels[section]
            group.enter()
            loadHistoryData(channel: channel, targetDate: today) { group.leave() }
            group.enter()
            loadHistoryData(channel: channel, targetDate: yesterday) { group.leave() }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            UIView.performWithoutAnimation {
                self.collectionView.reloadData()
                self.setNeedsFocusUpdate()
                self.updateFocusIfNeeded()
            }
            
            guard !self.hasScrolledToCurrentTime else { return }
            self.hasScrolledToCurrentTime = true

            if let restoreProgram {
                self.restoreFocus(restoreProgram)
                return
            }
            if let restoreSection {
                let maxY = max(0, CGFloat(channelCount) * rowTotal - self.collectionView.bounds.height)
                let y = min(CGFloat(restoreSection) * rowTotal, maxY)
                self.collectionView.setContentOffset(CGPoint(x: self.collectionView.contentOffset.x, y: y), animated: false)
                self.pendingNowFocusChannelId = self.viewModel.channels[restoreSection].id
                self.applyPendingNowFocus()
            }
            self.scrollToCurrentTime(animated: false)

            DispatchQueue.main.async {
                self.setNeedsFocusUpdate()
                self.updateFocusIfNeeded()
            }
        }
    }

    /// Převede rozsah X souřadnic na pole půlnočních datumů (UTC), které do rozsahu spadají.
    /// Zahrnuje vždy i den před prvním viditelným dnem, protože česká vysílací den
    /// začíná ~22:00 CEST (20:00 UTC) a odpolední programy jsou v API pod D-1 UTC.
    func getTargetDates(minX: CGFloat, maxX: CGFloat) -> [Date] {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(abbreviation: "UTC")!

        let minDate = epgLayout.dateForXOffset(max(0, minX))
        let maxDate = epgLayout.dateForXOffset(maxX)

        var dates: [Date] = []
        // Začínáme den před minDate — každý UTC den D závisí na API datech pro D a D-1.
        var current = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: minDate))!
        let end = calendar.startOfDay(for: maxDate)

        while current <= end {
            dates.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        return dates
    }

    // MARK: - Načtení historie (Zavolá se např. při scrollování doleva)
    
    func loadHistoryData(channel: Media, targetDate: Date, completion: (() -> Void)? = nil) {
        // Mřížka se překreslí najednou, až se načtou všechny dny (checkDataOnScroll, loadInitialPrograms)
        viewModel.loadProgramsIfNeeded(for: channel, on: targetDate) { _ in completion?() }
    }
}
