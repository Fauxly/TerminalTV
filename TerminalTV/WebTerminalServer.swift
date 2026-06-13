////  WebTerminalServer.swift//  TerminalTV////  Created by Fix’s Trick’s on 30.05.2026.//

////  WebTerminalServer.swift//  TerminalTV////  Created by Fix’s Trick’s on 30.05.2026.//

import Foundation
import Network

final class WebTerminalServer {

static let shared = WebTerminalServer()

private var listener: NWListener?
private var uploadBuffer = Data()

func start() {

    do {

        listener = try NWListener(
            using: .tcp,
            on: 8080
        )

        listener?.newConnectionHandler = { connection in

            connection.start(
                queue: DispatchQueue.global()
            )
            /*
            self.receiveAllData(
                from: connection
            ) { data in

                print(
                    "FULL REQUEST:",
                    data.count
                )
            }
            */
            self.uploadBuffer.removeAll()

            connection.receive(
                minimumIncompleteLength: 1,
                maximumLength: 65536
            ) { data, _, isComplete, error in
                
                print(
                        "RECEIVED BYTES:",
                        data?.count ?? 0
                    )
                
                if let data = data {

                    self.uploadBuffer.append(data)

                    print(
                        "TOTAL BUFFER:",
                        self.uploadBuffer.count
                    )
                }
                
                if !isComplete {

                    connection.receive(
                        minimumIncompleteLength: 1,
                        maximumLength: 65536
                    ) { _, _, _, _ in }

                    print(
                        "WAITING FOR MORE DATA..."
                    )
                }

                let request =
                    String(
                        data: data ?? Data(),
                        encoding: .utf8
                    ) ?? ""

                print("===== REQUEST =====")
                print(request)
                print("===================")
                
                print(
                    "UPLOAD CHECK:",
                    request.contains("POST /upload")
                )

                if request.contains("/run?cmd=") {

                    let parts =
                        request.components(
                            separatedBy: "/run?cmd="
                        )

                    if parts.count > 1 {

                        let cmdPart =
                            parts[1]
                                .components(
                                    separatedBy: " "
                                )
                                .first ?? ""

                        let command =
                            cmdPart
                                .removingPercentEncoding
                                ?? ""

                        DispatchQueue.main.sync {

                            TerminalSession.shared
                                .execute(command)
                        }

                        let output =
                            TerminalSession.shared.output

                        let response = """
                        HTTP/1.1 200 OK\r
                        Content-Type: text/plain; charset=utf-8\r
                        Connection: close\r
                        \r
                        \(output)
                        """

                        connection.send(
                            content: response.data(
                                using: .utf8
                            ),
                            completion: .contentProcessed { _ in

                                connection.cancel()
                            }
                        )

                        return
                    }
                }
                
                struct UploadedFile: Codable {

                    let name: String
                    let bytes: [UInt8]
                }
                
                if request.contains("POST /upload HTTP/1.1") {

                    print("UPLOAD DETECTED")

                    if let separator =
                        request.range(
                            of: "\r\n\r\n"
                        ) {

                        let body =
                            String(
                                request[
                                    separator.upperBound...
                                ]
                            )
                        
                        if let jsonData =
                            body.data(
                                using: .utf8
                            ) {

                            if let file =
                                try? JSONDecoder()
                                    .decode(
                                        UploadedFile.self,
                                        from: jsonData
                                    ) {

                                let path =
                                    "/var/mobile/Documents/" +
                                    file.name

                                do {

                                    let data =
                                        Data(file.bytes)

                                    try data.write(
                                        to: URL(
                                            fileURLWithPath: path
                                        )
                                    )

                                    print(
                                        "FILE SAVED:",
                                        path
                                    )

                                } catch {

                                    print(
                                        "SAVE ERROR:",
                                        error
                                    )
                                }
                            }
                        }

                        print(
                            "BODY SIZE:",
                            body.count
                        )

                        print(
                            "FIRST 100:",
                            body.prefix(100)
                        )
                    }

                    let response = """
                    HTTP/1.1 200 OK\r
                    Content-Type: text/plain\r
                    Connection: close\r
                    \r
                    Upload endpoint detected
                    """

                    connection.send(
                        content: response.data(
                            using: .utf8
                        ),
                        completion: .contentProcessed { _ in

                            connection.cancel()
                        }
                    )

                    return
                }
                
                let html = """
                HTTP/1.1 200 OK\r
                Content-Type: text/html; charset=utf-8\r
                Connection: close\r
                \r
                <!DOCTYPE html>
                <html>
                <head>

                <meta charset="utf-8">

                <title>TerminalTV</title>

                <style>

                body {

                    background: black;
                    color: #00ff00;
                    font-family: monospace;
                    padding: 20px;
                }

                input {

                    width: 400px;
                    padding: 10px;

                    background: #111;
                    color: #00ff00;

                    border: 1px solid #00ff00;
                }

                button {

                    padding: 10px;

                    background: #111;
                    color: #00ff00;

                    border: 1px solid #00ff00;
                }

                pre {

                    margin-top: 20px;

                    background: #111;

                    padding: 15px;

                    border: 1px solid #00ff00;

                    white-space: pre-wrap;
                }

                </style>

                </head>

                <body>

                <h1>TerminalTV Web Console</h1>

                <input
                    id="cmd"
                    placeholder="Enter command"
                />

                <button onclick="runCommand()">
                Execute
                </button>
                
                <button onclick="clearConsole()">
                Clear
                </button>
                
                <input
                    type="file"
                    id="fileInput"
                />
                
                <button onclick="testUpload()">
                Upload
                </button>

                <pre id="output">
                Ready.
                </pre>

                <script>

                async function runCommand() {

                    const cmd =
                        document.getElementById("cmd").value;
                if (cmd.trim() !== "") {

                    history.push(cmd);

                    historyIndex = history.length;
                }
                    const response =
                        await fetch(
                            "/run?cmd=" +
                            encodeURIComponent(cmd)
                        );

                    const text =
                        await response.text();

                    document.getElementById(
                        "output"
                    ).textContent = text;

                    document.getElementById(
                        "cmd"
                    ).value = "";

                    document.getElementById(
                        "cmd"
                    ).focus();
                
                }

                document.getElementById("cmd")
                .addEventListener("keydown", function(event) {

                    if (event.key === "Enter") {

                        runCommand();
                    }
                });
                
                document.getElementById("cmd")
                .addEventListener("keydown", function(event) {

                    if (event.key === "ArrowUp") {

                        if (history.length > 0) {

                            historyIndex =
                                Math.max(
                                    0,
                                    historyIndex - 1
                                );

                            this.value =
                                history[historyIndex];
                        }
                    }

                    if (event.key === "ArrowDown") {

                        if (history.length > 0) {

                            historyIndex =
                                Math.min(
                                    history.length - 1,
                                    historyIndex + 1
                                );

                            this.value =
                                history[historyIndex];
                        }
                    }
                });
                
                let history = [];

                let historyIndex = -1;
                
                function clearConsole() {

                    document.getElementById(
                        "output"
                    ).textContent = "Ready.";
                }
                
                async function testUpload() {

                    const file =
                        document.getElementById(
                            "fileInput"
                        ).files[0];

                    if (!file) {

                        alert("Select file");

                        return;
                    }

                    const formData =
                        new FormData();

                    formData.append(
                        "file",
                        file
                    );

                    const response =
                        await fetch(
                            "/upload",
                            {
                                method: "POST",
                                body: formData
                            }
                        );

                    const text =
                        await response.text();

                    alert(text);
                }

                window.onload = function() {

                    document
                        .getElementById("cmd")
                        .focus();
                }

                </script>

                </body>
                </html>
                """

                connection.send(
                    content: html.data(
                        using: .utf8
                    ),
                    completion: .contentProcessed { _ in

                        connection.cancel()
                    }
                )
            }
        }

        listener?.start(
            queue: DispatchQueue.global()
        )

        print(
            "Web server started on port 8080"
        )

    } catch {

        print(
            "Server error: \(error)"
        )
    }
}

    private func receiveAllData(
        from connection: NWConnection,
        completion: @escaping (Data) -> Void
    ) {

        var buffer = Data()

        func receiveNext() {

            connection.receive(
                minimumIncompleteLength: 1,
                maximumLength: 65536
            ) { data, _, isComplete, error in

                if let data = data {

                    buffer.append(data)

                    print(
                        "TOTAL BUFFER:",
                        buffer.count
                    )
                }

                if let error = error {

                    print(
                        "RECEIVE ERROR:",
                        error
                    )

                    completion(buffer)

                    return
                }

                if isComplete {

                    print(
                        "UPLOAD COMPLETE:",
                        buffer.count
                    )

                    completion(buffer)

                    return
                }

                receiveNext()
            }
        }

        receiveNext()
    }
}
