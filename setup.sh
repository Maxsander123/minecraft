#!/bin/bash

# --- KONFIGURATION (128 Kerne / 300GB RAM) ---
SESSION_NAME="minecraft"
RAM="256G"
THREADS="120"   # Optimale Auslastung für 128 Kerne
RADIUS=50000    # 100k x 100k Blöcke

# MOD-LINKS (Aktualisiert mit deinem GlitchCore Link)
URL_GLITCHCORE="https://cdn.modrinth.com/data/s3dmwKy5/versions/pYPZ5MNI/GlitchCore-forge-1.20.1-0.0.1.1.jar"
URL_CHUNKY="https://cdn.modrinth.com/data/fALzjamp/versions/4FTDk9wv/Chunky-1.3.146.jar"
URL_BLUEMAP="https://cdn.modrinth.com/data/swbUV1cr/versions/aHbq9KFB/BlueMap-5.3-forge-1.20.jar"
URL_BOP="https://cdn.modrinth.com/data/HXF82T3G/versions/jxUqRzSD/BiomesOPlenty-forge-1.20.1-19.0.0.96.jar"
URL_TERRABLENDER="https://cdn.modrinth.com/data/kkmrDlKT/versions/zGconCHG/TerraBlender-forge-1.20.1-3.0.1.10.jar"
URL_C2ME="https://cdn.modrinth.com/data/yE4MbG65/versions/h9trYS7V/c2meF-0.2.0%2Balpha.12-all.jar"
URL_FERRITECORE="https://cdn.modrinth.com/data/uXXizFIs/versions/DG5Fn9Sz/ferritecore-6.0.1-forge.jar"
URL_MODERNFIX="https://cdn.modrinth.com/data/nmDcB62a/versions/PbIMs8a8/modernfix-forge-5.25.1%2Bmc1.20.1.jar"
URL_STARLIGHT="https://cdn.modrinth.com/data/iRfIGC1s/versions/cNa0vkNj/starlight-1.1.2%2Bforge.1cda73c.jar"

echo "=== 1. MODS BEREINIGEN & DOWNLOAD ==="
# Wir löschen alte Mod-Versionen, um Konflikte zu vermeiden
rm -rf mods/*.jar
mkdir -p mods config config/bluemap

wget -q -O mods/glitchcore.jar "$URL_GLITCHCORE"
wget -q -O mods/chunky.jar "$URL_CHUNKY"
wget -q -O mods/bluemap.jar "$URL_BLUEMAP"
wget -q -O mods/biomesoplenty.jar "$URL_BOP"
wget -q -O mods/terrablender.jar "$URL_TERRABLENDER"
wget -q -O mods/c2me.jar "$URL_C2ME"
wget -q -O mods/ferritecore.jar "$URL_FERRITECORE"
wget -q -O mods/modernfix.jar "$URL_MODERNFIX"
wget -q -O mods/starlight.jar "$URL_STARLIGHT"

echo "=== 2. KONFIGURATION (PERFORMANCE & LARGE BIOMES) ==="
echo "eula=true" > eula.txt
echo "level-type=minecraft\:large_biomes" > server.properties
echo "max-tick-time=-1" >> server.properties
echo "view-distance=12" >> server.properties

# C2ME für extreme CPU-Auslastung konfigurieren
cat <<EOT > config/c2me.toml
version = 3
[general]
    maxWorkerThreads = $THREADS
[ioSystem]
    asyncIO = true
[threadingUtils]
    useGlobalExecutor = true
EOT

# BlueMap für extreme CPU-Auslastung konfigurieren
echo "accept-download: true" > config/bluemap/core.conf
echo "render-thread-count: $THREADS" >> config/bluemap/core.conf

# Java-Flags für 256GB RAM in user_jvm_args.txt schreiben
cat <<EOT > user_jvm_args.txt
-Xms$RAM
-Xmx$RAM
-XX:+UseG1GC
-XX:+ParallelRefProcEnabled
-XX:MaxGCPauseMillis=200
-XX:+UnlockExperimentalVMOptions
-XX:+DisableExplicitGC
-XX:+AlwaysPreTouch
-XX:G1NewSizePercent=40
-XX:G1MaxNewSizePercent=50
-XX:G1HeapRegionSize=32M
-XX:G1ReservePercent=15
-XX:G1HeapWastePercent=5
-XX:G1MixedGCCountTarget=4
-XX:InitiatingHeapOccupancyPercent=15
-XX:G1MixedGCLiveThresholdPercent=90
-XX:G1RSetUpdatingPauseTimePercent=5
-XX:SurvivorRatio=32
-XX:+PerfDisableSharedMem
-XX:MaxTenuringThreshold=1
-Dusing.aikars.flags=https://mcflags.emc.gs
-Daikars.new.flags=true
EOT

echo "=== 3. STARTE SERVER IM SCREEN '$SESSION_NAME' ==="
# Falls noch ein alter Screen läuft, beenden
screen -S $SESSION_NAME -X quit 2>/dev/null

# Log-Datei leeren für sauberen Scan
rm -f logs/latest.log

# Startbefehl
screen -dmS $SESSION_NAME ./run.sh

echo "Warte auf Server-Boot (Suche 'Done' in logs/latest.log)..."
until grep -q "Done" logs/latest.log 2>/dev/null; do
    echo -n "."
    sleep 5
done

echo -e "\n\n=== 4. SERVER BEREIT! SENDE CHUNKY BEFEHLE ==="
screen -S $SESSION_NAME -p 0 -X stuff "chunky world minecraft:overworld$(printf '\r')"
sleep 1
screen -S $SESSION_NAME -p 0 -X stuff "chunky center 0 0$(printf '\r')"
sleep 1
screen -S $SESSION_NAME -p 0 -X stuff "chunky radius $RADIUS$(printf '\r')"
sleep 1
screen -S $SESSION_NAME -p 0 -X stuff "chunky start$(printf '\r')"

echo "----------------------------------------------------"
echo "ERFOLG: Der Server läuft und generiert die Welt."
echo "Konsole öffnen:  screen -r $SESSION_NAME"
echo "CPU-Last prüfen: htop"
echo "----------------------------------------------------"
