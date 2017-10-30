import Foundation

/// Tasks can be autostarted or started manualy. The taks are still handled bij an URLSession like in `Service`, but
/// we store the TaskIdentifiers. When a task completes it is removed from the queue and `final()`.
/// It has its own `URLSession` which it invalidates once the queue is finished. You need to create another instance of `ServiceQueue` to be able to
/// perform new request after you fired the first queue.
open class ServiceQueue: Service {
    
    var taskQueue: Set<URLSessionDataTask>
    var failedTasks: Set<URLSessionTask>?
    lazy var errors: [FaroError] = [FaroError]()
    
    private let final: (_ failedTasks: Set<URLSessionTask>?, _ errors:[FaroError]?)->()
    
    /// Creates a queue that lasts until final is called. When all request in the queue are finished the session becomes invalid.
    /// For future queued request you have to create a new ServiceQueue instance.
    /// - parameter configuration: Faro service configuration
    /// - parameter faroSession: You can provide a custom `URLSession` via `FaroQueueSession`.
    /// - parameter final: closure is callen when all requests are performed.
    public init(configuration: Configuration, faroSession: FaroQueueSessionable = FaroQueueSession(), final: @escaping(_ failedTasks: Set<URLSessionTask>?, _ errors: [FaroError]?)->()) {
        self.final = final
        taskQueue = Set<URLSessionDataTask>()
        super.init(configuration: configuration, faroSession: faroSession)
    }
    
    // MARK: - Override not throwing
    
    open override func performJsonResult<M: Deserializable>(_ call: Call, autoStart: Bool = false, jsonResult: @escaping (Result<M>) -> ()) -> URLSessionDataTask? {
        var task: URLSessionDataTask?
        task = super.performJsonResult(call, autoStart: autoStart) { [weak self] (stage1JsonResult: Result<M>) in
            guard let strongSelf = self else {
                jsonResult(stage1JsonResult)
                return
            }
            /// Store ID of failed tasks to report
            switch stage1JsonResult {
            case .json(_), .ok:
                strongSelf.cleanupQueue(for: task)
            case .failure(let error):
                strongSelf.cleanupQueue(for: task, with: error, didFail: true)
            default:
                strongSelf.cleanupQueue(for: task)
            }
            
            
            jsonResult(stage1JsonResult)
            strongSelf.shouldCallFinal()
        }
        
        add(task)
        return task
    }
    
    open override func performWrite(_ writeCall: Call, autoStart: Bool, writeResult: @escaping (WriteResult) -> ()) -> URLSessionDataTask? {
        var task: URLSessionDataTask?
        task = super.performWrite(writeCall, autoStart: autoStart) { [weak self] (result) in
            guard let strongSelf = self else {
                writeResult(result)
                return
            }
            
            switch result {
            case .ok:
                strongSelf.cleanupQueue(for: task)
            case .failure(let error):
                strongSelf.cleanupQueue(for: task, with: error, didFail: true)
            }
            
            writeResult(result)
            strongSelf.shouldCallFinal()
        }
        add(task)
        return task
    }
    
    // MARK: - Override Throwing
    
    open override func performJsonResult<M : Deserializable>(_ call: Call, autoStart: Bool, jsonResult: @escaping (Result<M>) throws -> (), throwHandler: @escaping (() throws -> ()) -> ()) throws -> URLSessionDataTask {
        var task: URLSessionDataTask!
        task = try super.performJsonResult(call, autoStart: autoStart, jsonResult: { [weak self] (stage1JsonResult: Result<M>) in
            guard let strongSelf = self else {
                try jsonResult(stage1JsonResult)
                return
            }
            /// Store ID of failed tasks to report
            switch stage1JsonResult {
            case .json(_), .ok:
                strongSelf.cleanupQueue(for: task)
            case .failure(let error):
                strongSelf.cleanupQueue(for: task, with: error, didFail: true)
            default:
                strongSelf.cleanupQueue(for: task)
            }
            
            
            try jsonResult(stage1JsonResult)
            strongSelf.shouldCallFinal()
            }, throwHandler: throwHandler)
        
        add(task)
        return task
    }
    open override func performWrite(_ writeCall: Call, autoStart: Bool = true, writeResult: @escaping (WriteResult) throws -> (), throwHandler: @escaping (()throws ->()) -> () = faroDefaultThrowHandler) throws -> URLSessionDataTask {
        var task: URLSessionDataTask!
        task = try super.performWrite(writeCall, autoStart: autoStart, writeResult: { [weak self] (result) in
            guard let strongSelf = self else {
                try writeResult(result)
                return
            }
            
            switch result {
            case .ok:
                strongSelf.cleanupQueue(for: task)
            case .failure(let error):
                strongSelf.cleanupQueue(for: task, with: error, didFail: true)
            }
            
            try writeResult(result)
            strongSelf.shouldCallFinal()
            }, throwHandler: throwHandler)
        add(task)
        return task
    }
    
    // MARK: - Private
    private func add(_ task: URLSessionDataTask?) {
        guard let createdTask = task else {
            printFaroError(FaroError.invalidSession(message: "\(self) tried to "))
            return
        }
        taskQueue.insert(createdTask)
    }
    
    private func cleanupQueue(for task: URLSessionDataTask?, with error: FaroError? = nil, didFail: Bool = false) {
        if let task = task {
            let _ = taskQueue.remove(task)
            if(didFail) {
                if failedTasks == nil {
                    failedTasks = Set<URLSessionTask>()
                }
                failedTasks?.insert(task)
                
                guard let error = error else {
                    return
                }
                errors.append(error)
            }
        }
    }
    
    private func shouldCallFinal() {
        if !hasOustandingTasks {
            final(failedTasks, errors)
            finishTasksAndInvalidate()
        }
    }
    
    // MARK: - Interact with tasks
    
    open var hasOustandingTasks: Bool {
        get {
            return taskQueue.count > 0
        }
    }
    
    open func resume(_ task: URLSessionDataTask) {
        faroSession.resume(task)
    }
    
    open func resumeAll() {
        let notStartedTasks = taskQueue.filter { $0.state != .running || $0.state != .completed}
        notStartedTasks.forEach { (task) in
            faroSession.resume(task)
        }
    }
    
    // MARK: - Invalidate session overrides
    
    override open func invalidateAndCancel() {
        taskQueue.removeAll()
        failedTasks?.removeAll()
        faroSession.invalidateAndCancel()
    }
    
    deinit {
        faroSession.finishTasksAndInvalidate()
    }
}
