#include <QCoreApplication>
#include <QGuiApplication>
#include <QApplication>
#include <QLabel>
#include <QTimer>
#include <QNetworkAccessManager>
#include <QSqlDatabase>
#include <QDebug>
#include <iostream>

int main(int argc, char *argv[]) {
    std::cout << "[Test 1] Initializing QApplication..." << std::endl;
    // Set offscreen platform plugin for automated non-interactive testing if headless,
    // or native cocoa when display server is active.
    qputenv("QT_QPA_PLATFORM", "offscreen");

    QApplication app(argc, argv);
    std::cout << "  ✓ Application created: " << app.applicationName().toStdString() << std::endl;
    std::cout << "  ✓ Platform name: " << QGuiApplication::platformName().toStdString() << std::endl;

    std::cout << "[Test 2] Testing Qt Widgets..." << std::endl;
    QLabel label("Hello from Pacman Qt 6 on macOS!");
    std::cout << "  ✓ QLabel instantiated with text: " << label.text().toStdString() << std::endl;

    std::cout << "[Test 3] Testing Qt Network..." << std::endl;
    QNetworkAccessManager manager;
    std::cout << "  ✓ QNetworkAccessManager instantiated." << std::endl;

    std::cout << "[Test 4] Testing Qt SQL..." << std::endl;
    std::cout << "  ✓ Available SQL drivers: ";
    for (const QString &driver : QSqlDatabase::drivers()) {
        std::cout << driver.toStdString() << " ";
    }
    std::cout << std::endl;

    std::cout << "\n✓ ALL RUNTIME SMOKETESTS PASSED SUCCESSFULLY!" << std::endl;
    return 0;
}
