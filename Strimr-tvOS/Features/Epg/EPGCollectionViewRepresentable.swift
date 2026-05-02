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

        if let date = scrollToDate {
            // Spustíme scroll jen jednou pro dané datum — koordinátor si pamatuje
            // naposledy zpracované datum mimo SwiftUI state, takže ho lze bezpečně
            // nastavit i uprostřed view update bez "Modifying state during view update".
            if date != context.coordinator.consumedScrollDate {
                context.coordinator.consumedScrollDate = date
                uiViewController.scrollToDate(date)
                DispatchQueue.main.async { scrollToDate = nil }
            }
        } else {
            // scrollToDate bylo vymazáno — resetujeme koordinátor pro příští výběr.
            context.coordinator.consumedScrollDate = nil
        }
    }
}
