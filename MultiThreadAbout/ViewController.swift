//
//  ViewController.swift
//  OperationQueuesDownload
//
//  Created by cxz on 2018/11/16.
//  Copyright © 2018年 cxz. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    ///信号量 --- 一般在并发队列中限制对同一资源最大线程同时访问量做限制，防止线程资源争抢造成资源错误，即多线程对同一资源访问时一般设置value=1，一般是成对出现, global_semaphore.wait()即value-1，global_semaphore.signal()即value+1,当value=0时若此时有线程访问资源，则挂起等待，直到value!=0时访问资源
    ///当有两个线程同时挂起等待时，则优先级高的先访问资源，若优先级相同，则遵循FIFO的规则
    private let global_semaphore = DispatchSemaphore.init(value: 1)
    
    lazy private var queue: OperationQueue = {
        let queue = OperationQueue.init()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    ///dispatch_group
    private var group = DispatchGroup.init()
    
    private var index = 0   //资源
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.GCDGroupFunc()
        
    }
    
    //MARK: --- Operation About ---
    
    ///当并行队列的多线程对同一资源进行 如对DB的fetch/update/add/delet 操作时，使用信号量控制资源的访问控制
    ///当串行队列的多线程对同一资源访问时， 由于是串行队列，同时只能一条线程访问资源，所以是否使用semaphore均可
    private func operationSemaphoreFunc() -> Void {
        //maxConcurrentOperationCount == 1 即为串行操作
        for _ in 0..<100000 {
            let operation = BlockOperation.init {[weak self] in
                self?.task()
            }
            queue.addOperation(operation)
        }
    }
    
    ///资源访问
    private func task() -> Void {
        global_semaphore.wait()
        self.index += 1
        debugPrint("\(index) -- \(Thread.current)")
        global_semaphore.signal()
    }
    
    ///operationQueue 通知控制maxConcurrentOperationCount来控制串行/并行队列
    ///maxConcurrentOperationCount == 1 串行队列
    ///maxConcurrentOperationCount > 1 并行队列
    private func operationSequenceAbout() -> Void {
        ///operationQueue dependency
        let op1 = BlockOperation.init {
            debugPrint("i am operation 1 -- \(Thread.current)")
        }
        let op2 = BlockOperation.init {
            debugPrint("i am operation 2 -- \(Thread.current)")
        }
        let op3 = BlockOperation.init {
            debugPrint("i am operation 3 -- \(Thread.current)")
        }
        
        op1.addDependency(op2)
        op1.addDependency(op3)
        
        ///加到队列后即开始只能
        queue.addOperation(op1)
        queue.addOperation(op2)
        queue.addOperation(op3)
    }
    
    //MARK: --- GCD About ---
    // Tip: **********由于 GCD无法限制最大并发数，因此建议使用OperationQueue**********
    
    ///GCD栅栏函数: -- 在userCreateConcurrentThread中会强制 **串行执行**
    ///
    ///在 DispatchQueue.global() 中 并不会强制串行执行 Apple API 如下
    /*
     When submitted to a a global queue or to a queue not created with the DISPATCH_QUEUE_CONCURRENT attribute, barrier blocks behave identically to blocks submitted with the dispatch_async()/dispatch_sync() API.
     当barrier函数在 DispatchQueue.global()或非并发队列中使用，执行效果 == dispatch_async()/dispatch_sync()
     */
    private func GCDBarrierAbout() -> Void {
        ///GCD barrier
        let dispatch_queue = DispatchQueue.global()
        //        let dispatch_queue = DispatchQueue.init(label: "com.personal.cxz", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)
        dispatch_queue.async(group: nil, qos: .default, flags: .barrier) {
            //            sleep(1)
            debugPrint("GCD: no.2 -- \(Thread.current) -- \(Thread.main)")
        }
        
        dispatch_queue.async(group: nil, qos: .default, flags: .barrier) {
            debugPrint("GCD: no.1-- \(Thread.current) -- \(Thread.main)")
        }
        
        dispatch_queue.async(group: nil, qos: .default, flags: .barrier) {
            debugPrint("GCD: no.3-- \(Thread.current) -- \(Thread.main)")
        }
    }
    
    ///使用dispatchGroup
    private func GCDGroupFunc() -> Void {
        ///在swift的GCD中，如果不设置attributes，则default为串行队列，不会开辟新线程，反之为并行队列
        let queue1 = DispatchQueue.init(label: "com.personal.cxz.queue1", attributes: .concurrent)
        
        ///当 queue 执行 async时即开辟了新线程 group.notify不会开辟新线程
        queue1.async(group: self.group) {
            for _ in 0..<10000 {
                self.task()
            }
            debugPrint("GCD: queue11 --- \(Thread.current)")
        }
        
        queue1.async(group: self.group) {
            for _ in 0..<1000 {
                self.task()
            }
            debugPrint("GCD: queue12 --- \(Thread.current)")
        }
        
        queue1.async(group: self.group) {
            for _ in 0..<1000 {
                self.task()
            }
            debugPrint("GCD: queue13 --- \(Thread.current)")
        }
        
        ///设置超时时间，用以控制耗时操作操作时间
        ///注意，使用wait时会将当前进程挂起等待，所以wait一般不要在UI线程中使用
        debugPrint("我会率先执行")
        //        let rs = self.group.wait(timeout: .now() + 4.0)
        //        if rs == .success {
        //            debugPrint("success")
        //        } else {
        //            debugPrint("time out")
        //        }
        //        debugPrint("我会在 .now() + 2.0sec 后执行")
        //        if rs == .success {
        ///当queue1所有任务执行完毕后会执行notify中的block
        self.group.notify(queue: queue1) {
            debugPrint("all done --- \(Thread.current)")
        }
        //        }
    }
}

