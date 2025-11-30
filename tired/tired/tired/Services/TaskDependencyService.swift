import Foundation
import FirebaseFirestore

/// 任务依赖关系服务
class TaskDependencyService {

    // MARK: - Dependency Checking

    /// 检查任务是否可以开始（所有依赖都已完成）
    func canStartTask(_ task: Task, allTasks: [Task]) -> Bool {
        for dependencyId in task.dependsOnTaskIds {
            guard let dependency = allTasks.first(where: { $0.id == dependencyId }) else {
                continue  // 依赖任务不存在，忽略
            }

            if !dependency.isDone {
                return false  // 依赖任务未完成
            }
        }
        return true
    }

    /// 检查完成此任务后会自动解锁哪些任务
    func getUnlockedTasks(_ completedTaskId: String, allTasks: [Task]) -> [Task] {
        return allTasks.filter { task in
            task.dependsOnTaskIds.contains(completedTaskId)
        }
    }

    // MARK: - Dependency Chain

    /// 获取任务的完整依赖链（递归）
    func getDependencyChain(_ taskId: String, allTasks: [Task]) -> [Task] {
        guard let task = allTasks.first(where: { $0.id == taskId }) else { return [] }

        var chain = [task]
        for depId in task.dependsOnTaskIds {
            chain.append(contentsOf: getDependencyChain(depId, allTasks: allTasks))
        }
        return chain
    }

    /// 获取依赖于此任务的所有任务（递归）
    func getDependentTasks(_ taskId: String, allTasks: [Task]) -> [Task] {
        var dependents: [Task] = []

        for task in allTasks {
            if task.dependsOnTaskIds.contains(taskId) {
                dependents.append(task)
                // 递归获取依赖于这些任务的任务
                dependents.append(contentsOf: getDependentTasks(task.id ?? "", allTasks: allTasks))
            }
        }

        return dependents
    }

    /// 检查是否会形成循环依赖
    func hasCircularDependency(_ taskId: String, newDependencyId: String, allTasks: [Task]) -> Bool {
        // 如果新依赖依赖于当前任务，就会形成循环
        let chain = getDependencyChain(newDependencyId, allTasks: allTasks)
        return chain.contains { $0.id == taskId }
    }

    // MARK: - Topological Sorting

    /// 按依赖关系排序任务（拓扑排序，支持优先级决策）
    /// 依赖的任务会排在被依赖的任务之前，若有多个可排任务，则按优先级/截止时间/创建时间择优
    func topologicalSort(_ tasks: [Task], preferPriority: Bool = false) -> [Task] {
        // 以 ID 为键建立图结构；若缺少 ID，则生成临时 ID 以避免崩溃
        var taskMap: [String: Task] = [:]
        for task in tasks {
            let key = task.id ?? UUID().uuidString
            taskMap[key] = task
        }

        var inDegree: [String: Int] = [:]
        var graph: [String: [String]] = [:]
        taskMap.keys.forEach { inDegree[$0] = 0 }

        // 建图并统计入度
        for (taskId, task) in taskMap {
            for depId in task.dependsOnTaskIds {
                // 仅对当前待排程集合中的依赖建立约束；缺失的依赖视为已满足
                guard taskMap[depId] != nil else { continue }
                inDegree[taskId, default: 0] += 1
                graph[depId, default: []].append(taskId)
            }
        }

        // 允许依赖满足的任务进入队列
        var readyQueue: [String] = inDegree.filter { $0.value == 0 }.map { $0.key }

        func taskPriorityComparator(_ lhsTask: Task, _ rhsTask: Task) -> Bool {
            // 高优先级 > 低优先级
            let priorityScore: [TaskPriority: Int] = [.high: 3, .medium: 2, .low: 1]
            let lhsPriority = priorityScore[lhsTask.priority] ?? 0
            let rhsPriority = priorityScore[rhsTask.priority] ?? 0
            if lhsPriority != rhsPriority {
                return lhsPriority > rhsPriority
            }

            // 截止日越早越优先
            if let d1 = lhsTask.deadlineAt, let d2 = rhsTask.deadlineAt, d1 != d2 {
                return d1 < d2
            }

            // 创建时间越早越优先（保持稳定性）
            return lhsTask.createdAt < rhsTask.createdAt
        }

        func priorityComparator(lhsId: String, rhsId: String) -> Bool {
            guard
                let lhsTask = taskMap[lhsId],
                let rhsTask = taskMap[rhsId]
            else { return false }
            return taskPriorityComparator(lhsTask, rhsTask)
        }

        var sorted: [Task] = []
        var processedIds: Set<String> = []

        while !readyQueue.isEmpty {
            if preferPriority {
                readyQueue.sort(by: priorityComparator)
            }

            let currentId = readyQueue.removeFirst()
            guard let currentTask = taskMap[currentId] else { continue }
            processedIds.insert(currentId)
            sorted.append(currentTask)

            for neighbor in graph[currentId] ?? [] {
                inDegree[neighbor, default: 0] -= 1
                if inDegree[neighbor, default: 0] == 0 {
                    readyQueue.append(neighbor)
                }
            }
        }

        // 若存在循环依赖或缺失，补齐剩余任务并按优先级兜底排序
        if sorted.count < taskMap.count {
            let remainingIds = taskMap.keys.filter { !processedIds.contains($0) }
            let remaining = remainingIds.compactMap { taskMap[$0] }

            let fallback = preferPriority
                ? remaining.sorted(by: taskPriorityComparator)
                : remaining

            sorted.append(contentsOf: fallback)
        }

        return sorted
    }

    // MARK: - Scheduling with Dependencies

    /// 在考虑依赖关系的前提下进行自动排程
    func autoPlanWithDependencies(
        tasks: [Task],
        options: AutoPlanService.AutoPlanOptions
    ) -> [Task] {
        // 首先按依赖关系排序
        let sortedTasks = topologicalSort(tasks, preferPriority: true)

        // 对排序后的任务进行自动排程
        let autoPlanService = AutoPlanService()
        let (plannedTasks, _) = autoPlanService.autoplanWeek(tasks: sortedTasks, options: options)

        return plannedTasks
    }

    // MARK: - Dependency Notifications

    /// 获取用户需要知道的依赖信息
    /// 返回那些解锁了新任务的依赖完成事件
    func getUnlockNotifications(_ completedTaskId: String, allTasks: [Task]) -> [String] {
        let unlockedTasks = getUnlockedTasks(completedTaskId, allTasks: allTasks)

        return unlockedTasks.map { task in
            "✅ 任务\"\(task.title)\"现在已解锁，可以开始了"
        }
    }

    // MARK: - Dependency Validation

    /// 验证添加新的依赖是否有效
    func validateDependency(
        taskId: String,
        newDependencyId: String,
        allTasks: [Task]
    ) -> (valid: Bool, error: String?) {
        // 检查依赖任务是否存在
        if !allTasks.contains(where: { $0.id == newDependencyId }) {
            return (false, "依赖任务不存在")
        }

        // 检查是否为自己
        if taskId == newDependencyId {
            return (false, "任务不能依赖于自己")
        }

        // 检查循环依赖
        if hasCircularDependency(taskId, newDependencyId: newDependencyId, allTasks: allTasks) {
            return (false, "添加此依赖会形成循环引用")
        }

        return (true, nil)
    }
}
