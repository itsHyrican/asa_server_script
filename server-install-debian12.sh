#!/bin/bash
#
# Install script for ARK Survival Ascended on Debian 12
#
# Uses Glorious Eggroll's build of Proton
# Please ensure to run this script as root (or at least with sudo)
#
# @LICENSE AGPLv3
# @AUTHOR  Charlie Powell - cdp1337@veraciousnetwork.com
#
# F*** Nitrado

# Only allow running as root
if [ "$LOGNAME" != "root" ]; then
  echo "Please run this script as root! (If you ran with 'su', use 'su -' instead)" >&2
  exit 1
fi

# We will use this directory as a working directory for source files that need downloaded.
[ -d /opt/game-resources ] || mkdir -p /opt/game-resources


# Preliminary requirements
dpkg --add-architecture i386
apt update
apt install -y software-properties-common apt-transport-https dirmngr ca-certificates curl wget sudo


# Enable "non-free" repos for Debian (for steamcmd)
if [ -e /etc/apt/sources.list.d/debian.sources ]; then
  # Digital Ocean uses an unusual location for its repo source.
  sed -i 's#^Components: .*#Components: main non-free contrib#g' /etc/apt/sources.list.d/debian.sources
elif grep -Eq '^deb (http|https)://.*debian\.org' /etc/apt/sources.list; then
  # Normal behaviour, debian.org is listed in sources.list
  if [ -z "$(grep -E '^deb (http|https)://.*debian\.org.*' /etc/apt/sources.list | grep 'contrib')" ]; then
    # Enable contrib if not already enabled.
    add-apt-repository -sy -c 'contrib'
  fi
  if [ -z "$(grep -E '^deb (http|https)://.*debian\.org.*' /etc/apt/sources.list | grep 'non-free')" ]; then
    # Enable non-free if not already enabled.
    add-apt-repository -sy -c 'non-free'
  fi
else
  # If the machine doesn't have the repos added, we need to add the full list.
  add-apt-repository -sy 'deb http://ftp.us.debian.org/debian/ bookworm non-free non-free-firmware contrib main'
  add-apt-repository -sy 'deb http://security.debian.org/debian-security bookworm-security non-free non-free-firmware contrib main'
  add-apt-repository -sy 'deb http://ftp.us.debian.org/debian/ bookworm-updates non-free non-free-firmware contrib main'
fi


# Install steam repo
curl -s http://repo.steampowered.com/steam/archive/stable/steam.gpg > /usr/share/keyrings/steam.gpg
echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/steam.gpg] http://repo.steampowered.com/steam/ stable steam" > /etc/apt/sources.list.d/steam.list


# Install steam binary and steamcmd
apt update
apt install -y lib32gcc-s1 steamcmd steam-launcher


# Grab Proton from Glorious Eggroll
# https://github.com/GloriousEggroll/proton-ge-custom
PROTON_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton8-21/GE-Proton8-21.tar.gz"
PROTON_TGZ="$(basename "$PROTON_URL")"
PROTON_NAME="$(basename "$PROTON_TGZ" ".tar.gz")"
if [ ! -e "/opt/game-resources/$PROTON_TGZ" ]; then
  wget "$PROTON_URL" -O "/opt/game-resources/$PROTON_TGZ"
fi

# Create a "steam" user account
# This will create the account with no password, so if you need to log in with this user,
# run `sudo passwd steam` to set a password.
[ -d /home/ark_extinction ] || useradd -m -U ark_extinction


# Install ARK Survival Ascended Dedicated
sudo -u ark_extinction /usr/games/steamcmd +login anonymous +app_update 2430930 validate +quit


# Determine where Steam is installed
# sometimes it's in ~/Steam, whereas other times it's in ~/.local/share/Steam
# @todo figure out why.... this is annoying.
if [ -e "/home/ark_extinction/Steam" ]; then
  STEAMDIR="/home/ark_extinction/Steam"
elif [ -e "/home/ark_extinction/.local/share/Steam" ]; then
  STEAMDIR="/home/ark_extinction/.local/share/Steam"
else
  echo "Unable to guess where Steam is installed." >&2
  exit 1
fi


# Extract GE Proton into this user's Steam path
[ -d "$STEAMDIR/compatibilitytools.d" ] || sudo -u ark_extinction mkdir -p "$STEAMDIR/compatibilitytools.d"
sudo -u ark_extinction tar -x -C "$STEAMDIR/compatibilitytools.d/" -f "/opt/game-resources/$PROTON_TGZ"


# Install default prefix into game compatdata path
[ -d "$STEAMDIR/steamapps/compatdata" ] || sudo -u ark_extinction mkdir -p "$STEAMDIR/steamapps/compatdata"
[ -d "$STEAMDIR/steamapps/compatdata/2430930" ] || \
  sudo -u ark_extinction cp "$STEAMDIR/compatibilitytools.d/$PROTON_NAME/files/share/default_pfx" "$STEAMDIR/steamapps/compatdata/2430930" -r


# Install the systemd service file for ARK Survival Ascended Dedicated Server (Island)
cat > /etc/systemd/system/ark-extinction.service <<EOF
[Unit]
Description=ASA: Aberration
After=network.target

[Service]
Type=simple
LimitNOFILE=10000
User=ark_extinction
Group=ark_extinction
ExecStartPre=/usr/games/steamcmd +login anonymous +app_update 2430930 validate +quit
WorkingDirectory=$STEAMDIR/steamapps/common/ARK Survival Ascended Dedicated Server/ShooterGame/Binaries/Win64
Environment=XDG_RUNTIME_DIR=/run/user/$(id -u)
Environment="STEAM_COMPAT_CLIENT_INSTALL_PATH=$STEAMDIR"
Environment="STEAM_COMPAT_DATA_PATH=$STEAMDIR/steamapps/compatdata/2430930"
ExecStart=$STEAMDIR/compatibilitytools.d/$PROTON_NAME/proton run ArkAscendedServer.exe Aberration_WP?listenPort=7780 -mods=929800,928793,937546,934749,950914,939228,947033,927084,930115,963648,926956,926259,931874
Restart=on-failure
RestartSec=20s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ark-extinction
systemctl start ark-extinction


# Create some helpful links for the user.
[ -e "/home/ark_extinction/island-GameUserSettings.ini" ] || \
  sudo -u ark_extinction ln -s "$STEAMDIR/steamapps/common/ARK Survival Ascended Dedicated Server/ShooterGame/Saved/Config/WindowsServer/GameUserSettings.ini" /home/ark_extinction/island-GameUserSettings.ini

[ -e "/home/ark_extinction/island-ShooterGame.log" ] || \
  sudo -u ark_extinction ln -s "$STEAMDIR/steamapps/common/ARK Survival Ascended Dedicated Server/ShooterGame/Saved/Logs/ShooterGame.log" /home/ark_extinction/island-ShooterGame.log

echo "================================================================================"
echo "If everything went well, ARK Survival Ascended should be installed and starting!"
echo ""
echo "To restart the server: sudo systemctl restart ark-extinction"
echo "To start the server:   sudo systemctl start ark-extinction"
echo "To stop the server:    sudo systemctl stop ark-extinction"
echo ""
echo "Configuration is available in /home/ark_extinction/island-GameUserSettings.ini"
