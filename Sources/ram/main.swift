#!/usr/bin/swift sh

import Foundation
import XcodeProj  // @tuist ~> 7.0.0
import PathKit

func log_error(_ msg: String) -> Never {
    fputs("\nERROR: \(msg)\n", stderr)
    
    exit(1)
}

func log_info(_ msg: String) {
    fputs("\nINFO: \(msg)\n", stderr)
}

public struct ProjectDescriptor {
    let projectPath: Path
    let xcodeproj: XcodeProj
    let target: String
    
    init?(projectPath: Path, target: String) {
        self.projectPath = projectPath
        self.target = target
        
        do {
            self.xcodeproj = try XcodeProj(path: projectPath)
        } catch {
            log_error(error.localizedDescription)
            return nil
        }
    }
}

final class FlatTool {
    private struct Constants {
        static let relocationFolderName = "tmp"
    }
    
    private let projectDescriptor: ProjectDescriptor
    private let project: PBXProject
    
    private var projectDirPath: Path {
        let pathString = (projectDescriptor.projectPath.string as NSString).deletingLastPathComponent
        
        return Path(pathString)
    }
    
    init(cliArguments: [String]) {
        self.projectDescriptor = type(of: self).makeProjectDescriptor(withArguments: cliArguments)
        
        if let project = projectDescriptor.xcodeproj.pbxproj.projects.first {
            self.project = project
        } else {
            log_error("Cannot get main project.")
        }
    }
    
    func start() {
        handle(project.mainGroup)
        
        save()
    }
    
    private func handle(_ group: PBXGroup) {
        
        
        group.children.forEach { element in
            if element is PBXGroup {
                handle(element as! PBXGroup)
                
                return
            }
        }
        
        do {
            print("NAME: " + (group.name ?? ""))
            let path = try group.fullPath(sourceRoot: projectDirPath)
            
            print(path)
        } catch {
            log_error(error.localizedDescription)
        }
    }
    
    private func fullPath(for group: PBXGroup) -> String {
        if group.parent != nil {
            fullPath(for: group.parent as)
        }
        
    }
    
    private func save() {
        let xcodeproj = projectDescriptor.xcodeproj
        
        do {
            try xcodeproj.write(path: projectDescriptor.projectPath)
        } catch {
            log_error(error.localizedDescription)
        }
    }
    
    private func makeRootGroup() -> PBXGroup {
        let rootGroups = project.mainGroup.children.compactMap({ $0 as? PBXGroup })
        let relocationFolderName = type(of: self).Constants.relocationFolderName
        let rootGroup = rootGroups.first { $0.name == relocationFolderName || $0.path == relocationFolderName }
        
        if let rootGroup = rootGroup {
            return rootGroup
        }
        
        let group = PBXGroup(
            children: [],
            sourceTree: .group,
            name: relocationFolderName,
            path: relocationFolderName
        )
        
        try? FileManager.default.createDirectory(atPath: projectDirPath.string + "/" + relocationFolderName, withIntermediateDirectories: true, attributes: nil)
        
        projectDescriptor.xcodeproj.pbxproj.add(object: group)
        project.mainGroup?.children.append(group)
        
        return group
    }
    
    private static func makeProjectDescriptor(withArguments args: [String]) -> ProjectDescriptor {
        guard args.count >= 3 else {
            log_error("Expected 2 arguments <path-to-project> <target>.")
        }
        
        let projectFullPath = args[1]
        let target = args[2]
        
        guard let projectDescriptor = ProjectDescriptor(projectPath: Path(projectFullPath), target: target) else {
            log_error("Cannot initialize project.")
        }
        
        return projectDescriptor
    }
}

let tool = FlatTool(cliArguments: CommandLine.arguments)

tool.start()
