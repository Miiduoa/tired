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

    /// 按依赖关系排序任务（拓扑排序）
    /// 依赖的任务会排在被依赖的任务之前
    func topologicalSort(_ tasks: [Task]) -> [Task] {
        var sorted: [Task] = []
        var visited: Set<String> = []
        var visiting: Set<String> = []

        for task in tasks {
            topologicalSortDFS(task, allTasks: tasks, visited: &visited, visiting: &visiting, sorted: &sorted)
        }

        return sorted
    }

    private func topologicalSortDFS(
        _ task: Task,
        allTasks: [Task],
        visited: inout Set<String>,
        visiting: inout Set<String>,
        sorted: inout [Task]
    ) {
        let taskId = task.id ?? ""

        if visited.contains(taskId) {
            return  // 已访问
        }

        if visiting.contains(taskId) {
            return  // 正在访问（检测到循环）
        }

        visiting.insert(taskId)

        // 先访问所有依赖的任务
        for depId in task.dependsOnTaskIds {
            if let depTask = allTasks.first(where: { $0.id == depId }) {
                topologicalSortDFS(depTask, allTasks: allTasks, visited: &visited, visiting: &visiting, sorted: &sorted)
            }
        }

        visiting.remove(taskId)
        visited.insert(taskId)
        sorted.append(task)
    }

    // MARK: - Scheduling with Dependencies

    /// 在考虑依赖关系的前提下进行自动排程
    func autoPlanWithDependencies(
        tasks: [Task],
        options: AutoPlanService.AutoPlanOptions
    ) -> [Task] {
        // 首先按依赖关系排序
        let sortedTasks = topologicalSort(tasks)

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
