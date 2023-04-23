//
//  Setings.swift
//  ClusterBar
//
//  Created by Robert Biehl on 22.04.23.
//

import Foundation

class Settings {
    static let shared = Settings()
    
    private init() {}
    
    private let defaults = UserDefaults.standard
    
    var hostname: String {
        get { return defaults.string(forKey: "hostname") ?? "" }
        set { defaults.set(newValue, forKey: "hostname") }
    }
    
    var usePrivateKey: Bool {
        get { return defaults.bool(forKey: "usePrivateKey") }
        set { defaults.set(newValue, forKey: "usePrivateKey") }
    }
    
    var privateKeyURL: URL? {
          get {
              if let urlString = defaults.string(forKey: "privateKeyURL"),
                  let url = URL(string: urlString) {
                  return url
              }
              return nil
          }
          set {
              if let url = newValue {
                  defaults.set(url.absoluteString, forKey: "privateKeyURL")
              } else {
                  defaults.removeObject(forKey: "privateKeyURL")
              }
          }
      }
    
    var username: String? {
        get { return defaults.string(forKey: "username") }
        set {
            defaults.set(newValue, forKey: "username")
            defaults.removeObject(forKey: "privateKeyPath")
        }
    }
    
    var password: String? {
        get { return defaults.string(forKey: "password") }
        set {
            defaults.set(newValue, forKey: "password")
            defaults.removeObject(forKey: "privateKeyPath")
        }
    }
    
    var refreshInterval: TimeInterval {
        get { return defaults.double(forKey: "refreshInterval") }
        set { defaults.set(newValue, forKey: "refreshInterval") }
    }
    
    // Other user-configurable variables
}
