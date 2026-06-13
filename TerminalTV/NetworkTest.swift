//
//  NetworkTest.swift
//  TerminalTV
//
//  Created by Fix’s Trick’s on 30.05.2026.
//

import Network

final class NetworkTest {

    func test() {

        do {

            let listener =
                try NWListener(
                    using: .tcp,
                    on: 8080
                )

            print(listener)

        } catch {

            print(error)
        }
    }
}
