//
//  SlurmController.swift
//  ClusterBar
//
//  Created by Robert Biehl on 22.04.23.
//

import Foundation

class SlurmController {
    private let sshManager: SSHManager
    
    var nodeInfo: [Node] = []
    var jobInfo: [Job] = []
    
    init(host: String, port: Int, username: String, password: String, privateKeyURL: URL? = nil) {
        sshManager = SSHManager(host: host, port: port, username: username, password: password, privateKeyURL: privateKeyURL)
        refreshData { result in
            if case .failure(let error) = result {
                print("Failed to fetch initial data: \(error)")
            }
        }
    }
    
    func refreshData(completion: @escaping (Result<Void, Error>) -> Void) {
        let group = DispatchGroup()
        var nodeInfoError: Error?
        var jobInfoError: Error?
        
        group.enter()
        fetchNodeInfo { result in
            switch result {
            case .success(let nodes):
                self.nodeInfo = nodes
            case .failure(let error):
                nodeInfoError = error
            }
            group.leave()
        }
        
        group.enter()
        fetchJobInfo { result in
            switch result {
            case .success(let jobs):
                self.jobInfo = jobs
            case .failure(let error):
                jobInfoError = error
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            if let error = nodeInfoError ?? jobInfoError {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    private func fetchNodeInfo(completion: @escaping (Result<[Node], Error>) -> Void) {
        sshManager.executeCommand("sinfo -h -o '%N %T %G'") { result in
            switch result {
            case .success(let output):
                let nodes = output.split(separator: "\n").compactMap { line -> Node? in
                    let components = line.split(separator: " ")
                    guard components.count == 3 else { return nil }
                    return Node(name: String(components[0]), status: String(components[1]), group: String(components[2]))
                }
                completion(.success(nodes))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func fetchJobInfo(completion: @escaping (Result<[Job], Error>) -> Void) {
        sshManager.executeCommand("squeue -h -o '%i %u %j %t %M'") { result in
            switch result {
            case .success(let output):
                let jobs = output.split(separator: "\n").compactMap { line -> Job? in
                    let components = line.split(separator: " ")
                    guard components.count == 5 else { return nil }
                    return Job(id: String(components[0]), user: String(components[1]), name: String(components[2]), status: String(components[3]), ageString: String(components[4]))
                }
                completion(.success(jobs))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

struct Node {
    let name: String
    let status: String
    let group: String
}

struct Job {
    let id: String
    let user: String
    let name: String
    let status: String
    let ageString: String
    
    var age: TimeInterval {
        return TimeInterval(parseAgeString(ageString))
    }
    
    private func parseAgeString(_ ageString: String) -> Int {
        let components = ageString.split(separator: ":")
        guard components.count == 3 else { return 0 }
        
        let hours = Int(components[0]) ?? 0
        let minutes = Int(components[1]) ?? 0
        let seconds = Int(components[2]) ?? 0
        
        return (hours * 3600) + (minutes * 60) + seconds
    }
}
