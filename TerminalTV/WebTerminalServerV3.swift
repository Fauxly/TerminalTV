import Foundation
import Darwin
import Network
import SwiftUI
import Combine

// --- МОДЕЛЬ СИНХРОНИЗАЦИИ ---
class TerminalViewModel: ObservableObject {
    static let shared = TerminalViewModel()
    @Published var consoleOutput: String = "💀 Rootful Autonomous Terminal Ready."
    
    func appendText(_ text: String) {
        DispatchQueue.main.async {
            self.consoleOutput += "\n\(text)"
        }
    }
    
    func clearConsole() {
        DispatchQueue.main.async {
            self.consoleOutput = "🚀 Console cleared. Ready for input..."
        }
    }
}

typealias POpenType = @convention(c) (UnsafePointer<Int8>, UnsafePointer<Int8>) -> UnsafeMutableRawPointer?
typealias PCloseType = @convention(c) (UnsafeMutableRawPointer) -> Int32

final class WebTerminalServerV3 {
    static let shared = WebTerminalServerV3()
    
    private var listener: NWListener?
    private let baseDocumentsPath = "/var/mobile/Documents"
    private var currentSubDir = ""
    
    private var uploadHandle: FileHandle?
    private var expectedUploadSize = 0
    private var currentUploadPath = ""

    func start() {
        do {
            listener = try NWListener(using: .tcp, on: 8080)
            listener?.newConnectionHandler = { [weak self] connection in
                connection.start(queue: .global())
                self?.handleNewConnection(connection)
            }
            listener?.start(queue: .global())
        } catch { print("❌ Server error: \(error)") }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            guard let self = self, let data = data, error == nil else { return }
            let sep = Data("\r\n\r\n".utf8)
            if let range = data.range(of: sep) {
                let headerData = data.prefix(upTo: range.lowerBound)
                let bodyData = data.suffix(from: range.upperBound)
                guard let headerString = String(data: headerData, encoding: .utf8) else { return }
                
                if headerString.contains("POST /cmd") {
                    self.handleCommand(body: bodyData, on: connection)
                } else if headerString.contains("POST /upload") {
                    self.setupUpload(header: headerString, initialBody: bodyData, connection: connection)
                } else if headerString.contains("GET /files") {
                    self.sendFilesListPage(on: connection)
                } else if headerString.contains("GET /download?file=") {
                    self.handleDownload(request: headerString, on: connection)
                } else if headerString.contains("GET /delete?file=") {
                    self.handleDelete(request: headerString, on: connection)
                } else {
                    self.sendMainPage(on: connection)
                }
            }
        }
    }

    private func handleCommand(body: Data, on connection: NWConnection) {
        let command = String(data: body, encoding: .utf8) ?? ""
        let result = executeCommand(command)
        
        let response = "HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nConnection: close\r\n\r\n\(result)"
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed({ _ in connection.cancel() }))
    }

    // --- ЯДРО ТЕРМИНАЛА ---
    func executeCommand(_ command: String) -> String {
        let trimmedCmd = command.trimmingCharacters(in: .whitespaces)
        let parts = trimmedCmd.components(separatedBy: " ")
        let action = (parts.first ?? "").lowercased()
        
        if trimmedCmd.isEmpty { return "" }
        
        if action == "help" {

            let helpText = """
        Built-in commands:
        help
        clear
        cd
        pwd
        version
        about

        Shell commands:
        ls
        cp
        mv
        rm
        mkdir
        touch
        cat
        ps
        find
        which
        id
        whoami
        uname

        Any command from:
        /bin
        /usr/bin
        /usr/sbin
        /sbin
        """

            TerminalViewModel.shared.appendText("\n$ help\n\(helpText)")
            return helpText
        }

        if action == "clear" {
            TerminalViewModel.shared.clearConsole()
            return "CLEARED"
        }

        if action == "cd" {

            let target = parts.count > 1 ? parts[1] : "/"

            var newPath: String

            if target.hasPrefix("/") {

                newPath = URL(fileURLWithPath: target)
                    .standardizedFileURL
                    .path

            } else {

                let workDir: String

                if currentSubDir.hasPrefix("/") {
                    workDir = currentSubDir
                } else {
                    workDir = currentSubDir.isEmpty
                        ? baseDocumentsPath
                        : "\(baseDocumentsPath)/\(currentSubDir)"
                }

                newPath = URL(fileURLWithPath: workDir)
                    .appendingPathComponent(target)
                    .standardizedFileURL
                    .path
            }

            var isDir: ObjCBool = false

            if FileManager.default.fileExists(
                atPath: newPath,
                isDirectory: &isDir
            ), isDir.boolValue {

                currentSubDir = newPath

                let msg = "📂 \(newPath)"

                TerminalViewModel.shared.appendText(msg)

                return msg
            }

            return "❌ Error: Directory not found"
        }
        
        if action == "pwd" {

            let workDir: String

            if currentSubDir.hasPrefix("/") {
                workDir = currentSubDir
            } else {
                workDir = currentSubDir.isEmpty
                    ? baseDocumentsPath
                    : "\(baseDocumentsPath)/\(currentSubDir)"
            }

            TerminalViewModel.shared.appendText(workDir)

            return workDir
        }
        
        if action == "shellcheck" {

            let fm = FileManager.default

            return """
            /bin/sh = \(fm.fileExists(atPath: "/bin/sh"))
            /bin/bash = \(fm.fileExists(atPath: "/bin/bash"))
            /usr/bin/sh = \(fm.fileExists(atPath: "/usr/bin/sh"))
            /usr/bin/bash = \(fm.fileExists(atPath: "/usr/bin/bash"))
            """
        }

        if action == "version" {

            return "TerminalTV v1.0"
        }

        if action == "about" {

            return """
            TerminalTV
            Real Shell Terminal for tvOS

            Version: 1.0
            Shell: /usr/bin/sh

            Features:
            • Real shell commands
            • File Manager
            • File Upload
            • File Download
            • Command History
            • Web Terminal
            """
        }
        
        if action == "debug" {

            let current: String

            if currentSubDir.hasPrefix("/") {
                current = currentSubDir
            } else {
                current = currentSubDir.isEmpty
                    ? baseDocumentsPath
                    : "\(baseDocumentsPath)/\(currentSubDir)"
            }

            return """
            UID: \(getuid())
            EUID: \(geteuid())
            HOME: \(NSHomeDirectory())
            CURRENT: \(current)
            """
        }
        
        let sysPaths = "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin"
        let workDir: String

        if currentSubDir.hasPrefix("/") {
            workDir = currentSubDir
        } else {
            workDir = currentSubDir.isEmpty
                ? baseDocumentsPath
                : "\(baseDocumentsPath)/\(currentSubDir)"
        }
        let finalCmd = trimmedCmd
        
        TerminalViewModel.shared.appendText("\n📍 [\(currentSubDir.isEmpty ? "Documents" : currentSubDir)]\n$ \(trimmedCmd)")

        print("CMD PATH = \(workDir)")
        
        let fullCommand = "export PATH=\(sysPaths):$PATH && cd \(workDir) && \(finalCmd) 2>&1"
        
        let result = runSpawnCommand(fullCommand)

        print("COMMAND = \(fullCommand)")

        TerminalViewModel.shared.appendText(result)

        return result
    }
    
    func executeCommandExternally(_ command: String) -> String { return self.executeCommand(command) }

    // --- WEB UI С ИСТОРИЕЙ КОМАНД ЧЕРЕЗ СТРЕЛОЧКИ ---
    private func sendMainPage(on connection: NWConnection) {
        let html = """
        HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nConnection: close\r\n\r\n
        <html><head><meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body{font-family:monospace; background:#0a0a0a; color:#0f0; padding:20px; margin:0;} 
            .card{background:#161616; padding:25px; border-radius:12px; border:1px solid #333; max-width:850px; margin:10px auto; box-shadow:0 10px 30px rgba(0,0,0,0.5);} 
            #out{width:100%; height:380px; background:#000; color:#0f0; padding:15px; overflow-y:auto; border:1px solid #333; margin-bottom:15px; font-size:13px; line-height:1.4; white-space:pre-wrap;} 
            .input-group{display:flex; gap:10px;} 
            input[type="text"]{flex-grow:1; background:#000; border:1px solid #444; color:#0f0; padding:12px; outline:none; border-radius:4px;} 
            button{border:none; padding:10px 25px; border-radius:4px; cursor:pointer; font-weight:bold;} 
            .btn-run{background:#2979ff; color:#fff;} .btn-clear{background:#444; color:#fff;}
            .progress-container { width: 100%; background-color: #222; border-radius: 4px; margin-top: 15px; display: none; border: 1px solid #444; overflow: hidden; }
            .progress-bar { width: 0%; height: 20px; background-color: #00e676; text-align: center; line-height: 20px; color: #000; font-weight: bold; font-size: 12px; transition: width 0.1s linear; }
        </style>
        </head><body>
            <div class="card">
                <h1>📟 TerminalTV Remote</h1>
                <div id="out">Type 'help' to see commands. Use Up/Down arrows on keyboard for history.</div>
                <div class="input-group">
                    <input type="text" id="in" placeholder="Command..." autocomplete="off" autofocus>
                    <button class="btn-run" onclick="run()">RUN</button>
                    <button class="btn-clear" onclick="clearLogs()">CLEAR</button>
                </div>
                <hr style="border:0;border-top:1px solid #333;margin:25px 0;">
                <h1>📥 Upload File</h1>
                <div style="display:flex; gap:10px; align-items:center;">
                    <input type="file" id="fi" style="color: #eee;">
                    <button style="background:#00e676; color:#000; padding:10px 25px; border-radius:4px; border:none; cursor:pointer; font-weight:bold;" onclick="up()">UPLOAD</button>
                </div>
                <div class="progress-container" id="p_cont">
                    <div class="progress-bar" id="p_bar">0%</div>
                </div>
                <div style="margin-top:25px; text-align:center;"><a href="/files" style="color:#4da3ff; text-decoration:none; font-weight:bold;">📂 FILE MANAGER</a></div>
            </div>
        <script>
            // ГЛОБАЛЬНЫЙ МАССИВ ДЛЯ ИСТОРИИ КОМАНД
            let cmdHistory = [];
            let historyIndex = -1;

            async function clearLogs() {
                await fetch('/cmd', {method:'POST', body:'clear'});
                document.getElementById('out').innerText = 'Console cleared.';
            }

            async function run(){
                const i=document.getElementById('in'), o=document.getElementById('out'); 
                const cmd=i.value.trim(); 
                if(!cmd) return; 
                
                // Добавляем команду в историю, если она не повторяет предыдущую
                if (cmdHistory.length === 0 || cmdHistory[cmdHistory.length - 1] !== cmd) {
                    cmdHistory.push(cmd);
                }
                historyIndex = cmdHistory.length; // Сбрасываем указатель истории на конец

                if(cmd.toLowerCase()==='clear'){ clearLogs(); i.value=''; return; }
                o.innerText += '\\n$ ' + cmd; i.value=''; 
                
                const res = await fetch('/cmd', {method:'POST', body:cmd}); 
                const text = await res.text();
                if(text==='CLEARED') { o.innerText = 'Console cleared.'; } else { o.innerText += '\\n' + text; }
                o.scrollTop = o.scrollHeight;
            }

            // ПЕРЕХВАТ НАЖАТИЯ СТРЕЛОК КЛАВИАТУРЫ
            document.getElementById('in').addEventListener('keydown', function(event) {
                if (event.key === 'Enter') {
                    run();
                    event.preventDefault();
                }
                else if (event.key === 'ArrowUp') {
                    // Листаем историю ВВЕРХ
                    if (cmdHistory.length > 0 && historyIndex > 0) {
                        historyIndex--;
                        this.value = cmdHistory[historyIndex];
                    }
                    event.preventDefault(); // Блокируем стандартный сдвиг курсора в инпуте
                } 
                else if (event.key === 'ArrowDown') {
                    // Листаем историю ВНИЗ
                    if (cmdHistory.length > 0 && historyIndex < cmdHistory.length - 1) {
                        historyIndex++;
                        this.value = cmdHistory[historyIndex];
                    } else {
                        historyIndex = cmdHistory.length;
                        this.value = ''; // Если вышли в самый низ — очищаем строку
                    }
                    event.preventDefault();
                }
            });

            function up() {
                const fileInput = document.getElementById('fi');
                const f = fileInput.files[0]; 
                if(!f) return; 
                
                const pContainer = document.getElementById('p_cont');
                const pBar = document.getElementById('p_bar');
                pContainer.style.display = 'block';
                
                const x = new XMLHttpRequest();
                x.upload.onprogress = function(event) {
                    if (event.lengthComputable) {
                        const percentComplete = Math.round((event.loaded / event.total) * 100);
                        pBar.style.width = percentComplete + '%';
                        pBar.innerText = percentComplete + '%';
                    }
                };
                x.onload = function() {
                    if (x.status == 200) {
                        pBar.innerText = '🚀 Загрузка завершена!';
                        pBar.style.backgroundColor = '#2979ff';
                        setTimeout(() => { location.href='/files'; }, 1000);
                    } else {
                        pBar.innerText = '❌ Ошибка';
                        pBar.style.backgroundColor = '#ff1744';
                    }
                };
                x.open('POST','/upload'); 
                x.setRequestHeader('X-Filename', encodeURIComponent(f.name)); 
                x.send(f);
            }
        </script></body></html>
        """
        connection.send(content: html.data(using: .utf8), completion: .contentProcessed({ _ in connection.cancel() }))
    }

    // --- ОПЕРАЦИИ С ФАЙЛАМИ ЧЕРЕЗ SWIFT API ---
    private func setupUpload(header: String, initialBody: Data, connection: NWConnection) {
        var fname = "file_\(Int.random(in: 1000...9999)).bin"
        if let xf = header.range(of: "X-Filename: ") { fname = header[xf.upperBound...].components(separatedBy: "\r\n").first?.trimmingCharacters(in: .whitespaces) ?? fname }
        let decodedName = fname.removingPercentEncoding ?? fname
        
        let workDir: String

        if currentSubDir.hasPrefix("/") {
            workDir = currentSubDir
        } else {
            workDir = currentSubDir.isEmpty
                ? baseDocumentsPath
                : "\(baseDocumentsPath)/\(currentSubDir)"
        }
        self.currentUploadPath = "\(workDir)/\(decodedName)"
        
        FileManager.default.createFile(atPath: currentUploadPath, contents: nil)
        self.uploadHandle = FileHandle(forWritingAtPath: currentUploadPath)
        
        if !initialBody.isEmpty { self.uploadHandle?.write(initialBody) }
        self.receiveNextChunk(from: connection, totalBytes: initialBody.count)
    }
    
    private func receiveNextChunk(from connection: NWConnection, totalBytes: Int) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            if let d = data, !d.isEmpty {
                self.uploadHandle?.write(d)
                self.receiveNextChunk(from: connection, totalBytes: totalBytes + d.count)
            }
            else if isComplete {
                self.finishUpload(connection: connection)
            }
        }
    }
    
    private func finishUpload(connection: NWConnection) {
        self.uploadHandle?.closeFile()
        self.uploadHandle = nil
        connection.send(content: "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nOK".data(using: .utf8), completion: .contentProcessed({ _ in connection.cancel() }))
    }
    
    private func sendFilesListPage(on connection: NWConnection) {
        let workDir: String

        if currentSubDir.hasPrefix("/") {
            workDir = currentSubDir
        } else {
            workDir = currentSubDir.isEmpty
                ? baseDocumentsPath
                : "\(baseDocumentsPath)/\(currentSubDir)"
        }
        let files = (try? FileManager.default.contentsOfDirectory(atPath: workDir)) ?? []
        
        var rowsHtml = ""
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        
        for f in files {
            if f.hasPrefix(".") { continue }
            let fullPath = "\(workDir)/\(f)"
            
            let attributes = try? FileManager.default.attributesOfItem(atPath: fullPath)
            let fileSize = attributes?[.size] as? Int64 ?? 0
            let humanReadableSize = formatter.string(fromByteCount: fileSize)
            
            rowsHtml += """
            <tr style='border-bottom: 1px solid #333;'>
                <td style='padding:12px;'>📄 \(f)</td>
                <td style='padding:12px; color:#aaa;'>\(humanReadableSize)</td>
                <td style='padding:12px; text-align:center;'>
                    <a href='/download?file=\(f.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? f)' style='color:#00e676; font-weight:bold; text-decoration:none; margin-right:15px;'>[Скачать]</a>
                    <a href='/delete?file=\(f.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? f)' style='color:#ff1744; font-weight:bold; text-decoration:none;'>[Удалить]</a>
                </td>
            </tr>
            """
        }
        
        if rowsHtml.isEmpty {
            rowsHtml = "<tr><td colspan='3' style='padding:20px; text-align:center; color:#666;'>Папка пуста</td></tr>"
        }
        
        let html = """
        HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nConnection: close\r\n\r\n
        <html><head><meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body{background:#0a0a0a; color:#eee; font-family:monospace; padding:20px; margin:0;}
            .container{max-width:900px; margin:0 auto; background:#161616; padding:25px; border-radius:12px; border:1px solid #333; box-shadow:0 10px 30px rgba(0,0,0,0.5);}
            h1{color:#2979ff; margin-top:0;}
            table{width:100%; border-collapse:collapse; margin-top:15px;}
            th{background:#222; color:#0f0; text-align:left; padding:12px; border:1px solid #333;}
            .back-btn{display:inline-block; margin-top:25px; color:#2979ff; text-decoration:none; font-weight:bold; font-size:15px;}
        </style>
        </head><body><div class="container">
            <h1>📂 Профессиональный Менеджер Файлов</h1>
            <p style="color:#0f0; font-size:14px;">📍 Текущий путь: \(workDir)</p>
            <hr style="border:0; border-top:1px solid #333; margin:20px 0;">
            <table>
                <tr>
                    <th>Имя файла</th>
                    <th>Размер</th>
                    <th style="text-align:center; width:200px;">Действия</th>
                </tr>
                \(rowsHtml)
            </table>
            <a href="/" class="back-btn">⬅ Назад в Терминал</a>
        </div></body></html>
        """
        connection.send(content: html.data(using: .utf8), completion: .contentProcessed({ _ in connection.cancel() }))
    }
    
    private func handleDownload(request: String, on connection: NWConnection) {
        let workDir: String

        if currentSubDir.hasPrefix("/") {
            workDir = currentSubDir
        } else {
            workDir = currentSubDir.isEmpty
                ? baseDocumentsPath
                : "\(baseDocumentsPath)/\(currentSubDir)"
        }
        guard let urlRange = request.range(of: "file="),
              let filePart = request[urlRange.upperBound...].components(separatedBy: " ").first?.removingPercentEncoding else {
            let errorResponse = "HTTP/1.1 400 Bad Request\r\nConnection: close\r\n\r\nMissing filename"
            connection.send(content: errorResponse.data(using: .utf8), completion: .contentProcessed({ _ in connection.cancel() }))
            return
        }
        
        let fullPath = "\(workDir)/\(filePart)"
        
        if FileManager.default.fileExists(atPath: fullPath), let fileData = try? Data(contentsOf: URL(fileURLWithPath: fullPath)) {
            let header = """
            HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Disposition: attachment; filename="\(filePart)"\r\nContent-Length: \(fileData.count)\r\nConnection: close\r\n\r\n
            """
            var totalData = header.data(using: .utf8) ?? Data()
            totalData.append(fileData)
            connection.send(content: totalData, completion: .contentProcessed({ _ in connection.cancel() }))
        } else {
            let notFound = "HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\nFile not found"
            connection.send(content: notFound.data(using: .utf8), completion: .contentProcessed({ _ in connection.cancel() }))
        }
    }

    private func handleDelete(request: String, on connection: NWConnection) {
        let workDir: String

        if currentSubDir.hasPrefix("/") {
            workDir = currentSubDir
        } else {
            workDir = currentSubDir.isEmpty
                ? baseDocumentsPath
                : "\(baseDocumentsPath)/\(currentSubDir)"
        }
        if let name = request.components(separatedBy: "file=").last?.components(separatedBy: " ").first?.removingPercentEncoding {
            let fileToDelete = "\(workDir)/\(name)"
            try? FileManager.default.removeItem(atPath: fileToDelete)
        }
        connection.send(content: "HTTP/1.1 302 Found\r\nLocation: /files\r\n\r\n".data(using: .utf8), completion: .contentProcessed({ _ in connection.cancel() }))
        }
    
    func runSpawnCommand(_ command: String) -> String {

        var pipeFD: [Int32] = [0, 0]

        let pipeResult = pipe(&pipeFD)

        if pipeResult != 0 {
            return "pipe failed: \(pipeResult)"
        }

        var pid: pid_t = 0

        let shell = strdup("/bin/sh")
        let arg1 = strdup("-c")
        let arg2 = strdup(command)

        defer {
            free(shell)
            free(arg1)
            free(arg2)
        }

        var argv: [UnsafeMutablePointer<CChar>?] = [
            shell,
            arg1,
            arg2,
            nil
        ]
        
        let libc = dlopen(nil, RTLD_NOW)

        guard let initPtr = dlsym(
            libc,
            "posix_spawn_file_actions_destroy"
        ) else {
            return "init not found"
        }

        let actions = UnsafeMutableRawPointer.allocate(
            byteCount: 128,
            alignment: 8
        )

        defer {
            actions.deallocate()
        }

        typealias SpawnInitType = @convention(c)
        (
            UnsafeMutableRawPointer?
        ) -> Int32

        let spawnInit = unsafeBitCast(
            initPtr,
            to: SpawnInitType.self
        )

        _ = spawnInit(actions)

        guard let adddup2Ptr = dlsym(
            libc,
            "posix_spawn_file_actions_adddup2"
        ) else {
            return "adddup2 not found"
        }

        typealias AddDup2Type = @convention(c)
        (
            UnsafeMutableRawPointer?,
            Int32,
            Int32
        ) -> Int32

        let adddup2 = unsafeBitCast(
            adddup2Ptr,
            to: AddDup2Type.self
        )

        _ = adddup2(
            actions,
            pipeFD[1],
            1
        )
        
        _ = adddup2(
            actions,
            pipeFD[1],
            2
        )
        
        guard let addclosePtr = dlsym(
            libc,
            "posix_spawn_file_actions_addclose"
        ) else {
            return "addclose not found"
        }

        typealias AddCloseType = @convention(c)
        (
            UnsafeMutableRawPointer?,
            Int32
        ) -> Int32

        let addclose = unsafeBitCast(
            addclosePtr,
            to: AddCloseType.self
        )

        _ = addclose(
            actions,
            pipeFD[0]
        )
        
        guard let spawnPtr = dlsym(
            libc,
            "posix_spawn"
        ) else {
            return "spawn not found"
        }

        typealias PosixSpawnType = @convention(c)
        (
            UnsafeMutablePointer<pid_t>?,
            UnsafePointer<CChar>?,
            UnsafeMutableRawPointer?,
            UnsafeMutableRawPointer?,
            UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?,
            UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
        ) -> Int32

        let spawn = unsafeBitCast(
            spawnPtr,
            to: PosixSpawnType.self
        )

        let spawnResult = spawn(
            &pid,
            "/bin/sh",
            actions,
            nil,
            &argv,
            nil
        )

        if spawnResult != 0 {
            return "spawn failed: \(spawnResult)"
        }

        close(pipeFD[1])

        var buffer = [UInt8](repeating: 0, count: 65536)

        let bytesRead = read(
            pipeFD[0],
            &buffer,
            buffer.count
        )

        var status: Int32 = 0
        waitpid(pid, &status, 0)

        close(pipeFD[0])

        let output: String

        if bytesRead > 0 {

            output = String(
                decoding: buffer[0..<bytesRead],
                as: UTF8.self
            )

        } else {

            output = "<no output>"
        }
        
        return output.isEmpty ? "<no output>" : output

    }
}
