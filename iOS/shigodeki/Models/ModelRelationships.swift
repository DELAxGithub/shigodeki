//
//  ModelRelationships.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import Foundation

struct ModelRelationships {
    
    // MARK: - Project Relationships
    
    static func validateProjectHierarchy(project: Project, phases: [Phase]) throws {
        // Validate all phases belong to the project
        for phase in phases {
            if phase.projectId != project.id {
                throw ValidationError.invalidRelationship("フェーズ '\(phase.name)' がプロジェクトに属していません")
            }
        }
        
        // Validate phase order uniqueness
        let phaseOrders = phases.map { $0.order }
        if Set(phaseOrders).count != phaseOrders.count {
            throw ValidationError.duplicateEntry("フェーズの順序")
        }
    }
    
    static func validatePhaseHierarchy(phase: Phase, taskLists: [TaskList]) throws {
        // Validate all task lists belong to the phase
        for taskList in taskLists {
            if taskList.phaseId != phase.id || taskList.projectId != phase.projectId {
                throw ValidationError.invalidRelationship("タスクリスト '\(taskList.name)' がフェーズに属していません")
            }
        }
        
        // Validate task list order uniqueness
        let listOrders = taskLists.map { $0.order }
        if Set(listOrders).count != listOrders.count {
            throw ValidationError.duplicateEntry("タスクリストの順序")
        }
    }
    
    static func validateTaskListHierarchy(taskList: TaskList, tasks: [ShigodekiTask]) throws {
        // Validate all tasks belong to the task list
        for task in tasks {
            if task.listId != taskList.id || 
               task.phaseId != taskList.phaseId || 
               task.projectId != taskList.projectId {
                throw ValidationError.invalidRelationship("タスク '\(task.title)' がタスクリストに属していません")
            }
        }
        
        // Validate task order uniqueness
        let taskOrders = tasks.map { $0.order }
        if Set(taskOrders).count != taskOrders.count {
            throw ValidationError.duplicateEntry("タスクの順序")
        }
    }
    
    static func validateTaskHierarchy(task: ShigodekiTask, subtasks: [Subtask]) throws {
        // Validate all subtasks belong to the task
        for subtask in subtasks {
            if subtask.taskId != task.id ||
               subtask.listId != task.listId ||
               subtask.phaseId != task.phaseId ||
               subtask.projectId != task.projectId {
                throw ValidationError.invalidRelationship("サブタスク '\(subtask.title)' がタスクに属していません")
            }
        }
        
        // Validate subtask order uniqueness
        let subtaskOrders = subtasks.map { $0.order }
        if Set(subtaskOrders).count != subtaskOrders.count {
            throw ValidationError.duplicateEntry("サブタスクの順序")
        }
        
        // Validate task subtask counts
        if task.subtaskCount != subtasks.count {
            throw ValidationError.invalidRelationship("タスクのサブタスク数が実際のサブタスク数と一致しません")
        }
        
        let actualCompletedCount = subtasks.filter { $0.isCompleted }.count
        if task.completedSubtaskCount != actualCompletedCount {
            throw ValidationError.invalidRelationship("タスクの完了サブタスク数が実際の完了数と一致しません")
        }
    }
    
    // MARK: - Permission Validation
    
    static func validateUserProjectAccess(user: User, project: Project, requiredPermission: Permission) throws {
        guard project.memberIds.contains(user.id ?? "") else {
            throw ValidationError.invalidRelationship("ユーザーはプロジェクトのメンバーではありません")
        }
        
        guard let role = user.roleAssignments[project.id ?? ""] else {
            throw ValidationError.invalidRelationship("ユーザーのプロジェクト内でのロールが設定されていません")
        }
        
        if !role.permissions.contains(requiredPermission) {
            throw ValidationError.invalidRelationship("ユーザーには必要な権限がありません")
        }
    }
    
    static func validateProjectMemberConsistency(project: Project, members: [ProjectMember]) throws {
        // Check that all project memberIds have corresponding ProjectMember entries
        let memberUserIds = Set(members.map { $0.userId })
        let projectMemberIds = Set(project.memberIds)
        
        if memberUserIds != projectMemberIds {
            throw ValidationError.invalidRelationship("プロジェクトメンバーリストの整合性が取れていません")
        }
        
        // Validate all members belong to this project
        for member in members {
            if member.projectId != project.id {
                throw ValidationError.invalidRelationship("メンバーが異なるプロジェクトに属しています")
            }
        }
        
        // Validate owner exists and has owner role
        guard let ownerMember = members.first(where: { $0.userId == project.ownerId }) else {
            throw ValidationError.invalidRelationship("プロジェクトオーナーがメンバーに存在しません")
        }
        
        if ownerMember.role != .owner {
            throw ValidationError.invalidRelationship("プロジェクトオーナーのロールがオーナーに設定されていません")
        }
    }
    
    // MARK: - Task Dependencies
    
    static func validateTaskDependencies(tasks: [ShigodekiTask]) throws {
        let taskIds = Set(tasks.compactMap { $0.id })
        
        for task in tasks {
            // Check that all dependencies exist
            for dependencyId in task.dependsOn {
                if !taskIds.contains(dependencyId) {
                    throw ValidationError.invalidRelationship("タスク '\(task.title)' の依存関係に存在しないタスクが含まれています")
                }
            }
        }
        
        // Check for circular dependencies
        try validateNoCyclicDependencies(tasks: tasks)
    }
    
    private static func validateNoCyclicDependencies(tasks: [ShigodekiTask]) throws {
        let taskDict: [String: ShigodekiTask] = Dictionary(uniqueKeysWithValues: tasks.compactMap { task in
            guard let id = task.id else { return nil }
            return (id, task)
        })
        
        for task in tasks {
            guard let taskId = task.id else { continue }
            var visited = Set<String>()
            try checkCyclicDependency(taskId: taskId, taskDict: taskDict, visited: &visited, path: [])
        }
    }
    
    private static func checkCyclicDependency(taskId: String, taskDict: [String: ShigodekiTask], visited: inout Set<String>, path: [String]) throws {
        if path.contains(taskId) {
            throw ValidationError.invalidRelationship("タスクの依存関係に循環参照があります: \(path.joined(separator: " -> ")) -> \(taskId)")
        }
        
        if visited.contains(taskId) {
            return
        }
        
        visited.insert(taskId)
        
        guard let task = taskDict[taskId] else {
            return
        }
        
        let newPath = path + [taskId]
        for dependencyId in task.dependsOn {
            try checkCyclicDependency(taskId: dependencyId, taskDict: taskDict, visited: &visited, path: newPath)
        }
    }
    
    // MARK: - Statistics Validation
    
    static func validateProjectStatistics(project: Project, phases: [Phase], tasks: [ShigodekiTask], members: [ProjectMember]) throws {
        guard let stats = project.statistics else { return }
        
        // Validate task counts
        if stats.totalTasks != tasks.count {
            throw ValidationError.invalidRelationship("プロジェクトの総タスク数が実際のタスク数と一致しません")
        }
        
        let completedTasksCount = tasks.filter { $0.isCompleted }.count
        if stats.completedTasks != completedTasksCount {
            throw ValidationError.invalidRelationship("プロジェクトの完了タスク数が実際の完了数と一致しません")
        }
        
        // Validate phase count
        if stats.totalPhases != phases.count {
            throw ValidationError.invalidRelationship("プロジェクトの総フェーズ数が実際のフェーズ数と一致しません")
        }
        
        // Validate active member count (assuming all members are active for now)
        if stats.activeMembers != members.count {
            throw ValidationError.invalidRelationship("プロジェクトのアクティブメンバー数が実際のメンバー数と一致しません")
        }
    }
}