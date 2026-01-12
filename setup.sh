#!/bin/bash

# --- KONFIGURATION (Extreme Specs: 128 Kerne, 300GB RAM) ---
MC_VERSION="1.20.1"
FORGE_VERSION="47.3.0"
ALLOCATED_RAM="256G"   # 256GB RAM für Java
THREADS="120"          # 120 Threads für Weltgen & BlueMap
RADIUS=50000           # Radius (Fläche von 100.000x100.000 Blöcken)

# DEINE LINKS
URL_FORGE="https://maven.minecraftforge.net/net/minecraftforge/forge/${MC_VERSION}-${FORGE_VERSION}/forge-${MC_VERSION}-${FORGE_VERSION}-installer.jar"
URL_CHUNKY="https://cdn.modrinth.com/data/fALzjamp/versions/4FTDk9wv/Chunky-1.3.146.jar"
URL_BLUEMAP="https://cdn.modrinth.com/data/swbUV1cr/versions/aHbq9KFB/BlueMap-5.3-forge-1.20.jar"
URL_BOP="https://cdn.modrinth.com/data/HXF82T3G/versions/jxUqRzSD/BiomesOPlenty-forge-1.20.1-19.0.0.96.jar"
URL_TERRABLENDER="https://cdn.modrinth.com/data/kkmrDlKT/versions/zGconCHG/TerraBlender-forge-1.20.1-3.0.1.10.jar"
URL_C2ME="https://cdn.modrinth.com/data/yE4MbG65/versions/h9trYS7V/c2meF-0.2.0%2Balpha.12-all.jar"
URL_FERRITECORE="https://cdn.modrinth.com/data/uXXizFIs/versions/DG5Fn9Sz/ferritecore-6.0.1-forge.jar"
URL_MODERNFIX="https://cdn.modrinth.com/data/nmDcB62a/versions/PbIMs8a8/modernfix-forge-5.25.1%2Bmc1.20.1.jar"
URL_STARLIGHT="https://cdn.modrinth.com/data/iRfIGC1s/versions/cNa0vkNj/starlight-1.1.2%2Bforge.1cda73c.jar"

echo "=== INITIALISIERE ULTRA-SERVER SETUP (128 KERNE) ==="

# 1. Forge Installation
echo "Lade Forge Installer..."
wget -q --show-progress -O forge-installer.jar "$URL_FORGE"
java -jar forge-installer.jar --installServer > /dev/null
echo "eula=true" > eula.txt

# 2. Mods Herunterladen
mkdir -p mods
echo "Lade Mods in den mods/ Ordner..."
wget -q -O mods/chunky.jar "$URL_CHUNKY"
wget -q -O mods/bluemap.jar "$URL_BLUEMAP"
wget -q -O mods/biomesoplenty.jar "$URL_BOP"
wget -q -O mods/terrablender.jar "$URL_TERRABLENDER"
wget -q -O mods/c2me.jar "$URL_C2ME"
wget -q -O mods/ferritecore.jar "$URL_FERRITECORE"
wget -q -O mods/modernfix.jar "$URL_MODERNFIX"
wget -q -O mods/starlight.jar "$URL_STARLIGHT"

# 3. Server-Konfiguration (Large Biomes)
echo "Konfiguriere server.properties..."
cat <<EOT > server.properties
level-type=minecraft\:large_biomes
max-tick-time=-1
view-distance=12
simulation-distance=10
max-players=100
online-mode=true
EOT

# 4. C2ME Multi-Core Tuning (Wichtig für 128 Kerne)
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

# 5. BlueMap Tuning
mkdir -p config/bluemap
echo "accept-download: true" > config/bluemap/core.conf
echo "render-thread-count: $THREADS" >> config/bluemap/core.conf

# 6. Start-Skript (Optimiert für 256GB Heap)
echo "Erstelle optimiertes Start-Skript..."
cat <<EOT > start.sh
#!/bin/bash
java -Xms$ALLOCATED_RAM -Xmx$ALLOCATED_RAM \\
  -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 \\
  -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch \\
  -XX:G1NewSizePercent=40 -XX:G1MaxNewSizePercent=50 -XX:G1HeapRegionSize=32M \\
  -XX:G1ReservePercent=15 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 \\
  -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 \\
  -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem \\
  -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true \\
  -jar run.jar nogui
EOT
chmod +x start.sh

# 7. Start in Screen & Chunky Automatisierung
echo "Starte Server in Screen-Session 'minecraft'..."
screen -dmS minecraft ./start.sh

echo "Warte 120 Sekunden auf Server-Boot (generiere erste Chunks)..."
sleep 120

echo "Sende Chunky-Befehle für Pre-Generation (Radius $RADIUS)..."
screen -S minecraft -p 0 -X stuff "chunky world minecraft:overworld$(printf '\r')"
sleep 2
screen -S minecraft -p 0 -X stuff "chunky center 0 0$(printf '\r')"
sleep 2
screen -S minecraft -p 0 -X stuff "chunky radius $RADIUS$(printf '\r')"
sleep 2
screen -S minecraft -p 0 -X stuff "chunky start$(printf '\r')"

echo "=== SETUP ABGESCHLOSSEN ==="
echo "Status: Chunky generiert jetzt mit $THREADS Kernen."
echo "Befehl zum Zuschauen: screen -r minecraft"
echo "Befehl zum Verlassen der Ansicht: STRG+A, dann D"
