//
//  WebTerminalServerV2.swift.swift
//  TerminalTV
//
//  Created by Fix’s Trick’s on 31.05.2026.
//

import Foundation
import Network

final class WebTerminalServerV2 {

    static let shared = WebTerminalServerV2()

    private var listener: NWListener?

    func start() {

        do {

            listener = try NWListener(
                using: .tcp,
                on: 8081
            )

            listener?.newConnectionHandler = { connection in

                connection.start(
                    queue: .global()
                )

                connection.receive(
                    minimumIncompleteLength: 1,
                    maximumLength: 65536
                ) { data, _, _, _ in

                    guard let data = data else {
                        return
                    }

                    print(
                        "V2 RECEIVED:",
                        data.count
                    )

                    let firstBytes =
                        data.prefix(32)

                    print(
                        "RAW BYTE COUNT:",
                        data.count
                    )

                        let hex =
                            firstBytes.map {
                                String(
                                    format: "%02X",
                                    $0
                                )
                            }
                            .joined(separator: " ")

                        print("RAW HEX:")
                        print(hex)
                    
                    let request =
                        String(
                            data: data,
                            encoding: .utf8
                        ) ?? ""

                    print(
                        "V2 REQUEST:"
                    )

                    print(request)
                    
                    if request.contains("POST /upload") {

                        if let filenameRange =
                            request.range(
                                of: "filename=\""
                            ) {

                            let start =
                                filenameRange.upperBound

                            if let end =
                                request[start...]
                                    .firstIndex(
                                        of: "\""
                                    ) {

                                let filename =
                                    String(
                                        request[start..<end]
                                    )

                                print(
                                    "FILENAME:",
                                    filename
                                )
                                
                                print(
                                    "HAS DOUBLE:",
                                    request.contains("\r\n\r\n")
                                )

                                print(
                                    "HAS QUAD:",
                                    request.contains("\r\n\r\n\r\n\r\n")
                                )
                                
                                if let range =
                                    request.range(
                                        of: "\r\n\r\n"
                                    ) {

                                    let preview =
                                        String(
                                            request[
                                                range.upperBound...
                                            ]
                                            .prefix(200)
                                        )

                                    print(
                                        "AFTER DOUBLE:"
                                    )

                                    print(preview)
                                }
                                
                                if let contentTypeRange =
                                    request.range(
                                        of: "Content-Type: application/octet-stream"
                                    ) {

                                    let afterContentType =
                                        request[
                                            contentTypeRange.upperBound...
                                        ]

                                    if let contentStart =
                                        afterContentType.range(
                                            of: "\r\n\r\n"
                                        ) {

                                        let fileDataStart =
                                            contentStart.upperBound

                                        let remaining =
                                            afterContentType[
                                                fileDataStart...
                                            ]

                                        if let boundary =
                                            remaining.range(
                                                of: "\r\n------WebKitFormBoundary"
                                            ) {

                                            let content =
                                                String(
                                                    remaining[
                                                        ..<boundary.lowerBound
                                                    ]
                                                )

                                            print(
                                                "FILE CONTENT:"
                                            )

                                            print(content)

                                            let path =
                                                "/var/mobile/Documents/" +
                                                filename

                                            do {

                                                try content.write(
                                                    toFile: path,
                                                    atomically: true,
                                                    encoding: .utf8
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
                                }
                                
                                if let bodyStart =
                                    request.range(
                                        of: "\r\n\r\n\r\n\r\n"
                                    ) {

                                    let contentStart =
                                        bodyStart.upperBound

                                    if let boundaryRange =
                                        request[contentStart...]
                                            .range(
                                                of: "\r\n------WebKitFormBoundary"
                                            ) {

                                        let content =
                                            String(
                                                request[
                                                    contentStart..<boundaryRange.lowerBound
                                                ]
                                            )

                                        let path =
                                            "/var/mobile/Documents/" +
                                            filename

                                        do {

                                            try content.write(
                                                toFile: path,
                                                atomically: true,
                                                encoding: .utf8
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
                            }
                        }
                    }

                    if request.contains("GET /delete?file=") {

                        let parts =
                            request.components(
                                separatedBy: "/delete?file="
                            )

                        if parts.count > 1 {

                            let fileName =
                                parts[1]
                                    .components(
                                        separatedBy: " "
                                    )
                                    .first ?? ""

                            let path =
                                "/var/mobile/Documents/" +
                                fileName

                            do {

                                try FileManager.default
                                    .removeItem(
                                        atPath: path
                                    )

                                print(
                                    "FILE DELETED:",
                                    fileName
                                )

                            } catch {

                                print(
                                    "DELETE ERROR:",
                                    error
                                )
                            }

                            let response =
                                """
                                HTTP/1.1 302 Found\r
                                Location: /files\r
                                Connection: close\r
                                \r
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
                    
                    if request.contains("GET /download?file=") {

                        let parts =
                            request.components(
                                separatedBy: "/download?file="
                            )

                        if parts.count > 1 {

                            let fileName =
                                parts[1]
                                    .components(
                                        separatedBy: " "
                                    )
                                    .first ?? ""

                            let path =
                                "/var/mobile/Documents/" +
                                fileName

                            if let data =
                                FileManager.default
                                    .contents(
                                        atPath: path
                                    ) {

                                let header =
                                    """
                                    HTTP/1.1 200 OK\r
                                    Content-Type: application/octet-stream\r
                                    Content-Disposition: attachment; filename="\(fileName)"\r
                                    Connection: close\r
                                    \r
                                    """

                                var response =
                                    Data(
                                        header.utf8
                                    )

                                response.append(data)

                                connection.send(
                                    content: response,
                                    completion: .contentProcessed { _ in

                                        connection.cancel()
                                    }
                                )

                                return
                            }
                        }
                    }
                    
                    if request.contains("GET /files") {

                        let documents =
                            "/var/mobile/Documents"

                        let files =
                            (try? FileManager.default
                                .contentsOfDirectory(
                                    atPath: documents
                                )) ?? []
                        
                        let freeSpace =
                            (try? FileManager.default
                                .attributesOfFileSystem(
                                    forPath: documents
                                )[.systemFreeSize] as? Int64) ?? 0

                        let formatter =
                            ByteCountFormatter()

                        formatter.countStyle = .file

                        let freeSpaceString =
                            formatter.string(
                                fromByteCount: freeSpace
                            )

                        var page =
                            """
                            HTTP/1.1 200 OK\r
                            Content-Type: text/html\r
                            Connection: close\r
                            \r
                            <html>
                            <head>
                            <meta charset="utf-8">
                            <title>Files</title>

                            <style>
                            body {
                                font-family: Arial, sans-serif;
                                margin: 20px;
                            }

                            li {
                                margin: 8px 0;
                            }

                            a {
                                text-decoration: none;
                            }
                            </style>

                            </head>
                            <body>
                            <h1>&#128193; TerminalTV File Manager</h1>

                            <p>
                            &#128193; Files: \(files.count)
                            </p>

                            <p>
                            &#128190; Free Space: \(freeSpaceString)
                            </p>

                            <hr>

                            <ul>
                            """

                        for file in files {
                            
                            let path =
                                "/var/mobile/Documents/" + file

                            let attrs =
                                try? FileManager.default
                                    .attributesOfItem(
                                        atPath: path
                                    )

                            let size =
                                attrs?[.size] as? Int64 ?? 0

                            let formatter =
                                ByteCountFormatter()

                            formatter.countStyle = .file

                            let sizeString =
                                formatter.string(
                                    fromByteCount: size
                                )

                            page +=
                                """
                                <li>

                                &#128196;

                                <a href="/download?file=\(file)">
                                \(file) (\(sizeString))
                                </a>

                                &nbsp;

                                <a href="/download?file=\(file)">
                                &#11015;&#65039; Download
                                </a>

                                &nbsp;

                                <a
                                href="/delete?file=\(file)"
                                onclick="return confirm('Delete \(file)?')">
                                &#10060; Delete
                                </a>

                                </li>
                                """
                        }

                        page +=
                            """
                            </ul>
                            </body>
                            </html>
                            """

                        connection.send(
                            content: page.data(
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
                    Content-Type: text/html\r
                    Connection: close\r
                    \r
                    <html>
                    <body>
                    <h1>TerminalTV V2 Upload</h1>

                    <input
                        type="file"
                        id="fileInput"
                    />

                    <button onclick="uploadFile()">
                    Upload
                    </button>

                    <script>

                    async function uploadFile() {

                        const file =
                            document.getElementById(
                                "fileInput"
                            ).files[0];

                        const formData =
                            new FormData();

                        formData.append(
                            "file",
                            file
                        );

                        await fetch(
                            "/upload",
                            {
                                method: "POST",
                                body: formData
                            }
                        );

                        alert(
                            "Upload sent"
                        );
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
                queue: .global()
            )

            print(
                "WebTerminalServerV2 started on port 8081"
            )
        } catch {

            print(
                "V2 error:",
                error
            )
        }
    }

    private func receiveAllData(
        from connection: NWConnection,
        collected: Data = Data(),
        completion: @escaping (Data) -> Void
    ) {

        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: 65536
        ) { data, _, isComplete, error in

            var buffer = collected

            if let data = data {

                buffer.append(data)
                
                print(
                    "CHUNK:",
                    data.count
                )
                
                print(
                    "TOTAL RECEIVED:",
                    buffer.count
                )
            }
            
            print("IS COMPLETE")
            if isComplete {

                print(
                    "RECEIVE COMPLETE:",
                    buffer.count
                )

                completion(buffer)

                return
            }

            if error != nil {

                completion(buffer)

                return
            }

            self.receiveAllData(
                from: connection,
                collected: buffer,
                completion: completion
            )
        }
    }
}
