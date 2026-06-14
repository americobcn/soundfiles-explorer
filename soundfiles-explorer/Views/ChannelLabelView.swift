//
//  ChannelLabelView.swift
//  soundfiles-explorer
//
//  Created by Americo Cot on 14/6/26.
//

import Cocoa

/// A channel label with a speaker toggle button (bottom-right) to enable/disable that channel's audio.
final class ChannelLabelView: NSView {

    // MARK: - Public Properties

    let channelIndex: Int
    var onToggle: ((Int) -> Void)?

    var isChannelEnabled: Bool {
        didSet { refreshIcon() }
    }

    // MARK: - Private Properties

    private let nameLabel: NSTextField
    private let speakerButton: NSButton
    private let enabledColor: NSColor

    // MARK: - Init

    init(channelIndex: Int, channelName: String, channelColor: NSColor, isEnabled: Bool) {
        self.channelIndex = channelIndex
        self.enabledColor = channelColor
        self.isChannelEnabled = isEnabled
        self.nameLabel = NSTextField(labelWithString: channelName)
        self.speakerButton = NSButton()

        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        nameLabel.textColor = NSColor.white
        nameLabel.alignment = .left
        nameLabel.isEditable = false
        nameLabel.isBordered = true
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nameLabel)

        speakerButton.translatesAutoresizingMaskIntoConstraints = false
        speakerButton.isBordered = false
        speakerButton.imagePosition = .imageOnly
        speakerButton.target = self
        speakerButton.action = #selector(speakerTapped)
        addSubview(speakerButton)

        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: topAnchor),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            nameLabel.bottomAnchor.constraint(equalTo: bottomAnchor),

            speakerButton.widthAnchor.constraint(equalToConstant: 16),
            speakerButton.heightAnchor.constraint(equalToConstant: 16),
            speakerButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3),
            speakerButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3)
        ])

        refreshIcon()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Private Methods

    @objc private func speakerTapped() {
        onToggle?(channelIndex)
    }

    private func refreshIcon() {
        let symbolName = isChannelEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill"
        speakerButton.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        speakerButton.contentTintColor = isChannelEnabled ? enabledColor : NSColor.tertiaryLabelColor
    }
}
