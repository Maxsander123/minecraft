#!/bin/bash

# --- KONFIGURATION (Optimiert für 128 Kerne / 300GB RAM) ---
SESSION_NAME="minecraft"
RAM="256G"
THREADS="120"   # Lässt 8 Kerne für OS-Hintergrundprozesse frei
RADIUS=50000    # Entspricht 100.000 x 100.000 Blöcken

# MOD-LINKS (Deine bereitgestellten Links)
URL_FORGE="https://maven.minecraftforge.net/net/minecraftforge/forge/1.20.1-47.3.0/forge-1.20.1-47.3.0-installer.jar"
URL_CHUNKY="https://cdn.modrinth.com/data/fALzjamp/versions/4FTDk9wv/Chunky-1.3.146.jar"
URL_BLUEMAP="https://cdn.modrinth.com/data/swbUV1cr/versions/aHbq9KFB/BlueMap-5.3-forge-1.20.jar"
URL_BOP="https://cdn.modrinth.com/data/HXF82T3G/versions/jxUqRzSD/BiomesOPlenty-forge-1.20.1-19.0.0.96.jar"
URL_TERRABLENDER="https://cdn.modrinth.com/data/kkmrDlKT/versions/zGconCHG/TerraBlender-forge-1.20.1-3.0.1.10.jar"
URL_C2ME="https://cdn.modrinth.com/data/yE4MbG65/versions/h9trYS7V/c2meF-0.2.0%2Balpha.12-all.jar"
URL_FERRITECORE="https://cdn.modrinth.com/data/uXXizFIs/versions/DG5Fn9Sz/ferritecore-6.0.1-forge.jar"
URL_MODERNFIX="https://cdn.modrinth.com/data/nmDcB62a/versions/PbIMs8a8/modernfix-forge-5.25.1%2Bmc1.20.1.jar"
URL_STARLIGHT="https://cdn.modrinth.com/data/iRfIGC1s/versions/cNa0vkNj/starlight-1.1.2%2Bforge.1cda73c.jar"

echo "=== STARTE SETUP IM SCREEN-MODUS ==="

# 1. Forge Installation
echo "-> Installiere Forge..."
wget -q --show-progress -O forge-installer.jar "$URL_FORGE"
java -jar forge-installer.jar --installServer > /dev/null
echo "eula=true" > eula.txt

# 2. Mods Download
mkdir -p mods
echo "-> Lade Mods..."
wget -q -O mods/chunky.jar "$URL_CHUNKY"
wget -q -O mods/bluemap.jar "$URL_BLUEMAP"
wget -q -O mods/biomesoplenty.jar "$URL_BOP"
wget -q -O mods/terrablender.jar "$URL_TERRABLENDER"
wget -q -O mods/c2me.jar "$URL_C2ME"
wget -q -O mods/ferritecore.jar "$URL_FERRITECORE"
wget -q -O mods/modernfix.jar "$URL_MODERNFIX"
wget -q -O mods/starlight.jar "$URL_STARLIGHT"

# 3. Konfiguration: Large Biomes & Performance
echo "-> Erstelle Konfigurationen..."
echo "level-type=minecraft\:large_biomes" > server.properties
echo "max-tick-time=-1" >> server.properties
echo "view-distance=12" >> server.properties

# C2ME Tuning für 120 Threads
mkdir -p config
cat <<EOT > config/c2me.toml
version = 3
[general]
    maxWorkerThreads = $THREADS
[ioSystem]
    asyncIO = true
[threadingUtils]
    useGlobalExecutor = true
EOT

# BlueMap Tuning für 120 Threads
mkdir -p config/bluemap
echo "accept-download: true" > config/bluemap/core.conf
echo "render-thread-count: $THREADS" >> config/bluemap/core.conf

# 4. Erstellung des Start-Skripts mit G1GC High-RAM Flags
cat <<EOT > start_server.sh
#!/bin/bash
java -Xms$RAM -Xmx$RAM \\
  -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 \\
  -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch \\
  -XX:G1NewSizePercent=40 -XX:G1MaxNewSizePercent=50 -XX:G1HeapRegionSize=32M \\
  -XX:G1ReservePercent=15 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 \\
  -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 \\
  -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem \\
  -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true \\
  @user_jvm_args.txt @libraries/net/minecraftforge/forge/1.20.1-47.3.0/unix_args.txt "\$@"
EOT
chmod +x start_server.sh

# 5. SERVER IM SCREEN STARTEN
echo "-> Starte Server in Screen-Session '$SESSION_NAME'..."
screen -dmS $SESSION_NAME ./start_server.sh nogui

# 6. Automatisierung: Chunky Befehle in den Screen einspeisen
echo "-> Warte 120 Sekunden auf den Server-Start..."
sleep 120

echo "-> Sende Chunky Befehle an Screen..."
# Befehle werden nacheinander in die Screen-Konsole "getippt"
screen -S $SESSION_NAME -p 0 -X stuff "chunky world minecraft:overworld$(printf '\r')"
sleep 2
screen -S $SESSION_NAME -p 0 -X stuff "chunky center 0 0$(printf '\r')"
sleep 2
screen -S $SESSION_NAME -p 0 -X stuff "chunky radius $RADIUS$(printf '\r')"
sleep 2
screen -S $SESSION_NAME -p 0 -X stuff "chunky start$(printf '\r')"

echo "========================================================="
echo " SETUP ABGESCHLOSSEN "
echo "========================================================="
echo "Der Server läuft jetzt im Screen '$SESSION_NAME'."
echo ""
echo "Befehle:"
echo "  screen -r $SESSION_NAME   -> Konsole öffnen"
echo "  STRG+A, dann D           -> Konsole wieder verlassen"
echo "  htop                     -> CPU Last der 128 Kerne prüfen"
echo "========================================================="
