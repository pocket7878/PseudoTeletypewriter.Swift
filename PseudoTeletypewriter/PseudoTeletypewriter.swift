//
//  PseudoTeletypewriter.swift
//  PseudoTeletypewriter
//
//  Created by Hoon H. on 2015/01/12.
//  Copyright (c) 2015 Eonil. All rights reserved.
//

import Foundation
import BSD

/// Provides simple access to BSD `pty`.
/// 
/// This spawns a new child process using supplied arguments,
/// and setup a proper pseudo terminal connected to it.
///
/// The child process will run in interactive mode terminal,
/// and will emit terminal escape code accordingly if you set
/// a proper terminal environment variable.
///
///     TERM=ansi
///
/// Here's full recommended example.
///
///     let    pty    =    PseudoTeletypewriter(path: "/bin/ls", arguments: ["/bin/ls", "-Gbla"], environment: ["TERM=ansi"])!
///     println(pty.masterFileHandle.readDataToEndOfFile().toString())
///     pty.waitUntilChildProcessFinishes()
///
/// It is recommended to use executable name as the first argument by convention.
///
/// The child process will be launched immediately when you 
/// instantiate this class.
///
/// This is a sort of `NSTask`-like class and modeled on it.
/// This does not support setting terminal dimensions.
///
public final class PseudoTeletypewriter {
    private let _masterFileHandle:FileHandle
    private let _childProcessID:pid_t
    
    open func childProcessExitStatus() -> Int32 {
        var	stat_loc	=	0 as Int32
        let	childpid1	=	waitpid(_childProcessID, &stat_loc, 0)
        return stat_loc
    }
    
    open func killChild(sig: Int32) {
        kill(_childProcessID, sig)
    }
    
    open func isChildProcessFinished() -> Bool {
        var stat_loc = 0 as Int32
        let status = waitpid(_childProcessID, &stat_loc, WNOHANG)
        switch(status) {
        case -1:
            debugLog("child process \(_childProcessID) does not exists")
            return false
        case 0:
            return false
        case _childProcessID:
            return true
        default:
            debugLog("unknown return status \(status)")
            return false
        }
    }

    public init?(path:String, arguments:[String], environment:[String]) {
        assert(arguments.count >= 1)
        assert(path.hasSuffix(arguments[0]))
        
        let r = forkPseudoTeletypewriter()
        if r.result.ok {
            if r.result.isRunningInParentProcess {
                debugLog("parent: ok, child pid = \(r.result.processID)")
                self._masterFileHandle = r.master.toFileHandle(true)
                self._childProcessID = r.result.processID
            } else {
                debugLog("child: ok")
                execute(path, arguments, environment)
                fatalError("Returning from `execute` means the command was failed. This is unrecoverable error in child process side, so just abort the execution.")
            }
        } else {
            debugLog("`forkpty` failed.")
            
            /// Below two lines are useless but inserted to suppress compiler error.
            _masterFileHandle = FileHandle()
            _childProcessID = 0
            return nil
        }
    }

    public var masterFileHandle:FileHandle {
        return _masterFileHandle
    }
    
    public var childProcessID:pid_t {
        return _childProcessID
    }
    
    /// Waits for child process finishes synchronously.
    public func waitUntilChildProcessFinishes() {
        var stat_loc = 0 as Int32
        let childpid1 = waitpid(_childProcessID, &stat_loc, 0)
        debugLog("child process quit: pid = \(childpid1)")
    }
}

private func debugLog<T>(_ v:@autoclosure ()->T) {
    #if DEBUG
        println("\(v)")
    #endif
}
