//
//  TerminalSession.swift
//  TerminalTV
//
//  Created by Fix’s Trick’s on 29.05.2026.
//

import Foundation

final class TerminalSession: ObservableObject {
    static let shared = TerminalSession()

    @Published var output = """
root@AppleTV:~#

Welcome to TerminalTV
tvOS Terminal for Jailbroken Apple TV

"""

    @Published var commandHistory: [String] = []

    private let historyKey = "TerminalHistory"

    private init() {

        commandHistory =
            UserDefaults.standard.stringArray(
                forKey: historyKey
            ) ?? []
    }

    func execute(_ command: String) {

        let trimmed = command.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmed.isEmpty else {
            return
        }

        commandHistory.append(trimmed)

        UserDefaults.standard.set(
            commandHistory,
            forKey: historyKey
        )

        output += "\nroot@AppleTV:~# \(trimmed)\n\n"

        switch trimmed.lowercased() {

        case "help":

            output += """
Available commands:

Navigation:
pwd
cd
root
var
apps
home
system
private
favorites

File System:
ls
ll
lsroot
lsvar
tree
file

mkdir
touch
write
cat
rm
append

cp
mv
find
stat
open
wc
du
rename

System:
info
systeminfo
memory
uptime
hostname
neofetch
diskinfo

Shell:
shelltest
shellstatus
shellversion
whoami
uname
id

Other:
help
about
banner
clear
cls
recent
clearhistory
date
version
echo
exit

"""

        case "pwd":

            output += FileSystemProvider.shared.pwd()
            output += "\n"

        case "root":

            output += FileSystemProvider.shared
                .changeDirectory("/")

            output += "\n"

        case "var":

            output += FileSystemProvider.shared
                .changeDirectory("/var")

            output += "\n"

        case "apps":

            output += FileSystemProvider.shared
                .changeDirectory("/Applications")

            output += "\n"

        case "home":

            output += FileSystemProvider.shared
                .changeDirectory(NSHomeDirectory())

            output += "\n"

        case "system":

            output += FileSystemProvider.shared
                .changeDirectory("/System")

            output += "\n"

        case "private":

            output += FileSystemProvider.shared
                .changeDirectory("/private")

            output += "\n"
            
        case "favorites":

            output += """

        Favorites:

        /
        /var
        /Applications
        /System
        /private

        """

        case "dir":

            output += FileSystemProvider.shared.list()
            output += "\n"

        case "ll":

            output += FileSystemProvider.shared
                .longList()

            output += "\n"
        
        case "ls":

            output += FileSystemProvider.shared.list()
            output += "\n"

        case let cmd where cmd.hasPrefix("cd "):

            let path = String(cmd.dropFirst(3))

            output += FileSystemProvider.shared
                .changeDirectory(path)

            output += "\n"

        case let cmd where cmd.hasPrefix("mkdir "):

            let name = String(cmd.dropFirst(6))

            output += FileSystemProvider.shared
                .createDirectory(name)

            output += "\n"

        case let cmd where cmd.hasPrefix("touch "):

            let name = String(cmd.dropFirst(6))

            output += FileSystemProvider.shared
                .createFile(name)

            output += "\n"

        case let cmd where cmd.hasPrefix("cat "):

            let name = String(cmd.dropFirst(4))

            output += FileSystemProvider.shared
                .readFile(name)

            output += "\n"

        case let cmd where cmd.hasPrefix("write "):

            let parts = cmd.split(
                separator: " ",
                maxSplits: 2
            )

            guard parts.count == 3 else {

                output += """

Usage:

write filename text

"""

                break
            }

            let fileName = String(parts[1])
            let text = String(parts[2])

            output += FileSystemProvider.shared
                .writeFile(
                    fileName,
                    content: text
                )

            output += "\n"

        case let cmd where cmd.hasPrefix("rm "):

            let name = String(cmd.dropFirst(3))

            output += FileSystemProvider.shared
                .removeItem(name)

            output += "\n"

        case let cmd where cmd.hasPrefix("cp "):

            let parts =
                cmd.split(separator: " ")

            guard parts.count == 3 else {

                output += """
        Usage:

        cp source destination

        """

                break
            }

            output += FileSystemProvider.shared
                .copyItem(
                    from: String(parts[1]),
                    to: String(parts[2])
                )

            output += "\n"

        case let cmd where cmd.hasPrefix("mv "):

            let parts =
                cmd.split(separator: " ")

            guard parts.count == 3 else {

                output += """
        Usage:

        mv source destination

        """

                break
            }

            output += FileSystemProvider.shared
                .moveItem(
                    from: String(parts[1]),
                    to: String(parts[2])
                )

            output += "\n"

        case let cmd where cmd.hasPrefix("find "):

            let search =
                String(cmd.dropFirst(5))

            output += FileSystemProvider.shared
                .find(search)

            output += "\n"
 
        case "root":

            output += FileSystemProvider.shared
                .changeDirectory("/")

            output += "\n"

        case "var":

            output += FileSystemProvider.shared
                .changeDirectory("/var")

            output += "\n"

        case "apps":

            output += FileSystemProvider.shared
                .changeDirectory("/Applications")

            output += "\n"

        case "home":

            output += FileSystemProvider.shared
                .changeDirectory(NSHomeDirectory())

            output += "\n"
            
        case let cmd where cmd.hasPrefix("stat "):
            

            let name =
                String(cmd.dropFirst(5))

            output += FileSystemProvider.shared
                .stat(name)

            output += "\n"
            
        case let cmd where cmd.hasPrefix("du "):

            let name =
                String(cmd.dropFirst(3))

            output += FileSystemProvider.shared
                .sizeOfItem(name)

            output += "\n"
            
        case let cmd where cmd.hasPrefix("open "):

            let name =
                String(cmd.dropFirst(5))

            output += FileSystemProvider.shared
                .openFile(name)

            output += "\n"
            
        case let cmd where cmd.hasPrefix("file "):

            let name =
                String(cmd.dropFirst(5))

            output += FileSystemProvider.shared
                .fileInfo(name)

            output += "\n"
        
        case let cmd where cmd.hasPrefix("append "):

            let parts =
                cmd.split(
                    separator: " ",
                    maxSplits: 2
                )

            guard parts.count == 3 else {

                output += """

        Usage:

        append filename text

        """

                break
            }

            let fileName =
                String(parts[1])

            let text =
                String(parts[2])

            output += FileSystemProvider.shared
                .appendToFile(
                    fileName,
                    content: text
                )

            output += "\n"
     
        case "diskinfo":

            output += FileSystemProvider.shared
                .diskInfo()

            output += "\n"
     
        case "recent":

            let recentCommands =
                commandHistory.suffix(10)

            if recentCommands.isEmpty {

                output += """
        No recent commands.

        """

            } else {

                output += """
        Recent Commands:

        """

                for cmd in recentCommands {

                    output += "\(cmd)\n"
                }

                output += "\n"
            }
            
        case "shelltest":

            output += ShellExecutor.shared
                .execute("test")

            output += "\n"

        case "shellstatus":

            output += ShellExecutor.shared
                .execute("status")

            output += "\n"

        case "shellversion":

            output += ShellExecutor.shared
                .execute("version")

            output += "\n"

        case let cmd where cmd.hasPrefix("wc "):

            let name =
                String(cmd.dropFirst(3))

            output += FileSystemProvider.shared
                .wordCount(name)

            output += "\n"
 
        case let cmd where cmd.hasPrefix("rename "):

            let parts =
                cmd.split(separator: " ")

            guard parts.count == 3 else {

                output += """

        Usage:

        rename oldname newname

        """

                break
            }

            output += FileSystemProvider.shared
                .renameItem(
                    from: String(parts[1]),
                    to: String(parts[2])
                )

            output += "\n"
            
        case "whoami":

            output += ShellExecutor.shared
                .execute("whoami")

            output += "\n"

        case "uname":

            output += ShellExecutor.shared
                .execute("uname")

            output += "\n"

        case "id":

            output += ShellExecutor.shared
                .execute("id")

            output += "\n"
            
        case "about":

            output += """
TerminalTV

A terminal emulator for jailbroken Apple TV.

Developer: Fix's Trick's
Version: 1.5

"""

        case "banner":

            output += """

████████╗███████╗██████╗ ███╗   ███╗██╗███╗   ██╗ █████╗ ██╗
╚══██╔══╝██╔════╝██╔══██╗████╗ ████║██║████╗  ██║██╔══██╗██║
   ██║   █████╗  ██████╔╝██╔████╔██║██║██╔██╗ ██║███████║██║
   ██║   ██╔══╝  ██╔══██╗██║╚██╔╝██║██║██║╚██╗██║██╔══██║██║
   ██║   ███████╗██║  ██║██║ ╚═╝ ██║██║██║ ╚████║██║  ██║███████╗
   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝

"""

        case "history":

            if commandHistory.isEmpty {

                output += "No history\n\n"

            } else {

                for (index, cmd) in commandHistory.enumerated() {
                    output += "\(index + 1). \(cmd)\n"
                }

                output += "\n"
            }

        case "date":

            let formatter = DateFormatter()
            formatter.dateStyle = .full
            formatter.timeStyle = .medium

            output += formatter.string(from: Date())
            output += "\n\n"

        case "version":

            output += "TerminalTV v1.5\n\n"

        case "info":

            output += """
tvOS:
\(ProcessInfo.processInfo.operatingSystemVersionString)

"""

        case "memory":

            let memory =
                Double(ProcessInfo.processInfo.physicalMemory)
                / 1024 / 1024 / 1024

            output += """
RAM: \(String(format: "%.2f", memory)) GB

"""

        case "uptime":

            let uptime =
                ProcessInfo.processInfo.systemUptime

            let hours = Int(uptime) / 3600
            let minutes = (Int(uptime) % 3600) / 60

            output += """
Uptime: \(hours)h \(minutes)m

"""

        case "systeminfo":

            output += SystemInfoProvider.shared
                .deviceInfo()

            output += "\n"

        case "hostname":

            output += "Apple-TV\n\n"

        case "clearhistory":

            commandHistory.removeAll()

            UserDefaults.standard.removeObject(
                forKey: historyKey
            )

            output += "History cleared.\n\n"

        case let cmd where cmd.hasPrefix("echo "):

            output += String(cmd.dropFirst(5))
            output += "\n\n"

        case "cls", "clear":

            clear()

        case "exit":

            output += """
Use Home button to close TerminalTV.

"""

        default:

            output += """
Unknown command:

\(trimmed)

Type 'help' for available commands.

"""
        }
    }

    func clear() {

        output = """
root@AppleTV:~#

Welcome to TerminalTV
tvOS Terminal for Jailbroken Apple TV

"""
    }
}
