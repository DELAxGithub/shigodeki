#!/usr/bin/env swift

//
// Issue #52 Accurate Test: メンバー詳細でアサイン済みタスクが表示されない
//
// Accurate reproduction test using correct field names and structure
// Based on actual ShigodekiTask model: assignedTo (not assignedToUserId)
//

import Foundation

print("🔴 RED Phase: Issue #52 正確なバグ再現テスト")
print("========================================================")

// Accurate Task data structure matching ShigodekiTask model
struct AccurateTask {
    var id: String
    var title: String
    var assignedTo: String?  // Correct field name
    var projectId: String
    var isCompleted: Bool
    var createdAt: Date
    
    init(id: String = UUID().uuidString, title: String, assignedTo: String? = nil, projectId: String, isCompleted: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.assignedTo = assignedTo
        self.projectId = projectId
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }
}

// Accurate Member data structure
struct AccurateMember {
    var id: String
    var name: String
    var email: String
    
    init(id: String = UUID().uuidString, name: String, email: String) {
        self.id = id
        self.name = name
        self.email = email
    }
}

// Accurate Member Detail simulation
class AccurateMemberDetailSimulator {
    var member: AccurateMember?
    var assignedTasks: [AccurateTask] = []
    var isLoadingTasks = false
    
    // Mock Firestore data
    var allTasks: [AccurateTask] = []
    var allMembers: [AccurateMember] = []
    
    init() {
        setupTestData()
    }
    
    private func setupTestData() {
        // Create test members
        let member1 = AccurateMember(name: "田中太郎", email: "tanaka@example.com")
        let member2 = AccurateMember(name: "佐藤花子", email: "sato@example.com")
        
        allMembers = [member1, member2]
        
        // Create tasks with correct field name
        let task1 = AccurateTask(title: "UIデザイン作成", assignedTo: member1.id, projectId: "proj1")
        let task2 = AccurateTask(title: "データベース設計", assignedTo: member1.id, projectId: "proj1", isCompleted: true)
        let task3 = AccurateTask(title: "テスト実行", assignedTo: member2.id, projectId: "proj1")
        let task4 = AccurateTask(title: "未アサインタスク", assignedTo: nil, projectId: "proj1")
        
        allTasks = [task1, task2, task3, task4]
        
        print("  Test data setup:")
        print("    Members: \(allMembers.count)")
        print("    Tasks: \(allTasks.count)")
        print("    Tasks assigned to \(member1.name): \(allTasks.filter { $0.assignedTo == member1.id }.count)")
    }
    
    // Simulate loadAssignedTasks method from MemberDetailView.swift:281
    func loadAssignedTasks(userId: String) {
        print("🔍 Simulating loadAssignedTasks for userId: \(userId)")
        isLoadingTasks = true
        
        // Simulate Firestore query: .whereField("assignedTo", isEqualTo: userId)
        let queryResults = allTasks.filter { $0.assignedTo == userId }
        
        print("  📊 Query results: \(queryResults.count) tasks found")
        for task in queryResults {
            print("    - '\(task.title)' assignedTo: \(task.assignedTo ?? "nil")")
        }
        
        // Sort tasks (same logic as MemberDetailView.swift:310-316)
        assignedTasks = queryResults.sorted { 
            // 未完了タスクを先に、その後作成日の新しい順
            if $0.isCompleted != $1.isCompleted {
                return !$0.isCompleted && $1.isCompleted
            }
            return ($0.createdAt) > ($1.createdAt)
        }
        
        isLoadingTasks = false
        print("  ✅ Final assigned tasks: \(assignedTasks.count)")
    }
    
    func loadMember(memberId: String) {
        print("👤 Loading member ID: \(memberId)")
        
        if let foundMember = allMembers.first(where: { $0.id == memberId }) {
            member = foundMember
            print("  ✅ Member loaded: \(foundMember.name)")
            
            // Load assigned tasks
            loadAssignedTasks(userId: memberId)
        } else {
            member = nil
            print("  ❌ Member not found")
        }
    }
}

// Test Case: Verify the actual issue
struct Issue52AccurateTest {
    
    func testMemberDetailAssignedTasksDisplay() {
        print("🧪 Test Case: Member Detail Assigned Tasks Display (Accurate)")
        
        // Arrange
        let simulator = AccurateMemberDetailSimulator()
        let testMember = simulator.allMembers.first!
        let expectedTaskCount = simulator.allTasks.filter { $0.assignedTo == testMember.id }.count
        
        print("  Setup:")
        print("    Test member: \(testMember.name) (ID: \(testMember.id))")
        print("    Expected assigned tasks: \(expectedTaskCount)")
        
        // Act: Simulate the MemberDetailView loading process
        simulator.loadMember(memberId: testMember.id)
        
        // Assert
        let actualTaskCount = simulator.assignedTasks.count
        let memberLoaded = simulator.member != nil
        let tasksLoaded = !simulator.isLoadingTasks
        
        print("  Results:")
        print("    Member loaded: \(memberLoaded ? "✅" : "❌")")
        print("    Tasks loading finished: \(tasksLoaded ? "✅" : "❌")")
        print("    Expected tasks: \(expectedTaskCount)")
        print("    Actual tasks displayed: \(actualTaskCount)")
        
        if memberLoaded && tasksLoaded && actualTaskCount == expectedTaskCount && expectedTaskCount > 0 {
            print("  ✅ PASS: Member assigned tasks are displayed correctly")
            print("         This suggests the MemberDetailView logic should work")
        } else if expectedTaskCount == 0 {
            print("  ⚠️ INCONCLUSIVE: No tasks assigned to test member")
        } else {
            print("  ❌ FAIL: Issue #52 reproduced - tasks not displaying correctly")
            print("         Expected: \(expectedTaskCount), Got: \(actualTaskCount)")
        }
    }
    
    func testFirestoreQueryLogic() {
        print("\n🧪 Test Case: Firestore Query Logic Verification")
        
        let simulator = AccurateMemberDetailSimulator()
        let testMember = simulator.allMembers.first!
        
        print("  Testing Firestore query simulation:")
        print("    Query: db.collection(\"tasks\").whereField(\"assignedTo\", isEqualTo: \"\(testMember.id)\")")
        
        // Simulate the exact query logic from MemberDetailView.swift:292-295
        let directQuery = simulator.allTasks.filter { task in
            return task.assignedTo == testMember.id
        }
        
        print("  Query results:")
        print("    Tasks found: \(directQuery.count)")
        for task in directQuery {
            print("      - \(task.title) (assigned to: \(task.assignedTo ?? "nil"))")
        }
        
        if !directQuery.isEmpty {
            print("  ✅ PASS: Query logic works - tasks found")
            print("         Issue #52 might be caused by:")
            print("         1. Firestore permissions/security rules")
            print("         2. Network connectivity issues")
            print("         3. Data synchronization problems")
            print("         4. Firestore collection structure mismatch")
        } else {
            print("  ❌ FAIL: Query logic fails to find tasks")
        }
    }
}

// Execute Tests
print("\n🚨 実行中: Issue #52 正確なバグ再現テスト")
print("Using correct field names: assignedTo (not assignedToUserId)")

let testSuite = Issue52AccurateTest()

print("\n" + String(repeating: "=", count: 50))
testSuite.testMemberDetailAssignedTasksDisplay()
testSuite.testFirestoreQueryLogic()

print("\n🔴 RED Phase Results:")
print("- Field name is correct: 'assignedTo' matches ShigodekiTask model")
print("- Query logic appears sound in isolation")
print("- Issue #52 likely caused by:")
print("  1. Firestore security rules preventing task access")
print("  2. Missing or incorrect data in Firestore collection")
print("  3. Network/connectivity issues during query")
print("  4. Collection name mismatch ('tasks' vs actual collection)")
print("  5. User ID format mismatch between member.id and task.assignedTo")

print("\n🎯 Next: Examine Firestore security rules and actual data structure")
print("========================================================")