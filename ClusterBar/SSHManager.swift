//
//  SSHManager.swift
//  ClusterBar
//
//  Created by Robert Biehl on 22.04.23.
//

import Foundation
import Shout

class SSHManager {
    private let host: String
    private let port: Int32
    private let username: String
    private let password: String
    private let privateKeyURL: URL?
    
    init(host: String, port: Int, username: String, password: String, privateKeyURL: URL? = nil) {
        self.host = host
        self.port = Int32(port)
        self.username = username
        self.password = password
        self.privateKeyURL = privateKeyURL
    }
    
    enum SSHManagerError: Error {
        case unexpectedExitCode(status: Int32, command: String)
    }
    
    func executeCommand(_ command: String, completion: @escaping (Result<String, Error>) -> Void) {
        do {
            let ssh = try SSH(host: host, port: port)
            
            if let privateKeyURL = privateKeyURL {
                let privateKeyData = try Data(contentsOf: privateKeyURL)
                let privateKey = String(data: privateKeyData, encoding: .utf8)
                
                try ssh.authenticate(username: username, privateKey: privateKey!)
            } else {
                try ssh.authenticate(username: username, password: password)
            }
            
            
            let (status, output) = try ssh.capture(command)
            
            if status == 0 {
                completion(.success(output))
            } else {
                completion(.failure(SSHManagerError.unexpectedExitCode(status: status, command: command)))
            }
            
        } catch {
            completion(.failure(error))
        }
    }
}
