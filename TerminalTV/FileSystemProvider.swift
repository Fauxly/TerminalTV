//
//  FileSystemProvider.swift
//  TerminalTV
//
//  Created by Fix’s Trick’s on 29.05.2026.
//

import Foundation

final class FileSystemProvider {
    
    static let shared = FileSystemProvider()
    
    private(set) var currentPath = "/"
    
    func pwd() -> String {
        currentPath + "\n"
    }
    
    func list(path: String? = nil) -> String {

        let targetPath = path ?? currentPath

        do {

            let items = try FileManager.default
                .contentsOfDirectory(atPath: targetPath)

            if items.isEmpty {
                return "Directory is empty\n"
            }

            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB, .useGB]
            formatter.countStyle = .file

            var result = ""

            for item in items.sorted() {

                let fullPath = targetPath + "/" + item

                var isDir: ObjCBool = false

                FileManager.default.fileExists(
                    atPath: fullPath,
                    isDirectory: &isDir
                )

                if isDir.boolValue {

                    result += "📁 \(item)\n"

                } else {

                    let attrs =
                        try? FileManager.default
                        .attributesOfItem(
                            atPath: fullPath
                        )

                    let size =
                        attrs?[.size] as? Int64 ?? 0

                    let humanSize =
                        formatter.string(
                            fromByteCount: size
                        )

                    result += "📄 \(item) (\(humanSize))\n"
                }
            }

            return result

        } catch {

            return """
    Error:

    \(error.localizedDescription)

    """
        }
    }
    
    func tree(path: String? = nil) -> String {
        
        let targetPath = path ?? currentPath
        
        do {
            
            let items = try FileManager.default
                .contentsOfDirectory(atPath: targetPath)
            
            if items.isEmpty {
                return "Directory is empty\n"
            }
            
            return items
                .sorted()
                .map { "├── \($0)" }
                .joined(separator: "\n") + "\n"
            
        } catch {
            
            return """
Error:

\(error.localizedDescription)

"""
        }
    }
    
    func changeDirectory(_ path: String) -> String {
        
        if path == ".." {
            
            let parent =
            URL(fileURLWithPath: currentPath)
                .deletingLastPathComponent()
                .path
            
            currentPath =
            parent.isEmpty ? "/" : parent
            
            return "Current directory: \(currentPath)\n"
        }
        
        var targetPath = path
        
        if !targetPath.hasPrefix("/") {
            
            if currentPath == "/" {
                
                targetPath = "/" + path
                
            } else {
                
                targetPath =
                currentPath + "/" + path
            }
        }
        
        var isDirectory: ObjCBool = false
        
        if FileManager.default.fileExists(
            atPath: targetPath,
            isDirectory: &isDirectory
        ) && isDirectory.boolValue {
            
            currentPath = targetPath
            
            return "Current directory: \(currentPath)\n"
        }
        
        return """
Directory not found:

\(targetPath)

"""
    }
    
    func createDirectory(_ name: String) -> String {

        let path = currentPath + "/" + name

        do {

            try FileManager.default.createDirectory(
                atPath: path,
                withIntermediateDirectories: true
            )

            return """
    Directory created:

    \(name)

    Path:

    \(path)

    """
        } catch {

            return """
    Error:

    \(error.localizedDescription)

    Path:

    \(path)

    """
        }
    }
    
    func createFile(_ name: String) -> String {
        
        let path = currentPath + "/" + name
        
        let result =
        FileManager.default.createFile(
            atPath: path,
            contents: nil
        )
        
        return result
        ? "File created: \(name)\n"
        : "Failed to create file\n"
    }
    
    func readFile(_ name: String) -> String {
        
        let path = currentPath + "/" + name
        
        guard let text =
                try? String(
                    contentsOfFile: path
                ) else {
            
            return """
Unable to read file:

\(name)

"""
        }
        
        return text + "\n"
    }
    
    func writeFile(
        _ name: String,
        content: String
    ) -> String {
        
        let path = currentPath + "/" + name
        
        do {
            
            try content.write(
                toFile: path,
                atomically: true,
                encoding: .utf8
            )
            
            return "Written to file: \(name)\n"
            
        } catch {
            
            return """
Error:

\(error.localizedDescription)

"""
        }
    }
    
    func removeItem(_ name: String) -> String {
        
        let path = currentPath + "/" + name
        
        do {
            
            try FileManager.default.removeItem(
                atPath: path
            )
            
            return "Removed: \(name)\n"
            
        } catch {
            
            return "Error: \(error.localizedDescription)\n"
        }
    }
    
    func copyItem(
        from source: String,
        to destination: String
    ) -> String {
        
        let sourcePath =
        currentPath + "/" + source
        
        let destinationPath =
        currentPath + "/" + destination
        
        do {
            
            try FileManager.default.copyItem(
                atPath: sourcePath,
                toPath: destinationPath
            )
            
            return "Copied: \(source) -> \(destination)\n"
            
        } catch {
            
            return """
Error:

\(error.localizedDescription)

"""
        }
    }
    
    func moveItem(
        from source: String,
        to destination: String
    ) -> String {
        
        let sourcePath =
        currentPath + "/" + source
        
        let destinationPath =
        currentPath + "/" + destination
        
        do {
            
            try FileManager.default.moveItem(
                atPath: sourcePath,
                toPath: destinationPath
            )
            
            return "Moved: \(source) -> \(destination)\n"
            
        } catch {
            
            return """
Error:

\(error.localizedDescription)

"""
        }
    }
    
    func find(
        _ searchTerm: String
    ) -> String {
        
        do {
            
            let items =
            try FileManager.default
                .contentsOfDirectory(
                    atPath: currentPath
                )
            
            let results =
            items.filter {
                
                $0.localizedCaseInsensitiveContains(
                    searchTerm
                )
            }
            
            if results.isEmpty {
                
                return """
Nothing found:

\(searchTerm)

"""
            }
            
            return results.joined(
                separator: "\n"
            ) + "\n"
            
        } catch {
            
            return """
Error:

\(error.localizedDescription)

"""
        }
    }
    
    // MARK: - Stat
    
    func stat(_ name: String) -> String {
        
        let path = currentPath + "/" + name
        
        do {
            
            let attributes =
            try FileManager.default
                .attributesOfItem(
                    atPath: path
                )
            
            let size =
            attributes[.size] as? NSNumber ?? 0
            
            let created =
            attributes[.creationDate] as? Date
            
            let modified =
            attributes[.modificationDate] as? Date
            
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
            
            return """

Name: \(name)

Size: \(size) bytes

Created:
\(created.map {
formatter.string(from: $0)
} ?? "Unknown")

Modified:
\(modified.map {
formatter.string(from: $0)
} ?? "Unknown")

Path:
\(path)

"""
            
        } catch {
            
            return """
Error:

\(error.localizedDescription)

"""
        }
    }
    
    func openFile(_ name: String) -> String {
        
        let path = currentPath + "/" + name
        
        guard let content = try? String(
            contentsOfFile: path,
            encoding: .utf8
        ) else {
            
            return """
    Unable to open file:
    
    \(name)
    
    """
        }
        
        return """
    
    =================================
    \(name)
    =================================
    
    \(content)
    
    """
    }
    
    // MARK: - Append
    
    func appendToFile(
        _ name: String,
        content: String
    ) -> String {
        
        let path = currentPath + "/" + name
        
        guard let data =
                (content + "\n").data(
                    using: .utf8
                ) else {
            
            return "Encoding error\n"
        }
        
        if !FileManager.default.fileExists(
            atPath: path
        ) {
            
            FileManager.default.createFile(
                atPath: path,
                contents: data
            )
            
            return """
Created and appended:

\(name)

"""
        }
        
        do {
            
            let handle =
            try FileHandle(
                forWritingTo:
                    URL(fileURLWithPath: path)
            )
            
            handle.seekToEndOfFile()
            
            handle.write(data)
            
            try handle.close()
            
            return """
Appended to:

\(name)

"""
            
        } catch {
            
            return """
Error:

\(error.localizedDescription)

"""
        }
    }
    func diskInfo() -> String {

        let home = NSHomeDirectory()

        let readable =
            FileManager.default
            .isReadableFile(
                atPath: home
            )

        let writable =
            FileManager.default
            .isWritableFile(
                atPath: home
            )

        return """

    Disk Information

    Home Directory:
    \(home)

    File System:
    \(currentPath)

    Readable:
    \(readable ? "YES" : "NO")

    Writable:
    \(writable ? "YES" : "NO")

    """
    }
    func wordCount(_ name: String) -> String {

        let path = currentPath + "/" + name

        guard let content = try? String(
            contentsOfFile: path,
            encoding: .utf8
        ) else {

            return """
    Unable to read file:

    \(name)

    """
        }

        let lines =
            content.components(
                separatedBy: .newlines
            ).count

        let words =
            content.split {
                $0.isWhitespace
            }.count

        let characters =
            content.count

        return """

    File Statistics

    File:
    \(name)

    Lines:
    \(lines)

    Words:
    \(words)

    Characters:
    \(characters)

    """
    }
    func renameItem(
        from oldName: String,
        to newName: String
    ) -> String {

        let oldPath =
            currentPath + "/" + oldName

        let newPath =
            currentPath + "/" + newName

        do {

            try FileManager.default.moveItem(
                atPath: oldPath,
                toPath: newPath
            )

            return """

    Renamed:

    \(oldName)

    →

    \(newName)

    """

        } catch {

            return """
    Error:

    \(error.localizedDescription)

    """
        }
    }
    func longList() -> String {

        do {

            let items = try FileManager.default
                .contentsOfDirectory(
                    atPath: currentPath
                )

            if items.isEmpty {
                return "Directory is empty\n"
            }

            var result = ""

            for item in items.sorted() {

                let path =
                    currentPath + "/" + item

                var isDir: ObjCBool = false

                FileManager.default.fileExists(
                    atPath: path,
                    isDirectory: &isDir
                )

                result +=
                    isDir.boolValue
                    ? "[D] \(item)\n"
                    : "[F] \(item)\n"
            }

            return result

        } catch {

            return """
    Error:

    \(error.localizedDescription)

    """
        }
    }
    func sizeOfItem(_ name: String) -> String {

        let path = currentPath + "/" + name

        guard let attributes =
            try? FileManager.default
            .attributesOfItem(
                atPath: path
            ) else {

            return """
    Unable to get info:

    \(name)

    """
        }

        let size =
            attributes[.size] as? NSNumber ?? 0

        let mb =
            Double(truncating: size)
            / 1024
            / 1024

        return """

    \(name)

    Size:

    \(String(format: "%.2f", mb)) MB

    """
    }
    func fileInfo(_ name: String) -> String {

        let path = currentPath + "/" + name

        var isDir: ObjCBool = false

        guard FileManager.default.fileExists(
            atPath: path,
            isDirectory: &isDir
        ) else {

            return """
    File not found:

    \(name)

    """
        }

        if isDir.boolValue {

            return """

    Name:
    \(name)

    Type:
    Directory

    Path:
    \(path)

    """
        }

        if FileManager.default.isReadableFile(
            atPath: path
        ) {

            if let attrs =
                try? FileManager.default
                .attributesOfItem(
                    atPath: path
                ) {

                let size =
                    attrs[.size] as? NSNumber ?? 0

                return """

    Name:
    \(name)

    Type:
    File

    Size:
    \(size) bytes

    Path:
    \(path)

    """
            }
        }

        return """

    Name:
    \(name)

    Type:
    Unknown

    Path:
    \(path)

    """
    }
}

