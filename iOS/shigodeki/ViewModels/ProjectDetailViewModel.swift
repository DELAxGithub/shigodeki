//
//  ProjectDetailViewModel.swift
//  shigodeki
//
//  Lightweight VM to centralize project live-updates and lifecycle
//

import Foundation
import Combine

@MainActor
class ProjectDetailViewModel: ObservableObject {
    @Published private(set) var presentProject: Project
    private var cancellables = Set<AnyCancellable>()
    
    private var projectId: String? { presentProject.id }
    private var projectManager: ProjectManager?
    
    init(project: Project) {
        self.presentProject = project
    }
    
    func bootstrap(store: SharedManagerStore) async {
        guard let pid = projectId else { return }
        let pm = await store.getProjectManager()
        self.projectManager = pm
        
        // Start project detail listener (idempotent)
        pm.startListeningForProject(id: pid)
        
        // Subscribe to currentProject and map matching id
        pm.$currentProject
            .compactMap { [weak self] in
                guard let self = self else { return nil }
                guard let cp = $0, cp.id == self.presentProject.id else { return nil }
                return cp
            }
            .receive(on: RunLoop.main)
            .sink { [weak self] updated in
                self?.presentProject = updated
            }
            .store(in: &cancellables)
    }
}

