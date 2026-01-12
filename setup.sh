#!/bin/bash

# --- KONFIGURATION (Extreme Hardware: 128 Kerne / 300GB RAM) ---
MC_VERSION="1.20.1"
FORGE_VERSION="47.3.0"
ALLOCATED_RAM="256G"   # 256GB für den Server
THREADS_TO_USE="110"   # Wir lassen etwas Puffer für das System (128 Gesamt)
RADIUS=50000           # 100.000 x 100.000 Blöcke Fläche

# Download-URLs (Mods)
FORGE_URL="https://maven.minecraftforge.net/net/minecraftforge/forge/${MC_VERSION}-${FORGE_VERSION}/forge-${MC_VERSION}-${FORGE_VERSION}-installer.jar"
CHUNKY_URL="https://cdn.modrinth.com/data/fALm0ZpS/versions/fALm0ZpS/Chunky-1.4.28.jar"
BLUEMAP_URL="https://cdn.modrinth.com/data/swN6o9JI/versions/BNoWlXvK/BlueMap-3.21-forge-1.20.jar"
BOP_URL="https://cdn.modrinth.com/data/idX9dbUf/versions/idX9dbUf/BiomesOPlenty-1.20.1-18.0.0.592.jar"
TERRABLENDER_URL="https://cdn.modrinth.com/data/m797YI6X/versions/m797YI6X/TerraBlender-forge-1.20.1-3.0.1.7.jar"

# PERFORMANCE-MONSTER (C2ME für 128 Kerne, Canary, FerriteCore)
C2ME_URL="https://mediafilez.forgecdn.net/files/5129/744/c2me-forge-mc1.20.1-0.2.0%2Balpha.11.jar" # Inoffizieller Port/Version
CANARY_URL="https://cdn.modrinth.com/data/A7RjybD9/versions/vYw7x4m8/canary-mc1.20.1-0.3.3.jar"
FERRITECORE_URL="https://cdn.modrinth.com/data/u6h9ZpRw/versions/A1S6m7lW/ferritecore-6.0.1-forge.jar"
MODERNFIX_URL="https://cdn.modrinth.com/data/nmUakF6m/versions/H8YvD9M5/modernfix-forge-5.18.1+mc1.20.1.jar"

echo "=== START: MASSIVE MULTI-CORE SETUP ==="

# 1. Forge Installation
wget -O forge-installer.jar "$FORGE_URL"
java -jar forge-installer.jar --installServer > /dev/null
echo "eula=true" > eula.txt

# 2. Mods herunterladen
mkdir -p mods
wget -O mods/chunky.jar "$CHUNKY_URL"
wget -O mods/bluemap.jar "$BLUEMAP_URL"
wget -O mods/biomesoplenty.jar "$BOP_URL"
wget -O mods/terrablender.jar "$TERRABLENDER_URL"
wget -O mods/c2me.jar "$C2ME_URL"
wget -O mods/canary.jar "$CANARY_URL"
wget -O mods/ferritecore.jar "$FERRITECORE_URL"
wget -O mods/modernfix.jar "$MODERNFIX_URL"

# 3. Welt-Konfiguration (Large Biomes)
echo "level-type=minecraft\:large_biomes" > server.properties
echo "max-tick-time=-1" >> server.properties # Wichtig: Verhindert Server-Shutdown bei 100% Last

# 4. BlueMap Multi-Thread Tuning
mkdir -p config/bluemap
echo "accept-download: true" > config/bluemap/core.conf
echo "render-thread-count: $THREADS_TO_USE" >> config/bluemap/core.conf

# 5. C2ME Konfiguration (Hier wird Multi-Core erzwungen)
mkdir -p config
cat <<EOT > config/c2me.toml
version = 3
[general]
    maxWorkerThreads = $THREADS_TO_USE
[ioSystem]
    asyncIO = true
    chunkDataUnloadQueue = true
[threadingUtils]
    useGlobalExecutor = true
EOT

# 6. Start-Skript mit Profi-Flags (für 256GB RAM optimiert)
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

# 7. Server starten und Chunky befehlen
screen -dmS minecraft ./start.sh
echo "Server startet... warte 120s (C2ME & Forge Initialisierung)..."
sleep 120

# Chunky Befehle
screen -S minecraft -p 0 -X stuff "chunky world minecraft:overworld$(printf '\r')"
sleep 2
screen -S minecraft -p 0 -X stuff "chunky center 0 0$(printf '\r')"
sleep 2
screen -S minecraft -p 0 -X stuff "chunky radius $RADIUS$(printf '\r')"
sleep 2
screen -S minecraft -p 0 -X stuff "chunky start$(printf '\r')"

echo "=== SETUP ABGESCHLOSSEN ==="
echo "Monitoring mit: screen -r minecraft"
echo "Prüfe CPU-Auslastung mit: top oder htop"
