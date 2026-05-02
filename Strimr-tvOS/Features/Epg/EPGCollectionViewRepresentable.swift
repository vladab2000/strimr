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
            uiViewController.scrollToDate(date)
            DispatchQueue.main.async { scrollToDate = nil }
        }
    }
}
