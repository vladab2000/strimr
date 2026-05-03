//
//  EPGCollectionViewRepresentable.swift
//  Strimr
//
//  Created by Vladimír Bárta on 26.04.2026.
//

import SwiftUI
import OSLog

struct EPGCollectionViewRepresentable: UIViewControllerRepresentable {

    let viewModel: LiveTVViewModel
    var onProgramSelected: ((Media, Media) -> Void)?
    var onProgramFocused: ((Media?, Media?) -> Void)?

    @Binding var horizontalOffset: CGFloat
    @Binding var verticalOffset: CGFloat
    @Binding var scrollToDate: Date?
    @Binding var showDatePicker: Bool
    var epgViewingDate: Date
    var loadData: ((Date, @escaping () -> Void) -> Void)?
    var onDateSelected: (Date) -> Void

    // MARK: - Coordinator

    class Coordinator {
        /// True po dobu od spuštění scrollToDate až po vymazání scrollToDate binding.
        /// Brání opakovanému scrollování při re-renderech způsobených focus nebo ViewModel změnami.
        var isScrollPending = false
        /// True jen tehdy, když jsme picker sami prezentovali — brání dismiss
        /// jakéhokoliv jiného presentedViewController (např. přehrávače).
        var hasPresented = false
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - UIViewControllerRepresentable

    func makeUIViewController(context: Context) -> EPGViewController {
        let controller = EPGViewController(
            viewModel: viewModel,
            horizontalOffset: $horizontalOffset,
            verticalOffset: $verticalOffset
        )
        controller.onProgramSelected = onProgramSelected
        controller.onProgramFocused = onProgramFocused
        return controller
    }

    func updateUIViewController(_ uiViewController: EPGViewController, context: Context) {
        uiViewController.onProgramSelected = onProgramSelected
        uiViewController.onProgramFocused = onProgramFocused

        // DatePicker — EPGViewController je prezentující VC, takže po zavření
        // focus přirozeně vrátí přes jeho preferredFocusEnvironments.
        if showDatePicker {
            guard uiViewController.presentedViewController == nil else { return }
            context.coordinator.hasPresented = true
            let picker = TVOSDatePickerViewController()
            picker.initialDate = epgViewingDate
            picker.loadDataForDate = loadData
            picker.modalPresentationStyle = .overFullScreen
            picker.modalTransitionStyle = .crossDissolve
            picker.onDateSelected = { date in
                DispatchQueue.main.async {
                    showDatePicker = false
                    onDateSelected(date)
                }
            }
            picker.onDismiss = {
                DispatchQueue.main.async { showDatePicker = false }
            }
            uiViewController.present(picker, animated: false)
        } else if context.coordinator.hasPresented {
            context.coordinator.hasPresented = false
            if let presented = uiViewController.presentedViewController, !presented.isBeingDismissed {
                presented.dismiss(animated: true)
            }
        }

        // Scroll na datum — scrollToDate(date) se volá odloženě, aby neběželo uvnitř
        // SwiftUI render cyklu. reloadData() uvnitř scrollToDate totiž nutí UIKit layout,
        // který zpětně spouští SwiftUI render → AttributeGraph cycle.
        // isScrollPending se nastaví synchronně, takže mezilehlé re-rendery scroll přeskočí.
        if let date = scrollToDate, !context.coordinator.isScrollPending {
            let coordinator = context.coordinator
            coordinator.isScrollPending = true
            DispatchQueue.main.async {
                uiViewController.scrollToDate(date)
                scrollToDate = nil
                coordinator.isScrollPending = false
            }
        }
    }
}
