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
        /// Datum, pro které už byl scroll spuštěn — brání opakovanému volání
        /// při re-renderech způsobených ViewModel nebo focus změnami.
        var consumedScrollDate: Date? = nil
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
            uiViewController.present(picker, animated: true)
        } else {
            if let presented = uiViewController.presentedViewController, !presented.isBeingDismissed {
                presented.dismiss(animated: true)
            }
        }

        // Scroll na datum — koordinátor brání opakovanému volání při re-renderech.
        if let date = scrollToDate {
            if date != context.coordinator.consumedScrollDate {
                context.coordinator.consumedScrollDate = date
                uiViewController.scrollToDate(date)
                DispatchQueue.main.async { scrollToDate = nil }
            }
        } else {
            context.coordinator.consumedScrollDate = nil
        }
    }
}
