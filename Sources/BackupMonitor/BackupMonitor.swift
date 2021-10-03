import Foundation

public protocol BackupMonitorDelegate: AnyObject {
    func backupMonitor(_ monitor: BackupMonitor, backupStarted destinationMountPoint: String)
    func backupMonitor(_ monitor: BackupMonitor, backupEnded latestBackupPath: String)
    func backupMonitor(_ monitor: BackupMonitor, backupCleaningUpStarted backupPath: String)
    func backupMonitor(_ monitor: BackupMonitor, backupCleaningUpEnded backupPath: String, error: Int)
}

extension Notification.Name {
    public static let backupStarted = Notification.Name("BackupMonitor.backupStarted")
    public static let backupEnded = Notification.Name("BackupMonitor.backupEnded")
    public static let backupCleaningUpStarted = Notification.Name("BackupMonitor.backupCleaningUpStarted")
    public static let backupCleaningUpEnded = Notification.Name("BackupMonitor.backupCleaningUpEnded")
}

public final class BackupMonitor {
    private var backupdObservers: [NSObjectProtocol]?

    public weak var delegate: BackupMonitorDelegate?

    public init(delegate: BackupMonitorDelegate? = nil) {
        self.delegate = delegate
    }

    public func start() {
        stop()

        NotificationCenter.default.addObserver(self, selector: #selector(backupStarted(_:)), name: .backupStarted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(backupEnded(_:)), name: .backupEnded, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(backupCleaningUpStarted(_:)), name: .backupCleaningUpStarted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(backupCleaningUpEnded(_:)), name: .backupCleaningUpEnded, object: nil)

        backupdObservers = [
            DistributedNotificationCenter.default.addObserver(forName: .destinationMount, object: nil, queue: nil) { note in
                NotificationCenter.default.post(name: .backupStarted, object: nil, userInfo: note.userInfo)
            },
            DistributedNotificationCenter.default.addObserver(forName: .newSystemBackupAvailable, object: nil, queue: nil) { note in
                NotificationCenter.default.post(name: .backupEnded, object: nil, userInfo: note.userInfo)
            },
            DistributedNotificationCenter.default.addObserver(forName: .thinningbackup, object: nil, queue: nil) { note in
                NotificationCenter.default.post(name: .backupCleaningUpStarted, object: nil, userInfo: note.userInfo)
            },
            DistributedNotificationCenter.default.addObserver(forName: .thinningbackupended, object: nil, queue: nil) { note in
                NotificationCenter.default.post(name: .backupCleaningUpEnded, object: nil, userInfo: note.userInfo)
            }
        ]
    }

    public func stop() {
        NotificationCenter.default.removeObserver(self, name: .backupStarted, object: nil)
        NotificationCenter.default.removeObserver(self, name: .backupEnded, object: nil)
        NotificationCenter.default.removeObserver(self, name: .backupCleaningUpStarted, object: nil)
        NotificationCenter.default.removeObserver(self, name: .backupCleaningUpEnded, object: nil)
        backupdObservers?.forEach { DistributedNotificationCenter.default.removeObserver($0) }
        backupdObservers = nil
    }

    deinit {
        stop()
    }
}

extension BackupMonitor {
    @objc private func backupStarted(_ notificaiton: Notification) {
        let destinationMountPoint = notificaiton.userInfo!["DestinationMountPoint"] as! String
        delegate?.backupMonitor(self, backupStarted: destinationMountPoint)
    }

    @objc private func backupEnded(_ notificaiton: Notification) {
        let latestBackupPath = notificaiton.userInfo!["LatestBackupPath"] as! String
        delegate?.backupMonitor(self, backupEnded: latestBackupPath)
    }

    @objc private func backupCleaningUpStarted(_ notificaiton: Notification) {
        let backupPath = notificaiton.userInfo!["BackupPath"] as! String
        delegate?.backupMonitor(self, backupCleaningUpStarted: backupPath)
    }

    @objc private func backupCleaningUpEnded(_ notificaiton: Notification) {
        let backupPath = notificaiton.userInfo!["BackupPath"] as! String
        let error = notificaiton.userInfo!["Error"] as! Int
        delegate?.backupMonitor(self, backupCleaningUpEnded: backupPath, error: error)
    }
}

extension NSNotification.Name {
    static let destinationMount = NSNotification.Name("com.apple.backupd.DestinationMountNotification")
    static let newSystemBackupAvailable = NSNotification.Name("com.apple.backupd.NewSystemBackupAvailableNotification")
    static let thinningbackup = NSNotification.Name("com.apple.backupd.thinningbackup")
    static let thinningbackupended = NSNotification.Name("com.apple.backupd.thinningbackupended")
}
