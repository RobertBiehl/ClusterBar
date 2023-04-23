//
//  SettingsViewController.swift
//  ClusterBar
//
//  Created by Robert Biehl on 23.04.23.
//

import Cocoa
class SettingsViewController: NSViewController {
    
    private let settings = Settings.shared
    private let stackView = NSStackView()
    private let hostnameTextField = NSTextField()
    private let usePrivateKeyCheckbox = NSButton()
    private let usernameTextField = NSTextField()
    private let passwordTextField = NSSecureTextField()
    private let privateKeySelector = NSButton()
    private let refreshIntervalSlider = NSSlider()

    override func loadView() {
        view = NSView()
        view.frame = NSRect(x: 0, y: 0, width: 300, height: 200)
        configureStackView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateUI()
    }

    private func configureStackView() {
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        configureHostnameTextField()
        configureUsePrivateKeyCheckbox()
        configureUsernamePasswordField()
        configurePrivateKeySelector()
        configureRefreshIntervalSlider()

        // Set up constraints
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
        ])
    }

    // Add and configure components here...

    private func updateUI() {
        hostnameTextField.stringValue = settings.hostname
        usePrivateKeyCheckbox.state = settings.usePrivateKey ? .on : .off
        usernameTextField.stringValue = settings.username ?? ""
        passwordTextField.stringValue = settings.password ?? ""
        refreshIntervalSlider.doubleValue = settings.refreshInterval
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        saveSettings()
    }

    private func saveSettings() {
        settings.hostname = hostnameTextField.stringValue
        settings.usePrivateKey = usePrivateKeyCheckbox.state == .on
        settings.username = usernameTextField.stringValue
        settings.password = passwordTextField.stringValue
        settings.refreshInterval = refreshIntervalSlider.doubleValue
    }
    
    private func configureHostnameTextField() {
        let label = NSTextField(labelWithString: "Hostname:")
        stackView.addArrangedSubview(label)
        
        hostnameTextField.placeholderString = "Enter hostname"
        hostnameTextField.isBezeled = true
        hostnameTextField.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(hostnameTextField)
        
        NSLayoutConstraint.activate([
            hostnameTextField.widthAnchor.constraint(equalToConstant: 200)
        ])
    }

    private func configureUsePrivateKeyCheckbox() {
        usePrivateKeyCheckbox.title = "Use Private Key"
        usePrivateKeyCheckbox.setButtonType(.switch)
        usePrivateKeyCheckbox.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(usePrivateKeyCheckbox)
        
        usePrivateKeyCheckbox.target = self
        usePrivateKeyCheckbox.action = #selector(usePrivateKeyToggled)
    }

    @objc private func usePrivateKeyToggled() {
        let usePrivateKey = usePrivateKeyCheckbox.state == .on
        usernameTextField.isEnabled = !usePrivateKey
        passwordTextField.isEnabled = !usePrivateKey
        privateKeySelector.isEnabled = usePrivateKey
    }

    private func configureUsernamePasswordField() {
        let usernameLabel = NSTextField(labelWithString: "Username:")
        stackView.addArrangedSubview(usernameLabel)
        
        usernameTextField.placeholderString = "Enter username"
        usernameTextField.isBezeled = true
        usernameTextField.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(usernameTextField)
        
        let passwordLabel = NSTextField(labelWithString: "Password:")
        stackView.addArrangedSubview(passwordLabel)
        
        passwordTextField.placeholderString = "Enter password"
        passwordTextField.isBezeled = true
        passwordTextField.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(passwordTextField)
        
        NSLayoutConstraint.activate([
            usernameTextField.widthAnchor.constraint(equalToConstant: 200),
            passwordTextField.widthAnchor.constraint(equalToConstant: 200)
        ])
    }

    private func configurePrivateKeySelector() {
        privateKeySelector.title = "Select Private Key"
        privateKeySelector.bezelStyle = .rounded
        privateKeySelector.translatesAutoresizingMaskIntoConstraints = false
        privateKeySelector.target = self
        privateKeySelector.action = #selector(privateKeySelectorClicked)
        stackView.addArrangedSubview(privateKeySelector)
    }

    @objc private func privateKeySelectorClicked(_ sender: NSButton) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowsMultipleSelection = false
        openPanel.showsHiddenFiles = true
//        openPanel.allowedFileTypes = ["key", "pem"]
        
        openPanel.begin { [weak self] result in
            guard let self = self, result == .OK, let url = openPanel.url else { return }
            self.settings.privateKeyURL = url
        }
    }

    private func configureRefreshIntervalSlider() {
        let sliderLabel = NSTextField(labelWithString: "Refresh Interval:")
        stackView.addArrangedSubview(sliderLabel)
        
        refreshIntervalSlider.minValue = 5 // 5 seconds
        refreshIntervalSlider.maxValue = 600 // 10 minutes
        refreshIntervalSlider.allowsTickMarkValuesOnly = true
        refreshIntervalSlider.numberOfTickMarks = 20
        refreshIntervalSlider.target = self
        refreshIntervalSlider.action = #selector(refreshIntervalSliderChanged)
        stackView.addArrangedSubview(refreshIntervalSlider)
        
        let secondsLabel = NSTextField()
        secondsLabel.isEditable = false
        secondsLabel.isBordered = false
        secondsLabel.backgroundColor = .clear
        secondsLabel.tag = 100 // Use a tag to identify this label later
        stackView.addArrangedSubview(secondsLabel)
    }

    @objc private func refreshIntervalSliderChanged() {
        let value = refreshIntervalSlider.doubleValue
        let secondsLabel = stackView.viewWithTag(100) as? NSTextField
        secondsLabel?.stringValue = String(format: "%.0f seconds", value)
    }
}
