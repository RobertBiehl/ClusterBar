//
//  SlurmController.swift
//  ClusterBar
//
//  Created by Robert Biehl on 22.04.23.
//

import Foundation
import AppKit

class SlurmController {
    private let sshManager: SSHManager
    
    var nodeInfo: [Node] = []
    var jobInfo: [Job] = []
    
    init(host: String, port: Int, username: String, password: String?, privateKeyURL: URL? = nil) {
        sshManager = SSHManager(host: host, port: port, username: username, password: password, privateKeyURL: privateKeyURL)
        //        refreshData { result in
        //            if case .failure(let error) = result {
        //                print("Failed to fetch initial data: \(error)")
        //            }
        //        }
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
        sshManager.executeCommand("sinfo -h -o '%N %T %P'") { result in
            switch result {
            case .success(let output):
                let lines = output.split(separator: "\n")
                var nodes: [Node] = []
                for line in lines {
                    let components = line.split(separator: " ")
                    guard components.count == 3 else { continue }
                    let name = String(components[0])
                    let status = String(components[1])
                    let partition = String(components[2])
                    
                    let rangePattern = "\\[([0-9]+(-[0-9]+)?(,[0-9]+(-[0-9]+)?)*)\\]"
                    let regex = try! NSRegularExpression(pattern: rangePattern, options: [])
                    let range = NSRange(location: 0, length: name.utf16.count)
                    
                    if let match = regex.firstMatch(in: name, options: [], range: range) {
                        let matchedRange = match.range(at: 1)
                        let prefixRange = name.startIndex..<name.index(name.startIndex, offsetBy: matchedRange.lowerBound)
                        let prefix = String(name[prefixRange])
                        let rangeString = (name as NSString).substring(with: matchedRange)
                        let ranges = rangeString.split(separator: ",")
                        
                        for subrange in ranges {
                            if let dashRange = subrange.range(of: "-", options: .numeric) {
                                let lowerBound = Int(subrange[..<dashRange.lowerBound])!
                                let upperBound = Int(subrange[dashRange.upperBound...])!
                                
                                for i in lowerBound...upperBound {
                                    let nodeName = "\(prefix)\(String(format: "%02d", i))"
                                    nodes.append(Node(name: nodeName, status: status, partition: partition))
                                }
                            } else {
                                if let intValue = Int(subrange) {
                                    let nodeName = "\(prefix)\(String(format: "%02d", intValue))"
                                    nodes.append(Node(name: nodeName, status: status, partition: partition))
                                } else {
                                    print("Error: Cannot convert subrange to Int: \(subrange)")
                                }
                            }
                        }
                    } else {
                        nodes.append(Node(name: name, status: status, partition: partition))
                    }
                }
                completion(.success(nodes))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func parseJobStatus(_ status: String) -> Job.JobStatus {
        switch status {
        case "R", "RUNNING":
            return .running
        case "PD", "PENDING":
            return .pending
        case "S", "SUSPENDED":
            return .suspended
        case "C", "COMPLETED":
            return .completed
        case "CA", "CANCELLED":
            return .cancelled
        case "F", "FAILED":
            return .failed
        case "TO", "TIMEOUT":
            return .timeout
        default:
            return .unknown
        }
    }
    
    private func fetchJobInfo(maxJobs: Int = 128, completion: @escaping (Result<[Job], Error>) -> Void) {
        let command = "squeue -h -o '%i|%u|%j|%t|%M' && sacct -X -n -P -o 'JobID,User,JobName,State,Elapsed' --starttime 'now-7days' | head -n \(maxJobs)"
        
        sshManager.executeCommand(command) { result in
            switch result {
            case .success(let output):
                let lines = output.split(separator: "\n")
                var jobDict: [String: Job] = [:]
                
                for line in lines {
                    let components = line.split(separator: "|")
                    guard components.count == 5 else { continue }
                    let status = self.parseJobStatus(String(components[3]))
                    let job = Job(id: String(components[0]), user: String(components[1]), name: String(components[2]), status: status.rawValue, ageString: String(components[4]))
                    
                    // Deduplicate by adding the job to the dictionary only if it's not already present
                    if jobDict[job.id] == nil {
                        jobDict[job.id] = job
                    }
                }
                
                let deduplicatedJobs = Array(jobDict.values)
                let sortedJobs = deduplicatedJobs.sorted(by: { Int($0.id) ?? 0 > Int($1.id) ?? 0 })
                completion(.success(sortedJobs))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func cancelSlurmJob(jobID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let command = "scancel \(jobID)"
        
        sshManager.executeCommand(command) { result in
            switch result {
            case .success(_):
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    enum LogType {
        case stderr
        case stdout
    }

    func downloadErrorLogForJob(jobID: String, logType: LogType = .stderr, completion: @escaping (Result<Void, Error>) -> Void) {
        let command = "scontrol show job \(jobID) -o"
        
        sshManager.executeCommand(command) { result in
            switch result {
            case .success(let output):
                let logFilePattern = logType == .stderr ? "StdErr=(\\S+)" : "StdOut=(\\S+)"
                let regex = try! NSRegularExpression(pattern: logFilePattern, options: [])
                let range = NSRange(location: 0, length: output.utf16.count)
                if let match = regex.firstMatch(in: output, options: [], range: range) {
                    let matchedRange = match.range(at: 1)
                    let logFilePath = (output as NSString).substring(with: matchedRange)
                    
                    let catCommand = "cat \(logFilePath)"
                    self.sshManager.executeCommand(catCommand) { catResult in
                        switch catResult {
                        case .success(let logContent):
                            do {
                                let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
                                let logFileName = logType == .stderr ? "slurm_error_log_\(jobID).txt" : "slurm_output_log_\(jobID).txt"
                                let tempFileURL = tempDirectoryURL.appendingPathComponent(logFileName)
                                
                                try logContent.write(to: tempFileURL, atomically: true, encoding: .utf8)
                                
                                let consoleAppURL = URL(fileURLWithPath: "/System/Applications/Utilities/Console.app")
                                let configuration = NSWorkspace.OpenConfiguration()
                                
                                NSWorkspace.shared.open([tempFileURL], withApplicationAt: consoleAppURL, configuration: configuration, completionHandler: { (success, error) in
                                    if let error = error {
                                        completion(.failure(error))
                                    } else {
                                        completion(.success(()))
                                    }
                                })
                            } catch {
                                completion(.failure(error))
                            }
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                } else {
                    let errorDescription = logType == .stderr ? "Error log file not found" : "Output log file not found"
                    completion(.failure(NSError(domain: "SlurmController", code: -1, userInfo: [NSLocalizedDescriptionKey: errorDescription])))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

struct Node {
    let name: String
    let status: NodeStatus
    let partition: String
    
    enum NodeStatus: String {
        case idle = "idle"
        case allocated = "allocated"
        case mixed = "mixed"
        case drained = "drained"
        case unknown = "unknown"
    }
    
    init(name: String, status: String, partition: String) {
        self.name = name
        self.status = NodeStatus(rawValue: status) ?? .unknown
        self.partition = partition
    }
}

struct Job {
    let id: String
    let user: String
    let name: String
    let status: JobStatus
    let ageString: String
    
    enum JobStatus: String {
        case running = "R"
        case pending = "PD"
        case suspended = "S"
        case completed = "C"
        case cancelled = "CA"
        case failed = "F"
        case timeout = "TO"
        case unknown = "unknown"
    }
    
    init(id: String, user: String, name: String, status: String, ageString: String) {
        self.id = id
        self.user = user
        self.name = name
        self.status = JobStatus(rawValue: status) ?? .unknown
        self.ageString = ageString
    }
    
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
