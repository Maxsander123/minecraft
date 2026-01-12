#!/bin/bash

# --- KONFIGURATION ---
SESSION_NAME="minecraft"
MC_USER=$(logname)
RAM="240G"  # Etwas Puffer lassen
THREADS="115"
RADIUS=50000

# Links
URL_FORGE="https://maven.minecraftforge.net/net/minecraftforge/forge/1.20.1-47.3.0/forge-1.20.1-47.3.0-installer.jar"
URL_CHUNKY="https://cdn.modrinth.com/data/fALzjamp/versions/4FTDk9wv/Chunky-1.3.146.jar"
URL_BLUEMAP="https://cdn.modrinth.com/data/swbUV1cr/versions/aHbq9KFB/BlueMap-5.3-forge-1.20.jar"
URL_BOP="https://cdn.modrinth.com/data/HXF82T3G/versions/jxUqRzSD/BiomesOPlenty-forge-1.20.1-19.0.0.96.jar"
URL_TERRABLENDER="https://cdn.modrinth.com/data/kkmrDlKT/versions/zGconCHG/TerraBlender-forge-1.20.1-3.0.1.10.jar"
URL_C2ME="https://cdn.modrinth.com/data/yE4MbG65/versions/h9trYS7V/c2meF-0.2.0%2Balpha.12-all.jar"
URL_FERRITECORE="https://cdn.modrinth.com/data/uXXizFIs/versions/DG5Fn9Sz/ferritecore-6.0.1-forge.jar"
URL_MODERNFIX="https://cdn.modrinth.com/data/nmDcB62a/versions/PbIMs8a8/modernfix-forge-5.25.1%2Bmc1.20.1.jar"
URL_STARLIGHT="https://cdn.modrinth.com/data/iRfIGC1s/versions/cNa0vkNj/starlight-1.1.2%2Bforge.1cda73c.jar"

# 1. Bereinigung und Vorbereitung
echo "=== 1. VORBEREITUNG ==="
# Wir arbeiten im aktuellen Verzeichnis
WORK_DIR=$(pwd)
chown $MC_USER:$MC_USER $WORK_DIR

# 2. Forge Installation (Diesmal mit sichtbarem Output)
echo "=== 2. FORGE INSTALLATION (Lade Bibliotheken...) ==="
wget -q --show-progress -O forge-installer.jar "$URL_FORGE"
# WICHTIG: Installation als MC_USER ausführen
sudo -u $MC_USER java -jar forge-installer.jar --installServer | grep "Extracting"

# 3. EULA & Mods
echo "=== 3. MODS & CONFIG ==="
echo "eula=true" > eula.txt
mkdir -p mods config config/bluemap
wget -q -O mods/chunky.jar "$URL_CHUNKY"
wget -q -O mods/bluemap.jar "$URL_BLUEMAP"
wget -q -O mods/biomesoplenty.jar "$URL_BOP"
wget -q -O mods/terrablender.jar "$URL_TERRABLENDER"
wget -q -O mods/c2me.jar "$URL_C2ME"
wget -q -O mods/ferritecore.jar "$URL_FERRITECORE"
wget -q -O mods/modernfix.jar "$URL_MODERNFIX"
wget -q -O mods/starlight.jar "$URL_STARLIGHT"

# Configs schreiben
echo "level-type=minecraft\:large_biomes" > server.properties
echo "max-tick-time=-1" >> server.properties

cat <<EOT > config/c2me.toml
version = 3
[general]
    maxWorkerThreads = $THREADS
EOT

echo "accept-download: true" > config/bluemap/core.conf
echo "render-thread-count: $THREADS" >> config/bluemap/core.conf

# 4. Start-Skript erstellen
echo "=== 4. ERSTELLE START-SKRIPT ==="
cat <<EOT > start.sh
#!/bin/bash
java -Xms$RAM -Xmx$RAM \\
  -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 \\
  -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch \\
  -XX:G1NewSizePercent=40 -XX:G1MaxNewSizePercent=50 -XX:G1HeapRegionSize=32M \\
  -XX:InitiatingHeapOccupancyPercent=15 \\
  -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true \\
  @libraries/net/minecraftforge/forge/1.20.1-47.3.0/unix_args.txt "\$@"
EOT
chmod +x start.sh
chown $MC_USER:$MC_USER start.sh eula.txt server.properties
chown -R $MC_USER:$MC_USER mods config libraries

# 5. Start im Screen
echo "=== 5. STARTE SERVER ==="
# Wir löschen alte Logs, um den Start sauber zu tracken
rm -f logs/latest.log
sudo -u $MC_USER screen -dmS $SESSION_NAME ./start.sh nogui

echo "Warte darauf, dass der Server bereit ist (log-scan)..."
# Loop bis "Done" im Log erscheint
timeout=300
count=0
while ! grep -q "Done" logs/latest.log 2>/dev/null; do
    sleep 5
    count=$((count+5))
    echo -n "."
    if [ $count -gt $timeout ]; then
        echo "FEHLER: Server braucht zu lange zum Starten. Prüfe 'screen -r minecraft'"
        exit 1
    fi
done

echo -e "\nServer ist ONLINE! Sende Chunky Befehle..."
sudo -u $MC_USER screen -S $SESSION_NAME -p 0 -X stuff "chunky world minecraft:overworld$(printf '\r')"
sleep 1
sudo -u $MC_USER screen -S $SESSION_NAME -p 0 -X stuff "chunky center 0 0$(printf '\r')"
sleep 1
sudo -u $MC_USER screen -S $SESSION_NAME -p 0 -X stuff "chunky radius $RADIUS$(printf '\r')"
sleep 1
sudo -u $MC_USER screen -S $SESSION_NAME -p 0 -X stuff "chunky start$(printf '\r')"

echo "----------------------------------------------------"
echo "ERFOLG: Chunky generiert jetzt."
echo "Konsole öffnen: screen -r $SESSION_NAME"
echo "----------------------------------------------------"
