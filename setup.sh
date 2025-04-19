#!/usr/bin/env bash

# ======================================================
# Minecraft Server Manager (Setup & Control)
# Interactive UI via dialog, supports Vanilla/Forge, custom port,
# screen-based management (start, stop, command send, kill)
# ======================================================

set -euo pipefail

# 1. Dependencies
DEPENDENCIES=(dialog curl wget unzip screen)
INSTALL_CMD="sudo apt-get update && sudo apt-get install -y"
MISSING=()
for pkg in "${DEPENDENCIES[@]}"; do
  if ! command -v "$pkg" &>/dev/null; then
    MISSING+=("$pkg")
  fi
done
if ! command -v java &>/dev/null; then
  MISSING+=("default-jre-headless")
fi
if [ 
  \${#MISSING[@]} -gt 0 ]; then
  echo "Installiere fehlende Pakete: \${MISSING[*]}"
  \$INSTALL_CMD "\${MISSING[@]}"
fi

# Helper: clear dialog handlers
cleanup() { clear; exit; }
trap cleanup SIGINT SIGTERM

# Main menu
ACTION=$(dialog --clear --title "Minecraft Server Manager" \
  --menu "Wähle Aktion:" 15 50 3 \
  setup  "Neuen Server einrichten" \
  manage "Bestehenden Server verwalten" \
  exit   "Beenden" 2>&1 >/dev/tty)
case "$ACTION" in
  setup)
    ;;
  manage)
    # Ask installation directory
    DIR=$(dialog --clear --dselect "$HOME/" 15 60 2>&1 >/dev/tty)
    if [ -z "$DIR" ]; then cleanup; fi
    cd "$DIR"
    # Management loop
    while true; do
      CMD=$(dialog --clear --title "Server verwalten" \
        --menu "Aktion für Server in \$DIR:" 15 50 5 \
        start   "Server starten (screen)" \
        stop    "Graceful stop ('stop')" \
        send    "Befehl senden" \
        kill    "Server-Sitzung killen" \
        exit    "Zurück zum Hauptmenü" 2>&1 >/dev/tty)
      case "$CMD" in
        start)
          screen -dmS mcserver bash -c "cd '$DIR' && ./start.sh"
          dialog --msgbox "Server gestartet in screen-Session 'mcserver'." 6 40
          ;;
        stop)
          screen -S mcserver -p 0 -X stuff "stop$(printf '\r')"
          dialog --msgbox "Stop-Befehl gesendet." 6 40
          ;;
        send)
          USERCMD=$(dialog --inputbox "Minecraft-Konsolen-Befehl:" 8 60 2>&1 >/dev/tty)
          screen -S mcserver -p 0 -X stuff "$USERCMD$(printf '\r')"
          dialog --msgbox "Befehl '$USERCMD' gesendet." 6 40
          ;;
        kill)
          screen -S mcserver -X quit || true
          dialog --msgbox "Screen-Session 'mcserver' beendet." 6 40
          ;;
        exit)
          break
          ;;
      esac
    done
    cleanup
    ;;
  exit)
    cleanup
    ;;
esac

# Setup new server
# Defaults
TYPE="vanilla"
MC_VERSION="1.20.4"
FORGE_VERSION=""
MEMORY="2048"
DIR="$HOME/minecraft"
PORT="25565"

# Dialog: Typ
TYPE=$(dialog --clear --title "Server-Typ" \
  --menu "Wähle Server-Typ:" 10 40 2 \
  vanilla "Vanilla" \
  forge   "Forge" 2>&1 >/dev/tty)
# Minecraft Version
MC_VERSION=$(dialog --clear --inputbox "Minecraft-Version:" 8 40 "$MC_VERSION" 2>&1 >/dev/tty)
# Forge Version
if [ "$TYPE" = "forge" ]; then
  FORGE_VERSION=$(dialog --clear --inputbox "Forge-Version (z.B. 1.20.4-45.1.0):" 8 64 "" 2>&1 >/dev/tty)
fi
# RAM
MEMORY=$(dialog --clear --inputbox "Max RAM (MB):" 8 40 "$MEMORY" 2>&1 >/dev/tty)
# Pfad
DIR=$(dialog --clear --dselect "$DIR/" 15 60 2>&1 >/dev/tty)
# Port
PORT=$(dialog --clear --inputbox "TCP Port:" 8 40 "$PORT" 2>&1 >/dev/tty)
clear

# Prepare
mkdir -p "$DIR"
cd "$DIR"

# Download server.jar
if [ "$TYPE" = "vanilla" ]; then
  MANIFEST=$(curl -s https://launchermeta.mojang.com/mc/game/version_manifest.json)
  URL=$(echo "$MANIFEST" | grep -A2 "\"id\":\"$MC_VERSION\"" | grep url | head -n1 | cut -d'"' -f4)
  JARURL=$(curl -s "$URL" | grep '"server":' -A1 | grep url | cut -d'"' -f4)
  curl -o server.jar "$JARURL"
else
  INSTALLER_URL="https://maven.minecraftforge.net/net/minecraftforge/forge/$FORGE_VERSION/forge-$FORGE_VERSION-installer.jar"
  wget -O forge-installer.jar "$INSTALLER_URL"
  java -jar forge-installer.jar --installServer
  mv forge-*-universal.jar server.jar || mv forge-*-installer.jar server.jar
  rm forge-installer.jar
fi

# EULA
echo "eula=true" > eula.txt

# Properties
cat > server.properties <<EOF
motd=Managed Minecraft Server
max-players=20
view-distance=10
server-port=$PORT
online-mode=true
EOF

# Start script
cat > start.sh <<'EOF'
#!/usr/bin/env bash
java -Xms1G -Xmx${MEMORY}M -jar server.jar nogui
EOF
chmod +x start.sh

echo "Setup abgeschlossen: $DIR"
echo "Verwaltung: ./$(basename "$0") -> 'Bestehenden Server verwalten' -> Pfad wählen."
