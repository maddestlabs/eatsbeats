import 'dart:ffi';
import 'dart:io' as io;
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'platform_env_helper.dart';

bool isFullscreenState = false;

// Windows API definitions
typedef _GetForegroundWindowC = IntPtr Function();
typedef _GetForegroundWindowDart = int Function();

typedef _GetWindowLongPtrWC = IntPtr Function(IntPtr hWnd, Int32 nIndex);
typedef _GetWindowLongPtrWDart = int Function(int hWnd, int nIndex);

typedef _SetWindowLongPtrWC = IntPtr Function(IntPtr hWnd, Int32 nIndex, IntPtr dwNewLong);
typedef _SetWindowLongPtrWDart = int Function(int hWnd, int nIndex, int dwNewLong);

typedef _SetWindowPosC = Int32 Function(
  IntPtr hWnd,
  IntPtr hWndInsertAfter,
  Int32 X,
  Int32 Y,
  Int32 cx,
  Int32 cy,
  Uint32 uFlags,
);
typedef _SetWindowPosDart = int Function(
  int hWnd,
  int hWndInsertAfter,
  int X,
  int Y,
  int cx,
  int cy,
  int uFlags,
);

typedef _GetSystemMetricsC = Int32 Function(Int32 nIndex);
typedef _GetSystemMetricsDart = int Function(int nIndex);

typedef _ShowWindowC = Int32 Function(IntPtr hWnd, Int32 nCmdShow);
typedef _ShowWindowDart = int Function(int hWnd, int nCmdShow);

typedef _GetWindowRectC = Int32 Function(IntPtr hWnd, Pointer<_NativeRect> lpRect);
typedef _GetWindowRectDart = int Function(int hWnd, Pointer<_NativeRect> lpRect);

typedef _MonitorFromWindowC = IntPtr Function(IntPtr hWnd, Uint32 dwFlags);
typedef _MonitorFromWindowDart = int Function(int hWnd, int dwFlags);

typedef _GetMonitorInfoWC = Int32 Function(IntPtr hMonitor, Pointer<_NativeMonitorInfo> lpmi);
typedef _GetMonitorInfoWDart = int Function(int hMonitor, Pointer<_NativeMonitorInfo> lpmi);

final class _NativeRect extends Struct {
  @Int32()
  external int left;
  @Int32()
  external int top;
  @Int32()
  external int right;
  @Int32()
  external int bottom;
}

final class _NativeMonitorInfo extends Struct {
  @Uint32()
  external int cbSize;
  external _NativeRect rcMonitor;
  external _NativeRect rcWork;
  @Uint32()
  external int dwFlags;
}

const int _GWL_STYLE = -16;
const int _WS_OVERLAPPEDWINDOW = 0x00CF0000;
const int _WS_VISIBLE = 0x10000000;
const int _WS_POPUP = 0x80000000;

const int _HWND_TOP = 0;
const int _SWP_NOZORDER = 0x0004;
const int _SWP_FRAMECHANGED = 0x0020;
const int _SWP_SHOWWINDOW = 0x0040;

const int _SM_CXSCREEN = 0;
const int _SM_CYSCREEN = 1;

const int _MONITOR_DEFAULTTONEAREST = 2;

const int _SW_RESTORE = 9;

int _savedWindowStyle = 0;
int _savedWindowX = 100;
int _savedWindowY = 100;
int _savedWindowW = 1280;
int _savedWindowH = 800;
bool _hasSavedState = false;

Future<void> toggleFullscreenImpl() async {
  await setFullscreenImpl(!isFullscreenState);
}

Future<void> setFullscreenImpl(bool enable) async {
  isFullscreenState = enable;

  if (io.Platform.isWindows && !PlatformEnvHelper.isFlutterTest) {
    try {
      final user32 = DynamicLibrary.open('user32.dll');
      final getForegroundWindow = user32.lookupFunction<_GetForegroundWindowC, _GetForegroundWindowDart>('GetForegroundWindow');
      final getWindowLongPtrW = user32.lookupFunction<_GetWindowLongPtrWC, _GetWindowLongPtrWDart>('GetWindowLongPtrW');
      final setWindowLongPtrW = user32.lookupFunction<_SetWindowLongPtrWC, _SetWindowLongPtrWDart>('SetWindowLongPtrW');
      final setWindowPos = user32.lookupFunction<_SetWindowPosC, _SetWindowPosDart>('SetWindowPos');
      final getSystemMetrics = user32.lookupFunction<_GetSystemMetricsC, _GetSystemMetricsDart>('GetSystemMetrics');
      final showWindow = user32.lookupFunction<_ShowWindowC, _ShowWindowDart>('ShowWindow');

      _GetWindowRectDart? getWindowRect;
      if (user32.providesSymbol('GetWindowRect')) {
        getWindowRect = user32.lookupFunction<_GetWindowRectC, _GetWindowRectDart>('GetWindowRect');
      }

      _MonitorFromWindowDart? monitorFromWindow;
      if (user32.providesSymbol('MonitorFromWindow')) {
        monitorFromWindow = user32.lookupFunction<_MonitorFromWindowC, _MonitorFromWindowDart>('MonitorFromWindow');
      }

      _GetMonitorInfoWDart? getMonitorInfoW;
      if (user32.providesSymbol('GetMonitorInfoW')) {
        getMonitorInfoW = user32.lookupFunction<_GetMonitorInfoWC, _GetMonitorInfoWDart>('GetMonitorInfoW');
      }

      final hwnd = getForegroundWindow();
      if (hwnd != 0) {
        if (enable) {
          final style = getWindowLongPtrW(hwnd, _GWL_STYLE);
          if (!_hasSavedState) {
            _savedWindowStyle = style;
            if (getWindowRect != null) {
              final rectPtr = calloc<_NativeRect>();
              try {
                if (getWindowRect(hwnd, rectPtr) != 0) {
                  _savedWindowX = rectPtr.ref.left;
                  _savedWindowY = rectPtr.ref.top;
                  _savedWindowW = rectPtr.ref.right - rectPtr.ref.left;
                  _savedWindowH = rectPtr.ref.bottom - rectPtr.ref.top;
                }
              } finally {
                calloc.free(rectPtr);
              }
            }
            _hasSavedState = true;
          }

          int posX = 0;
          int posY = 0;
          int screenWidth = getSystemMetrics(_SM_CXSCREEN);
          int screenHeight = getSystemMetrics(_SM_CYSCREEN);

          if (monitorFromWindow != null && getMonitorInfoW != null) {
            final hMonitor = monitorFromWindow(hwnd, _MONITOR_DEFAULTTONEAREST);
            if (hMonitor != 0) {
              final miPtr = calloc<_NativeMonitorInfo>();
              try {
                miPtr.ref.cbSize = sizeOf<_NativeMonitorInfo>();
                if (getMonitorInfoW(hMonitor, miPtr) != 0) {
                  posX = miPtr.ref.rcMonitor.left;
                  posY = miPtr.ref.rcMonitor.top;
                  screenWidth = miPtr.ref.rcMonitor.right - miPtr.ref.rcMonitor.left;
                  screenHeight = miPtr.ref.rcMonitor.bottom - miPtr.ref.rcMonitor.top;
                }
              } finally {
                calloc.free(miPtr);
              }
            }
          }

          // Remove window borders & titlebar
          final newStyle = (style & ~_WS_OVERLAPPEDWINDOW) | _WS_POPUP | _WS_VISIBLE;
          setWindowLongPtrW(hwnd, _GWL_STYLE, newStyle);

          // Position window to cover entire monitor
          setWindowPos(
            hwnd,
            _HWND_TOP,
            posX,
            posY,
            screenWidth,
            screenHeight,
            _SWP_NOZORDER | _SWP_FRAMECHANGED | _SWP_SHOWWINDOW,
          );
        } else {
          // Restore regular windowed style
          final restoreStyle = _savedWindowStyle != 0 ? _savedWindowStyle : _WS_OVERLAPPEDWINDOW | _WS_VISIBLE;
          setWindowLongPtrW(hwnd, _GWL_STYLE, restoreStyle);

          setWindowPos(
            hwnd,
            _HWND_TOP,
            _savedWindowX,
            _savedWindowY,
            _savedWindowW,
            _savedWindowH,
            _SWP_NOZORDER | _SWP_FRAMECHANGED | _SWP_SHOWWINDOW,
          );
          showWindow(hwnd, _SW_RESTORE);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Windows fullscreen FFI fallback: $e');
      }
    }
  }

  // System UI mode for mobile/web/fallback
  if (!PlatformEnvHelper.isFlutterTest) {
    try {
      if (enable) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    } catch (_) {}
  }
}

bool getIsFullscreenImpl() => isFullscreenState;
