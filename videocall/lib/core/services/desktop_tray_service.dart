import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Manages desktop-specific lifecycle behavior on Windows, macOS, and Linux:
/// - Minimizing / hiding to the Windows System Tray (near the clock) when closed with 'X'.
/// - Keeping the background socket alive.
/// - Automatically restoring, focusing, and bringing the window to the front when an incoming call arrives.
class DesktopTrayService with WindowListener {
  static final DesktopTrayService _instance = DesktopTrayService._internal();
  factory DesktopTrayService() => _instance;
  DesktopTrayService._internal();

  TrayIcon? _trayIcon;
  bool _initialized = false;

  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  /// Initialize desktop window and system tray
  Future<void> initialize() async {
    if (!isDesktop || _initialized) return;
    _initialized = true;

    try {
      await windowManager.ensureInitialized();
      windowManager.addListener(this);

      const windowOptions = WindowOptions(
        title: 'CallWave',
        size: Size(1280, 800),
        minimumSize: Size(900, 600),
        center: true,
      );

      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
        await windowManager.setPreventClose(true);
      });

      // Initialize System Tray
      _trayIcon = TrayIcon.create();
      if (_trayIcon != null) {
        try {
          if (Platform.isWindows) {
            _trayIcon!.icon = Image.fromFile('windows/runner/resources/app_icon.ico');
          } else {
            _trayIcon!.icon = ImageAsset.fromAsset('assets/logo/logo.png');
          }
        } catch (_) {}

        _trayIcon!.setTooltip('CallWave - Realtime Video & Audio Calls');

        final menu = Menu.create();
        if (menu != null) {
          final showItem = MenuItem.createWithLabelAndType('Open CallWave', MenuItemType.normal);
          if (showItem != null) {
            showItem.addListener((event) {
              if (event is MenuItemClickedEvent) {
                _showAndFocus();
              }
            });
            menu.addItem(showItem);
          }

          menu.addSeparator();

          final exitItem = MenuItem.createWithLabelAndType('Quit CallWave', MenuItemType.normal);
          if (exitItem != null) {
            exitItem.addListener((event) {
              if (event is MenuItemClickedEvent) {
                windowManager.destroy();
              }
            });
            menu.addItem(exitItem);
          }

          _trayIcon!.setContextMenu(menu);
        }

        _trayIcon!.addListener((event) {
          if (event is TrayIconClickedEvent || event is TrayIconDoubleClickedEvent) {
            _showAndFocus();
          }
        });

        _trayIcon!.setVisible(true);
      }
    } catch (e) {
      debugPrint('[DesktopTrayService] Initialization error: $e');
    }
  }

  /// Bring window to the front, unminimize, and bring forward when a call arrives
  Future<void> bringToFrontForCall() async {
    if (!isDesktop) return;
    try {
      final isMinimized = await windowManager.isMinimized();
      if (isMinimized) {
        await windowManager.restore();
      }
      final isVisible = await windowManager.isVisible();
      if (!isVisible) {
        await windowManager.show();
      }
      await windowManager.setAlwaysOnTop(true);
      await windowManager.focus();
      // Release always-on-top lock after 1.5 seconds so user can use other apps normally
      Future.delayed(const Duration(milliseconds: 1500), () async {
        await windowManager.setAlwaysOnTop(false);
      });
    } catch (e) {
      debugPrint('[DesktopTrayService] bringToFront error: $e');
    }
  }

  @override
  void onWindowClose() async {
    // Instead of exiting, minimize/hide to system tray
    if (isDesktop) {
      final isPreventClose = await windowManager.isPreventClose();
      if (isPreventClose) {
        await windowManager.hide();
      }
    }
  }

  Future<void> _showAndFocus() async {
    final isMinimized = await windowManager.isMinimized();
    if (isMinimized) {
      await windowManager.restore();
    }
    await windowManager.show();
    await windowManager.focus();
  }

  void dispose() {
    if (isDesktop) {
      windowManager.removeListener(this);
      _trayIcon?.dispose();
    }
  }
}
