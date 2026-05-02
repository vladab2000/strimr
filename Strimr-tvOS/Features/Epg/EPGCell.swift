//
//  EPGCell.swift
//  Strimr
//
//  Created by Vladimír Bárta on 26.04.2026.
//


import UIKit

class EPGCell: UICollectionViewCell {
    let titleLabel = UILabel()
    let timeLabel = UILabel()
    var programId: String?
    private(set) var isPlaceholder = false
    private var normalBackgroundColor: UIColor = UIColor(white: 0.2, alpha: 1)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = true
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupUI() {
        // Povolí nativní tvOS efekt "plovoucí karty" při zaměření (Focus)
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true
        contentView.backgroundColor = UIColor.darkGray
        

        // Setup Labelů
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .white
        
        timeLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        timeLabel.textColor = .lightGray
        
        // ZÁKAZ AUTO LAYOUTU 🚀
        // Prvkům vypneme automatické vazby, nastavíme je ručně přes souřadnice
        titleLabel.translatesAutoresizingMaskIntoConstraints = true
        timeLabel.translatesAutoresizingMaskIntoConstraints = true

        contentView.addSubview(titleLabel)
        contentView.addSubview(timeLabel)        
    }
        
    // 🚀 TATO METODA VŠE VYŘEŠÍ: Nastaví pozice labelů napevno podle velikosti buňky
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let width = contentView.bounds.width
        
        // Title label bude v horní polovině s okrajem 12 bodů
        titleLabel.frame = CGRect(x: 12, y: 15, width: width - 24, height: 30)
        
        // Time label bude ve spodní polovině
        timeLabel.frame = CGRect(x: 12, y: 50, width: width - 24, height: 25)
    }
    
    func configure(with program: Media, indexPath: IndexPath) {
        self.programId = program.id
        isPlaceholder = false
        titleLabel.text = "\(indexPath.row). \(indexPath.section) \(program.title)"

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        if let start = program.programStart, let end = program.programEnd {
            timeLabel.text = "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        }

        let now = Date()
        let isPast = (program.programStart ?? .distantFuture) < now
        normalBackgroundColor = isPast ? UIColor(white: 0.2, alpha: 1) : UIColor(white: 0.45, alpha: 1)
        contentView.backgroundColor = normalBackgroundColor
    }

    func configurePlaceholder() {
        programId = nil
        isPlaceholder = true
        titleLabel.text = nil
        timeLabel.text = nil
        contentView.backgroundColor = UIColor(white: 0.15, alpha: 1)
        contentView.layer.borderWidth = 0
    }

    override var canBecomeFocused: Bool {
        return !isPlaceholder
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        guard !isPlaceholder else { return }
        if self.isFocused {
            self.contentView.backgroundColor = .white
            self.titleLabel.textColor = .black
            self.timeLabel.textColor = .black
            self.transform = .identity
            self.layer.zPosition = 10
        } else {
            self.contentView.backgroundColor = self.normalBackgroundColor
            self.titleLabel.textColor = .white
            self.timeLabel.textColor = .lightGray
            self.transform = .identity
            self.layer.zPosition = 0
        }
    }
}
