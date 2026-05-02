import UIKit
import SwiftUI

class TVOSDatePickerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var onDateSelected: ((Date) -> Void)?
    private let tableView = UITableView()
    private let dates = (0...6).compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: Date()) }
    private let activityIndicator = UIActivityIndicatorView(style: .large)

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 1. tvOS pozadí - Blur místo barvy
        setupBlurBackground()
        setupTableView()
        setupLoader()
    }

    private func setupBlurBackground() {
        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = view.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(blurView)
    }

    private func setupTableView() {
        // Na TV chceme tabulku vycentrovanou, ne přes celý displej
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        
        // tvOS specifické nastavení
        tableView.backgroundColor = .clear
        tableView.remembersLastFocusedIndexPath = true
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tableView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            tableView.widthAnchor.constraint(equalToConstant: 600), // Šířka menu na TV
            tableView.heightAnchor.constraint(equalToConstant: 600)
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

    // MARK: - TableView Logic
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dates.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        let formatter = DateFormatter()
        formatter.dateStyle = .long // Na TV je víc místa, můžeme použít delší formát
        
        cell.textLabel?.text = formatter.string(from: dates[indexPath.row])
        cell.textLabel?.textAlignment = .center
        cell.textLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        
        // Důležité pro tvOS: Vzhled při zaměření (focus)
        cell.selectionStyle = .none
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedDate = dates[indexPath.row]
        
        // Spustíme loader a schováme tabulku
        activityIndicator.startAnimating()
        tableView.alpha = 0.2
        tableView.isUserInteractionEnabled = false
        
        loadData(for: selectedDate) { [weak self] in
            self?.dismiss(animated: true) {
                self?.onDateSelected?(selectedDate)
            }
        }
    }

    func loadData(for date: Date, completion: @escaping () -> Void) {
        // Simulace asynchronního načítání
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { completion() }
    }
}

// MARK: - SwiftUI wrapper

struct DatePickerRepresentable: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onDateSelected: (Date) -> Void

    func makeUIViewController(context: Context) -> TVOSDatePickerViewController {
        let vc = TVOSDatePickerViewController()
        vc.onDateSelected = { [weak vc] date in
            _ = vc // already dismissed at this point
            isPresented = false
            onDateSelected(date)
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: TVOSDatePickerViewController, context: Context) {}
}
