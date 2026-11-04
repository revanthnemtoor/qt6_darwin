#include <QApplication>
#include <QMainWindow>
#include <QVBoxLayout>
#include <QLabel>
#include <QPushButton>
#include <QTimer>
#include <QLibraryInfo>
#include <QImageReader>
#include <QImage>
#include <QPainter>
#include <QBuffer>
#include <QNetworkAccessManager>
#include <QSqlDatabase>
#include <QStyle>
#include <QSvgRenderer>
#include <QSvgWidget>
#include <QUiLoader>
#include <iostream>
#include <set>

int main(int argc, char *argv[]) {
    std::cout << "=== Qt 6.12.0 Darwin Multi-Module Native Validation Suite ===" << std::endl;

    // 1. Initialize QApplication without any manual environment variables
    //    to prove automatic plugin discovery and Cocoa QPA loading.
    QApplication app(argc, argv);

    std::string platform = QGuiApplication::platformName().toStdString();
    std::string styleName = app.style() ? app.style()->objectName().toStdString() : "none";
    std::string pluginsPath = QLibraryInfo::path(QLibraryInfo::PluginsPath).toStdString();

    std::cout << "[1] Platform & Plugin Discovery (qt6-base):" << std::endl;
    std::cout << "  - Active QPA Platform : " << platform << std::endl;
    std::cout << "  - Active Widget Style : " << styleName << std::endl;
    std::cout << "  - Built-in PluginsPath: " << pluginsPath << std::endl;
    std::cout << "  - Library Paths       : ";
    for (const QString &p : QCoreApplication::libraryPaths()) {
        std::cout << p.toStdString() << " ";
    }
    std::cout << std::endl;

    if (platform != "cocoa") {
        std::cerr << "ERROR: Expected 'cocoa' platform plugin, got '" << platform << "'" << std::endl;
        return 1;
    }

    // 2. SVG Rendering & SvgWidgets validation (qt6-svg)
    std::cout << "[2] Validating SVG Rendering & Widgets (qt6-svg):" << std::endl;
    const QByteArray svgData = R"(<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
        <circle cx="32" cy="32" r="28" fill="#41cd52" stroke="#1e6b27" stroke-width="4"/>
    </svg>)";
    QSvgRenderer svgRenderer(svgData);
    if (!svgRenderer.isValid()) {
        std::cerr << "ERROR: QSvgRenderer failed to parse inline SVG!" << std::endl;
        return 1;
    }
    QImage svgImg(64, 64, QImage::Format_ARGB32_Premultiplied);
    svgImg.fill(Qt::transparent);
    QPainter painter(&svgImg);
    svgRenderer.render(&painter);
    painter.end();
    std::cout << "  - QSvgRenderer rendered 64x64 SVG (center pixel ARGB: 0x"
              << std::hex << svgImg.pixel(32, 32) << std::dec << ")" << std::endl;

    // 3. Extended Image format plugins discovery (qt6-imageformats + qt6-svg)
    std::cout << "[3] Discovered Image Formats (qt6-base + qt6-svg + qt6-imageformats):" << std::endl << "  - ";
    std::set<std::string> formats;
    for (const QByteArray &fmt : QImageReader::supportedImageFormats()) {
        formats.insert(fmt.toStdString());
        std::cout << fmt.toStdString() << " ";
    }
    std::cout << std::endl;

    for (const char *req : {"svg", "webp", "tiff", "icns", "tga", "wbmp"}) {
        if (formats.find(req) == formats.end()) {
            std::cerr << "ERROR: Required image format plugin missing: " << req << std::endl;
            return 1;
        }
    }
    std::cout << "  - Verified extended image plugins: svg, webp, tiff, icns, tga, wbmp" << std::endl;

    // 4. Dynamic UI Loader validation (qt6-tools / Qt6::UiTools)
    std::cout << "[4] Validating QUiLoader (qt6-tools):" << std::endl;
    const QByteArray uiXml = R"(<?xml version="1.0" encoding="UTF-8"?>
    <ui version="4.0">
     <class>DynamicTestForm</class>
     <widget class="QWidget" name="DynamicTestForm">
      <layout class="QVBoxLayout" name="verticalLayout">
       <item>
        <widget class="QLabel" name="dynLabel">
         <property name="text"><string>Loaded via QUiLoader (qt6-tools)</string></property>
        </widget>
       </item>
      </layout>
     </widget>
    </ui>)";
    QBuffer uiBuffer;
    uiBuffer.setData(uiXml);
    uiBuffer.open(QIODevice::ReadOnly);
    QUiLoader uiLoader;
    QWidget *loadedUi = uiLoader.load(&uiBuffer);
    if (!loadedUi) {
        std::cerr << "ERROR: QUiLoader failed to instantiate widget from .ui XML!" << std::endl;
        return 1;
    }
    std::cout << "  - QUiLoader instantiated widget: " << loadedUi->objectName().toStdString() << std::endl;

    // 5. Native Window & Widgets launch test
    std::cout << "[5] Launching Native Cocoa Window (QtWidgets + QSvgWidget + QUiLoader):" << std::endl;
    QMainWindow window;
    window.setWindowTitle("Qt 6.12.0 Darwin Native Suite");
    window.resize(420, 260);

    QWidget *central = new QWidget(&window);
    QVBoxLayout *layout = new QVBoxLayout(central);
    QLabel *label = new QLabel("Qt 6.12.0 running natively via Cocoa on macOS!", central);
    QSvgWidget *svgWidget = new QSvgWidget(central);
    svgWidget->load(svgData);
    svgWidget->setFixedSize(64, 64);
    loadedUi->setParent(central);
    QPushButton *btn = new QPushButton("Close", central);
    QObject::connect(btn, &QPushButton::clicked, &app, &QApplication::quit);
    layout->addWidget(label);
    layout->addWidget(svgWidget);
    layout->addWidget(loadedUi);
    layout->addWidget(btn);
    window.setCentralWidget(central);

    window.show();
    std::cout << "  - Native window shown (winId: " << window.winId() << ")" << std::endl;

    // 6. SQL & Network
    std::cout << "[6] SQL & Network Modules:" << std::endl;
    QNetworkAccessManager netManager;
    std::cout << "  - QNetworkAccessManager initialized" << std::endl;
    std::cout << "  - SQL Drivers: ";
    for (const QString &drv : QSqlDatabase::drivers()) {
        std::cout << drv.toStdString() << " ";
    }
    std::cout << std::endl;

    // Run real Cocoa event loop for 250ms then exit cleanly
    QTimer::singleShot(250, &app, [&]() {
        std::cout << "[7] Cocoa event loop processed events and timer fired cleanly." << std::endl;
        app.quit();
    });

    int ret = app.exec();
    std::cout << "\n✓ ALL NATIVE QT6 DARWIN VALIDATION CHECKS PASSED (exit code " << ret << ")" << std::endl;
    return ret;
}
