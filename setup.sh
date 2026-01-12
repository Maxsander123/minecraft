#!/bin/bash

# --- CHECK: BIST DU ROOT/SUDO? ---
if [[ $EUID -ne 0 ]]; then
   echo "Bitte starte das Skript mit sudo: sudo ./setup.sh"
   exit 1
fi

# --- KONFIGURATION ---
MC_USER=$(logname) # Der Benutzer, dem der Server gehören soll
SESSION_NAME="minecraft"
RAM="256G"
THREADS="120"
RADIUS=50000

# Deine Mod-Links
URL_FORGE="https://maven.minecraftforge.net/net/minecraftforge/forge/1.20.1-47.3.0/forge-1.20.1-47.3.0-installer.jar"
URL_CHUNKY="https://cdn.modrinth.com/data/fALzjamp/versions/4FTDk9wv/Chunky-1.3.146.jar"
URL_BLUEMAP="https://cdn.modrinth.com/data/swbUV1cr/versions/aHbq9KFB/BlueMap-5.3-forge-1.20.jar"
URL_BOP="https://cdn.modrinth.com/data/HXF82T3G/versions/jxUqRzSD/BiomesOPlenty-forge-1.20.1-19.0.0.96.jar"
URL_TERRABLENDER="https://cdn.modrinth.com/data/kkmrDlKT/versions/zGconCHG/TerraBlender-forge-1.20.1-3.0.1.10.jar"
URL_C2ME="https://cdn.modrinth.com/data/yE4MbG65/versions/h9trYS7V/c2meF-0.2.0%2Balpha.12-all.jar"
URL_FERRITECORE="https://cdn.modrinth.com/data/uXXizFIs/versions/DG5Fn9Sz/ferritecore-6.0.1-forge.jar"
URL_MODERNFIX="https://cdn.modrinth.com/data/nmDcB62a/versions/PbIMs8a8/modernfix-forge-5.25.1%2Bmc1.20.1.jar"
URL_STARLIGHT="https://cdn.modrinth.com/data/iRfIGC1s/versions/cNa0vkNj/starlight-1.1.2%2Bforge.1cda73c.jar"

echo "=== 1. INSTALLIERE SYSTEM-ABHÄNGIGKEITEN ==="
apt update
apt install -y openjdk-17-jdk screen wget curl htop

echo "=== 2. FORGE INSTALLATION ==="
mkdir -p /home/$MC_USER/minecraft
cd /home/$MC_USER/minecraft

wget -q --show-progress -O forge-installer.jar "$URL_FORGE"
java -jar forge-installer.jar --installServer > /dev/null
echo "eula=true" > eula.txt

echo "=== 3. MODS DOWNLOAD ==="
mkdir -p mods
wget -q -O mods/chunky.jar "$URL_CHUNKY"
wget -q -O mods/bluemap.jar "$URL_BLUEMAP"
wget -q -O mods/biomesoplenty.jar "$URL_BOP"
wget -q -O mods/terrablender.jar "$URL_TERRABLENDER"
wget -q -O mods/c2me.jar "$URL_C2ME"
wget -q -O mods/ferritecore.jar "$URL_FERRITECORE"
wget -q -O mods/modernfix.jar "$URL_MODERNFIX"
wget -q -O mods/starlight.jar "$URL_STARLIGHT"

echo "=== 4. KONFIGURATION (PERFORMANCE & LARGE BIOMES) ==="
# server.properties
cat <<EOT > server.properties
level-type=minecraft\:large_biomes
max-tick-time=-1
view-distance=12
simulation-distance=10
online-mode=true
EOT

# C2ME Threads
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

# BlueMap Threads
mkdir -p config/bluemap
echo "accept-download: true" > config/bluemap/core.conf
echo "render-thread-count: $THREADS" >> config/bluemap/core.conf

# user_jvm_args.txt (Die offizielle Forge-Art RAM zu setzen)
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

# Rechte an den User übertragen
chown -R $MC_USER:$MC_USER /home/$MC_USER/minecraft

echo "=== 5. STARTE SERVER IM SCREEN '$SESSION_NAME' ==="
# Wir starten als der normale User, nicht als Root
sudo -u $MC_USER screen -dmS $SESSION_NAME bash ./run.sh

echo "Warte 120 Sekunden auf Server-Boot..."
sleep 120

echo "Sende Chunky-Befehle an Konsole..."
sudo -u $MC_USER screen -S $SESSION_NAME -p 0 -X stuff "chunky world minecraft:overworld$(printf '\r')"
sleep 2
sudo -u $MC_USER screen -S $SESSION_NAME -p 0 -X stuff "chunky center 0 0$(printf '\r')"
sleep 2
sudo -u $MC_USER screen -S $SESSION_NAME -p 0 -X stuff "chunky radius $RADIUS$(printf '\r')"
sleep 2
sudo -u $MC_USER screen -S $SESSION_NAME -p 0 -X stuff "chunky start$(printf '\r')"

echo "--------------------------------------------------------"
echo "FERTIG! Der Server generiert jetzt im Hintergrund."
echo "Konsole öffnen:  screen -r $SESSION_NAME"
echo "Hardware-Check:  htop"
echo "--------------------------------------------------------"
