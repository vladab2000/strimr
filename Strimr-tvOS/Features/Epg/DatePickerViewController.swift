import UIKit
import SwiftUI

// MARK: - TVOSDatePickerViewController

class TVOSDatePickerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    var onDateSelected: ((Date) -> Void)?
    var onDismiss: (() -> Void)?
    var loadDataForDate: ((Date, @escaping () -> Void) -> Void)?
    var initialDate: Date?

    private let card = UIView()
    private let tableView = UITableView()
    private let titleLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let dates = (0...6).compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: Date()) }
    
    private var hasSelectedDate = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        setupCard()
        setupLoader()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let row = initialRow {
            tableView.scrollToRow(at: IndexPath(row: row, section: 0), at: .middle, animated: false)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isBeingDismissed && !hasSelectedDate {
            onDismiss?()
        }
    }

    private var initialRow: Int? {
        guard let initialDate else { return nil }
        return dates.firstIndex { Calendar.current.isDate($0, inSameDayAs: initialDate) }
    }

    // MARK: - Layout

    private func setupCard() {
        // Blur pozadí karty
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = 20
        blur.layer.masksToBounds = true

        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.cornerRadius = 20
        card.layer.masksToBounds = true
        view.addSubview(card)
        card.addSubview(blur)

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            card.widthAnchor.constraint(equalToConstant: 700),
            card.heightAnchor.constraint(equalToConstant: 760),

            blur.topAnchor.constraint(equalTo: card.topAnchor),
            blur.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])

        // Nadpis
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Vyberte datum"
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.preferredFont(forTextStyle: .title2)
        titleLabel.textColor = .white
        card.addSubview(titleLabel)

        // Tabulka
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.backgroundColor = .clear
        tableView.remembersLastFocusedIndexPath = false
        card.addSubview(tableView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 30),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            tableView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
        ])
    }

    private func setupLoader() {
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // MARK: - Formátování

    private func label(for date: Date) -> String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let shortFormatter = DateFormatter()
        shortFormatter.locale = Locale(identifier: "cs_CZ")
        shortFormatter.dateFormat = "d. M."
        let shortDate = shortFormatter.string(from: date)

        if cal.isDate(date, inSameDayAs: today) { return "Dnes · \(shortDate)" }
        if let yesterday = cal.date(byAdding: .day, value: -1, to: today),
           cal.isDate(date, inSameDayAs: yesterday) { return "Včera · \(shortDate)" }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "cs_CZ")
        formatter.dateFormat = "EEEE d. M."
        return formatter.string(from: date).capitalized
    }

    // MARK: - UITableViewDataSource / Delegate

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        dates.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = label(for: dates[indexPath.row])
        cell.textLabel?.textAlignment = .center
        cell.textLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        cell.selectionStyle = .none
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedDate = dates[indexPath.row]
        hasSelectedDate = true
        activityIndicator.startAnimating()
        tableView.alpha = 0.2
        tableView.isUserInteractionEnabled = false
        loadData(for: selectedDate) { [weak self] in
            self?.dismiss(animated: true) {
                self?.onDateSelected?(selectedDate)
            }
        }
    }

    func indexPathForPreferredFocusedView(in tableView: UITableView) -> IndexPath? {
        guard let row = initialRow else { return nil }
        return IndexPath(row: row, section: 0)
    }

    func loadData(for date: Date, completion: @escaping () -> Void) {
        if let loader = loadDataForDate {
            loader(date, completion)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { completion() }
        }
    }
}

// MARK: - SwiftUI helper (neviditelný presenter)

/// Neviditelný UIViewControllerRepresentable, který prezentuje DatePicker přes UIKit
/// s modalPresentationStyle = .overCurrentContext — EPG zůstane viditelné v pozadí
/// a focus se přesune automaticky jako u každé UIKit prezentace.
struct DatePickerPresentationHelper: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var currentDate: Date
    var loadData: ((Date, @escaping () -> Void) -> Void)?
    var onDateSelected: (Date) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        return vc
    }

    func updateUIViewController(_ hostVC: UIViewController, context: Context) {
        if isPresented {
            guard hostVC.presentedViewController == nil else { return }
            let picker = TVOSDatePickerViewController()
            picker.initialDate = currentDate
            picker.loadDataForDate = loadData
            picker.modalPresentationStyle = .overFullScreen
            picker.modalTransitionStyle = .crossDissolve
            picker.onDateSelected = { date in
                isPresented = false
                onDateSelected(date)
            }
            picker.onDismiss = {
                isPresented = false
            }
            hostVC.present(picker, animated: false)
        } else {
            if let presented = hostVC.presentedViewController, !presented.isBeingDismissed {
                presented.dismiss(animated: false)
            }
        }
    }
}
