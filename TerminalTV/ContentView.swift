import SwiftUI

struct ContentView: View {
    // Подключаемся к нашей новой общей модели синхронизации
    @StateObject private var vm = TerminalViewModel.shared
    @State private var command = ""

    var body: some View {
        ZStack {
            // Классический черный фон терминала
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // ВЕРХНЯЯ ПАНЕЛЬ
                HStack {
                    Text("TerminalTV Console")
                        .font(.headline)
                        .foregroundColor(.green)

                    Spacer()

                    // Кнопка системной инфо
                    Button("Info") {
                        vm.appendText("\n[SYSTEM INFO]\nOS: \(ProcessInfo.processInfo.operatingSystemVersionString)\n")
                    }

                    // Очистка экрана на ТВ
                    Button("Clear") {
                        vm.consoleOutput = "🚀 Console cleared. Waiting for commands..."
                    }
                }
                .padding()

                Divider().background(Color.green.opacity(0.3))

                // ГЛАВНОЕ ОКНО ВЫВОДА
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading) {
                            Text(vm.consoleOutput)
                                .font(.system(size: 28, weight: .medium, design: .monospaced))
                                .foregroundColor(.green)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                            
                            // Невидимый элемент для авто-скролла
                            Color.clear
                                .frame(height: 1)
                                .id("BOTTOM")
                        }
                    }
                    // Следим за обновлением текста и прокручиваем вниз
                    .onChange(of: vm.consoleOutput) { _ in
                        withAnimation {
                            proxy.scrollTo("BOTTOM", anchor: .bottom)
                        }
                    }
                }

                Divider().background(Color.green.opacity(0.3))

                // НИЖНЯЯ ПАНЕЛЬ ВВОДА
                HStack {
                    Text(">")
                        .foregroundColor(.green)
                        .font(.system(.body, design: .monospaced))

                    TextField("Введите команду...", text: $command)
                        .foregroundColor(.white)

                    Button("Execute") {
                        if !command.isEmpty {
                            vm.appendText("\n$ \(command)")
                            // Вызываем метод, который мы УЖЕ добавили в файл сервера
                            let result = WebTerminalServerV3.shared.executeCommandExternally(command)
                            vm.appendText(result)
                            command = ""
                        }
                    }
                }
                .padding()
            }
        }
        .onAppear {
            // Запуск веб-сервера
            WebTerminalServerV3.shared.start()
        }
    }
}

#Preview {
    ContentView()
}
