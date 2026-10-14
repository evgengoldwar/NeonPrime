#!/usr/bin/env bash
# Сборка APK «Я — подземелье» для Android.
#
# Использование:
#   ./build_apk.sh            — подписанный release-APK (по умолчанию)
#   ./build_apk.sh debug      — debug-APK (подписан отладочным ключом)
#   ./build_apk.sh install    — release-APK и сразу установка на телефон по USB (нужен adb)
#
# При первом запуске скрипт сам скачает в .build-cache/ всё, чего нет:
#   Godot (headless-редактор) и шаблоны экспорта, JDK 17, Android SDK.
# Нужны: bash, curl, unzip, tar. Работает на Linux (x86_64/arm64) и macOS.
#
# Переменные окружения (необязательно):
#   GODOT_VERSION   версия Godot, по умолчанию 4.7-stable (например 4.7.1-stable)
#   GODOT_BIN       путь к своему Godot 4.7 — тогда он не скачивается
#   JAVA_HOME       свой JDK 17
#   ANDROID_HOME    свой Android SDK
#   KEYSTORE_PASS   пароль release-ключа (по умолчанию генерируется и хранится в keystore/)

set -euo pipefail

MODE="${1:-release}"
case "$MODE" in
  release|debug|install) ;;
  -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
  *) echo "Неизвестный режим: $MODE (release | debug | install)"; exit 1 ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE="$ROOT/.build-cache"
OUT_DIR="$ROOT/build"
KEY_DIR="$ROOT/keystore"
GODOT_VERSION="${GODOT_VERSION:-4.7-stable}"
APP_NAME="ya-podzemelye"
PRESET="Android"
ANDROID_PLATFORM="android-35"
ANDROID_BUILD_TOOLS="35.0.0"
CMDLINE_TOOLS_REV="11076708"

say()  { printf '\033[1;35m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mОшибка:\033[0m %s\n' "$*" >&2; exit 1; }

for tool in curl unzip tar; do
  command -v "$tool" >/dev/null || die "не найдена утилита '$tool', установите её"
done

mkdir -p "$CACHE" "$OUT_DIR" "$KEY_DIR"
# Godot не должен сканировать кэш (SDK, JDK) и папки сборки как ресурсы проекта.
touch "$CACHE/.gdignore" "$OUT_DIR/.gdignore" "$KEY_DIR/.gdignore"

OS="$(uname -s)"
ARCH="$(uname -m)"
case "$OS" in
  Linux)  PLATFORM="linux" ;;
  Darwin) PLATFORM="mac" ;;
  *) die "поддерживаются Linux и macOS (на Windows запускайте через WSL)" ;;
esac

download() { # url файл
  say "Скачиваю $(basename "$2")"
  if ! curl -fL --retry 3 --progress-bar -o "$2.part" "$1"; then
    rm -f "$2.part"
    return 1
  fi
  mv "$2.part" "$2"
}

# ------------------------------------------------------------------ Godot

GODOT_DIR="$CACHE/godot-$GODOT_VERSION"
BASE_URL="https://github.com/godotengine/godot-builds/releases/download/$GODOT_VERSION"

if [[ -n "${GODOT_BIN:-}" ]]; then
  GODOT="$GODOT_BIN"
  [[ -x "$GODOT" ]] || die "GODOT_BIN=$GODOT_BIN не найден или не исполняемый"
  EDITOR_DATA=""
else
  mkdir -p "$GODOT_DIR"
  if [[ "$PLATFORM" == "linux" ]]; then
    case "$ARCH" in
      x86_64)        GZIP_NAME="Godot_v${GODOT_VERSION}_linux.x86_64" ;;
      aarch64|arm64) GZIP_NAME="Godot_v${GODOT_VERSION}_linux.arm64" ;;
      *) die "неподдерживаемая архитектура $ARCH" ;;
    esac
    GODOT="$GODOT_DIR/$GZIP_NAME"
    BIN_DIR="$GODOT_DIR"
  else
    GZIP_NAME="Godot_v${GODOT_VERSION}_macos.universal"
    GODOT="$GODOT_DIR/Godot.app/Contents/MacOS/Godot"
    BIN_DIR="$GODOT_DIR/Godot.app/Contents/MacOS"
  fi
  if [[ ! -x "$GODOT" ]]; then
    download "$BASE_URL/$GZIP_NAME.zip" "$CACHE/$GZIP_NAME.zip" \
      || die "нет сборки Godot $GODOT_VERSION. Укажите версию: GODOT_VERSION=4.7.1-stable ./build_apk.sh"
    unzip -q -o "$CACHE/$GZIP_NAME.zip" -d "$GODOT_DIR"
    chmod +x "$GODOT"
    rm -f "$CACHE/$GZIP_NAME.zip"
  fi
  # Самодостаточный режим: настройки и шаблоны лежат рядом с бинарником,
  # системный Godot пользователя не затрагивается.
  touch "$BIN_DIR/._sc_"
  EDITOR_DATA="$BIN_DIR/editor_data"
  mkdir -p "$EDITOR_DATA"
fi

# Папка шаблонов называется по версии без «-»: 4.7-stable -> 4.7.stable
TEMPLATE_VER="${GODOT_VERSION/-/.}"
if [[ -n "$EDITOR_DATA" ]]; then
  TEMPLATES_DIR="$EDITOR_DATA/export_templates/$TEMPLATE_VER"
elif [[ "$PLATFORM" == "linux" ]]; then
  TEMPLATES_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$TEMPLATE_VER"
else
  TEMPLATES_DIR="$HOME/Library/Application Support/Godot/export_templates/$TEMPLATE_VER"
fi

if [[ ! -f "$TEMPLATES_DIR/android_release.apk" ]]; then
  TPZ="$CACHE/Godot_v${GODOT_VERSION}_export_templates.tpz"
  [[ -f "$TPZ" ]] || download "$BASE_URL/Godot_v${GODOT_VERSION}_export_templates.tpz" "$TPZ" \
    || die "не удалось скачать шаблоны экспорта Godot $GODOT_VERSION"
  say "Распаковываю шаблоны экспорта"
  TMP_T="$CACHE/templates-tmp"
  rm -rf "$TMP_T" && mkdir -p "$TMP_T" "$TEMPLATES_DIR"
  unzip -q -o "$TPZ" -d "$TMP_T"
  cp -R "$TMP_T/templates/." "$TEMPLATES_DIR/"
  rm -rf "$TMP_T" "$TPZ"
fi

# ------------------------------------------------------------------ JDK 17

java_major() {
  "$1/bin/java" -version 2>&1 | awk -F'"' '/version/ {split($2, v, "."); print (v[1] == "1") ? v[2] : v[1]; exit}'
}

if [[ -n "${JAVA_HOME:-}" && -x "$JAVA_HOME/bin/java" && "$(java_major "$JAVA_HOME")" -ge 17 ]]; then
  :
else
  JAVA_HOME=""
  if command -v java >/dev/null; then
    SYS_JAVA="$(cd "$(dirname "$(readlink -f "$(command -v java)" 2>/dev/null || command -v java)")/.." && pwd)"
    if [[ -x "$SYS_JAVA/bin/keytool" && "$(java_major "$SYS_JAVA")" -ge 17 ]]; then
      JAVA_HOME="$SYS_JAVA"
    fi
  fi
  if [[ -z "$JAVA_HOME" ]]; then
    JDK_DIR="$CACHE/jdk-17"
    if [[ ! -x "$JDK_DIR/bin/java" && ! -x "$JDK_DIR/Contents/Home/bin/java" ]]; then
      case "$ARCH" in
        x86_64) JARCH="x64" ;;
        aarch64|arm64) JARCH="aarch64" ;;
        *) die "неподдерживаемая архитектура $ARCH" ;;
      esac
      JOS="linux"; [[ "$PLATFORM" == "mac" ]] && JOS="mac"
      download "https://api.adoptium.net/v3/binary/latest/17/ga/$JOS/$JARCH/jdk/hotspot/normal/eclipse" "$CACHE/jdk17.tar.gz" \
        || die "не удалось скачать JDK 17"
      mkdir -p "$JDK_DIR"
      tar -xzf "$CACHE/jdk17.tar.gz" -C "$JDK_DIR" --strip-components=1
      rm -f "$CACHE/jdk17.tar.gz"
    fi
    JAVA_HOME="$JDK_DIR"
    [[ -x "$JDK_DIR/Contents/Home/bin/java" ]] && JAVA_HOME="$JDK_DIR/Contents/Home"
  fi
fi
export JAVA_HOME
export PATH="$JAVA_HOME/bin:$PATH"
say "JDK: $JAVA_HOME"

# ------------------------------------------------------------------ Android SDK

ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$CACHE/android-sdk}}"
export ANDROID_HOME ANDROID_SDK_ROOT="$ANDROID_HOME"
SDKMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"

sdk_ready() {
  [[ -d "$ANDROID_HOME/platform-tools" ]] && compgen -G "$ANDROID_HOME/build-tools/*/apksigner" >/dev/null
}

if ! sdk_ready || [[ ! -d "$ANDROID_HOME/platforms/$ANDROID_PLATFORM" && ! -d "$ANDROID_HOME/platforms" ]]; then
  if [[ ! -x "$SDKMANAGER" ]]; then
    CT_OS="linux"; [[ "$PLATFORM" == "mac" ]] && CT_OS="mac"
    CT_ZIP="$CACHE/cmdline-tools.zip"
    download "https://dl.google.com/android/repository/commandlinetools-${CT_OS}-${CMDLINE_TOOLS_REV}_latest.zip" "$CT_ZIP" \
      || die "не удалось скачать Android command-line tools"
    mkdir -p "$ANDROID_HOME/cmdline-tools"
    rm -rf "$ANDROID_HOME/cmdline-tools/latest" "$ANDROID_HOME/cmdline-tools/cmdline-tools"
    unzip -q -o "$CT_ZIP" -d "$ANDROID_HOME/cmdline-tools"
    mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
    rm -f "$CT_ZIP"
  fi
  say "Устанавливаю компоненты Android SDK, это несколько минут (лицензии принимаются автоматически)"
  yes | "$SDKMANAGER" --sdk_root="$ANDROID_HOME" --licenses >/dev/null || true
  "$SDKMANAGER" --sdk_root="$ANDROID_HOME" \
    "platform-tools" "build-tools;$ANDROID_BUILD_TOOLS" "platforms;$ANDROID_PLATFORM" >/dev/null
fi
say "Android SDK: $ANDROID_HOME"

# ------------------------------------------------------------------ ключи подписи

mkdir -p "$KEY_DIR"
DEBUG_KS="$KEY_DIR/debug.keystore"
if [[ ! -f "$DEBUG_KS" ]]; then
  say "Создаю отладочный ключ"
  keytool -genkeypair -v -keystore "$DEBUG_KS" -storepass android -keypass android \
    -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 \
    -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
fi

RELEASE_KS="$KEY_DIR/release.keystore"
RELEASE_ALIAS="yapodzemelye"
PASS_FILE="$KEY_DIR/release.pass"
if [[ -z "${KEYSTORE_PASS:-}" ]]; then
  if [[ -f "$PASS_FILE" ]]; then
    KEYSTORE_PASS="$(cat "$PASS_FILE")"
  else
    KEYSTORE_PASS="$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom 2>/dev/null | head -c 20 || true)"
    printf '%s' "$KEYSTORE_PASS" > "$PASS_FILE"
    chmod 600 "$PASS_FILE"
  fi
fi
if [[ "$MODE" != "debug" && ! -f "$RELEASE_KS" ]]; then
  say "Создаю release-ключ: $RELEASE_KS"
  keytool -genkeypair -v -keystore "$RELEASE_KS" -storepass "$KEYSTORE_PASS" -keypass "$KEYSTORE_PASS" \
    -alias "$RELEASE_ALIAS" -keyalg RSA -keysize 2048 -validity 10000 \
    -dname "CN=Ya Podzemelye,O=NeonPrime,C=RU" >/dev/null 2>&1
  warn "Сохраните папку keystore/ — без этого ключа нельзя будет обновить игру на телефоне."
fi

# Godot берёт ключи из переменных окружения
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$DEBUG_KS"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER="androiddebugkey"
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="android"
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$RELEASE_KS"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$RELEASE_ALIAS"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$KEYSTORE_PASS"

# Пути к SDK и JDK — в настройки редактора (для разных версий Godot имя файла разное)
if [[ -n "$EDITOR_DATA" ]]; then
  MAJOR_MINOR="$(echo "$GODOT_VERSION" | grep -oE '^[0-9]+\.[0-9]+')"
  MAJOR="${MAJOR_MINOR%%.*}"
  for f in "editor_settings-$MAJOR.tres" "editor_settings-$MAJOR_MINOR.tres"; do
    cat > "$EDITOR_DATA/$f" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$ANDROID_HOME"
export/android/java_sdk_path = "$JAVA_HOME"
export/android/debug_keystore = "$DEBUG_KS"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
EOF
  done
else
  warn "Используется свой Godot: проверьте, что в Editor Settings указаны Android SDK ($ANDROID_HOME) и Java SDK ($JAVA_HOME)."
fi

# ------------------------------------------------------------------ сборка

say "Импорт ресурсов проекта"
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 \
  || "$GODOT" --headless --path "$ROOT" --editor --quit >/dev/null 2>&1 || true

if [[ "$MODE" == "debug" ]]; then
  APK="$OUT_DIR/$APP_NAME-debug.apk"
  EXPORT_FLAG="--export-debug"
else
  APK="$OUT_DIR/$APP_NAME.apk"
  EXPORT_FLAG="--export-release"
fi
rm -f "$APK"

say "Экспорт APK ($MODE)"
LOG="$OUT_DIR/export.log"
if ! "$GODOT" --headless --path "$ROOT" "$EXPORT_FLAG" "$PRESET" "$APK" >"$LOG" 2>&1 || [[ ! -s "$APK" ]]; then
  tail -n 40 "$LOG" >&2
  die "экспорт не удался, полный лог: $LOG"
fi

APKSIGNER="$(compgen -G "$ANDROID_HOME/build-tools/*/apksigner" | sort | tail -n 1 || true)"
if [[ -n "$APKSIGNER" && -x "$APKSIGNER" ]]; then
  if "$APKSIGNER" verify "$APK" >/dev/null 2>&1; then
    say "Подпись APK проверена"
  else
    warn "apksigner не подтвердил подпись APK"
  fi
fi

say "Готово: $APK ($(du -h "$APK" | cut -f1))"

if [[ "$MODE" == "install" ]]; then
  ADB="$ANDROID_HOME/platform-tools/adb"
  [[ -x "$ADB" ]] || ADB="$(command -v adb || true)"
  [[ -n "$ADB" ]] || die "adb не найден"
  say "Устанавливаю на телефон (включите «Отладку по USB»)"
  "$ADB" install -r "$APK"
fi
