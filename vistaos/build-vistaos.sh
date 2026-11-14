#!/bin/bash
# ============================================================
#  VistaOS - script de build (base Debian 13 + XFCE + Calamares)
#  Debian/Ubuntu : build direct. Arch & autres : build automatique
#  dans un conteneur Debian (Docker ou Podman requis).
#  Internet + ~15 Go libres. Duree : 20 a 60 minutes.
# ============================================================
set -e

SELF="$(readlink -f "$0")"
OUT_DIR="$(dirname "$SELF")"

# ---- Arch / Fedora / autre : on relance le script dans un conteneur Debian ----
if ! command -v apt-get >/dev/null 2>&1 && [ -z "$VISTAOS_IN_CONTAINER" ]; then
  if command -v docker >/dev/null 2>&1; then ENGINE="docker"
  elif command -v podman >/dev/null 2>&1; then ENGINE="podman"
  else
    echo "Pas de Docker ni Podman. Sur Arch :"
    echo "  sudo pacman -S docker && sudo systemctl enable --now docker"
    echo "puis relance ./build-vistaos.sh"
    exit 1
  fi
  echo ">>> Systeme non-Debian detecte : build dans un conteneur Debian 13 ($ENGINE)"
  sudo $ENGINE run --rm --privileged \
    -e VISTAOS_IN_CONTAINER=1 -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
    -v "$SELF":/build.sh:ro -v "$OUT_DIR":/out \
    debian:trixie bash /build.sh
  echo ""
  echo "Termine. Ton ISO : $OUT_DIR/VistaOS.iso"
  exit 0
fi

# ---- Dans le conteneur : on est root, pas de sudo ----
if [ -n "$VISTAOS_IN_CONTAINER" ]; then
  SUDO=""
  OUT_DIR="/out"
  apt-get update && apt-get install -y sudo ca-certificates >/dev/null
else
  if [ "$(id -u)" -eq 0 ]; then
    echo "Lance ce script avec ton utilisateur normal (pas root), il demandera sudo."
    exit 1
  fi
  SUDO="sudo"
fi

WORK="$HOME/vistaos-build"

echo ">>> [1/8] Installation des outils..."
$SUDO apt-get update
$SUDO apt-get install -y live-build imagemagick

echo ">>> [2/8] Preparation du dossier $WORK"
if [ -d "$WORK" ]; then
  (cd "$WORK" && $SUDO lb clean --purge 2>/dev/null || true)
  $SUDO rm -rf "$WORK"
fi
mkdir -p "$WORK"
cd "$WORK"

echo ">>> [3/8] Configuration live-build..."
lb config \
  --distribution trixie \
  --architectures amd64 \
  --binary-images iso-hybrid \
  --bootloaders "grub-pc,grub-efi" \
  --debian-installer none \
  --archive-areas "main contrib non-free non-free-firmware" \
  --iso-application "VistaOS" --iso-volume "VistaOS" \
  --bootappend-live "boot=live components quiet splash"

echo ">>> [4/8] Liste des paquets..."
mkdir -p config/package-lists
cat > config/package-lists/custom.list.chroot <<'EOF'
xorg lightdm lightdm-gtk-greeter
xfce4 xfce4-terminal xfce4-whiskermenu-plugin xfce4-power-manager
thunar-archive-plugin network-manager-gnome
pipewire-audio pavucontrol
arc-theme papirus-icon-theme fonts-inter
rofi conky-all zram-tools
firefox-esr
firmware-linux firmware-realtek firmware-atheros
plymouth plymouth-themes imagemagick yad
calamares calamares-settings-debian
EOF

echo ">>> [5/8] Reglages du bureau..."
S=config/includes.chroot/etc/skel
mkdir -p $S/.config/xfce4/xfconf/xfce-perchannel-xml $S/.config/autostart config/includes.chroot/etc/default

cat > $S/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Arc-Dark"/>
    <property name="IconThemeName" type="string" value="Papirus-Dark"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName" type="string" value="Inter 10"/>
  </property>
</channel>
EOF

cat > $S/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="Arc-Dark"/>
    <property name="use_compositing" type="bool" value="true"/>
  </property>
</channel>
EOF

# --- UNE SEULE barre des taches, en bas, style Vista ---
mkdir -p $S/.config/xfce4/panel $S/.config/gtk-3.0

cat > $S/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml <<'PANELEOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
    <property name="dark-mode" type="bool" value="true"/>
    <property name="panel-1" type="empty">
      <property name="position" type="string" value="p=10;x=0;y=0"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="length" type="uint" value="100"/>
      <property name="size" type="uint" value="40"/>
      <property name="nrows" type="uint" value="1"/>
      <property name="mode" type="uint" value="0"/>
      <property name="plugin-ids" type="array">
        <value type="int" value="1"/>
        <value type="int" value="2"/>
        <value type="int" value="3"/>
        <value type="int" value="4"/>
        <value type="int" value="5"/>
        <value type="int" value="6"/>
      </property>
    </property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-1" type="string" value="whiskermenu"/>
    <property name="plugin-2" type="string" value="tasklist">
      <property name="grouping" type="uint" value="1"/>
      <property name="show-labels" type="bool" value="true"/>
    </property>
    <property name="plugin-3" type="string" value="separator">
      <property name="expand" type="bool" value="true"/>
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-4" type="string" value="systray"/>
    <property name="plugin-5" type="string" value="clock">
      <property name="mode" type="uint" value="2"/>
      <property name="digital-layout" type="uint" value="3"/>
      <property name="digital-time-format" type="string" value="%H:%M%n%d/%m/%Y"/>
    </property>
    <property name="plugin-6" type="string" value="showdesktop"/>
  </property>
</channel>
PANELEOF

# Bouton Demarrer = l'orbe VistaOS
cat > $S/.config/xfce4/panel/whiskermenu-1.rc <<'WMEOF'
[General]
button-icon=/usr/share/vistaos/start-orb.png
button-title=
show-button-title=false
show-button-icon=true
button-single-row=true
menu-width=520
menu-height=520
WMEOF

# Verre bleu "Aero" sur la barre
cat > $S/.config/gtk-3.0/gtk.css <<'CSSEOF'
.xfce4-panel.background, #XfcePanelWindow {
  background-image: linear-gradient(to bottom,
    rgba(150,205,245,0.92) 0%, rgba(55,125,200,0.94) 45%,
    rgba(15,60,125,0.96) 52%, rgba(30,100,175,0.96) 100%);
  border-top: 1px solid rgba(255,255,255,0.65);
  color: #ffffff;
}
.xfce4-panel button {
  background-image: none; background-color: transparent;
  border: 1px solid transparent; border-radius: 5px;
  box-shadow: none; color: #ffffff; text-shadow: 0 1px 2px rgba(0,0,0,0.6);
}
.xfce4-panel button:hover {
  background-image: linear-gradient(to bottom, rgba(255,255,255,0.45), rgba(255,255,255,0.12));
  border-color: rgba(255,255,255,0.55);
}
.xfce4-panel button:checked {
  background-image: linear-gradient(to bottom, rgba(255,255,255,0.30), rgba(120,190,255,0.25));
  border-color: rgba(255,255,255,0.7);
}
CSSEOF

# Fond d'ecran + bureau propre (pas de disquette)
DX=$S/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml
{
echo '<?xml version="1.0" encoding="UTF-8"?>'
echo '<channel name="xfce4-desktop" version="1.0">'
echo '  <property name="backdrop" type="empty"><property name="screen0" type="empty">'
for m in monitor0 monitor1 monitorVGA-1 monitorLVDS-1 monitorLVDS1 monitoreDP-1 monitorHDMI-1 monitorVirtual-1 monitorDVI-I-1 monitorDP-1; do
  echo "    <property name=\"$m\" type=\"empty\"><property name=\"workspace0\" type=\"empty\">"
  echo '      <property name="color-style" type="int" value="0"/><property name="image-style" type="int" value="5"/><property name="last-image" type="string" value="/usr/share/backgrounds/vistaos.png"/>'
  echo '    </property></property>'
done
echo '  </property></property>'
echo '  <property name="desktop-icons" type="empty"><property name="file-icons" type="empty"><property name="show-filesystem" type="bool" value="false"/><property name="show-removable" type="bool" value="false"/></property></property>'
echo '</channel>'
} > "$DX"

cat > config/includes.chroot/etc/default/zramswap <<'EOF'
ALGO=zstd
PERCENT=50
EOF

echo ">>> [6/8] Animation de demarrage + ecran de bienvenue..."
P=config/includes.chroot/usr/share/plymouth/themes/vistaos
mkdir -p $P

cat > $P/vistaos.plymouth <<'EOF'
[Plymouth Theme]
Name=VistaOS
Description=Animation de demarrage VistaOS
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/vistaos
ScriptFile=/usr/share/plymouth/themes/vistaos/vistaos.script
EOF

cat > $P/vistaos.script <<'EOF'
Window.SetBackgroundTopColor(0.00, 0.10, 0.25);
Window.SetBackgroundBottomColor(0.00, 0.45, 0.65);

global.cx = Window.GetWidth() / 2;
global.cy = Window.GetHeight() / 2;
global.t = 0;

orb = Image("orb.png");
for (i = 0; i < 6; i++) { global.s[i] = Sprite(orb); }

title = Image.Text("VistaOS", 1, 1, 1, 1, "Sans Bold 38");
ts = Sprite(title);
ts.SetPosition(global.cx - title.GetWidth() / 2, global.cy - 170, 10);

sub = Image.Text("Linux inside", 0.7, 0.95, 1, 1, "Monospace 12");
ss = Sprite(sub);
ss.SetPosition(global.cx - sub.GetWidth() / 2, global.cy - 110, 10);

fun refresh() {
  global.t++;
  for (i = 0; i < 6; i++) {
    a = global.t * 0.07 - i * 0.45;
    global.s[i].SetX(global.cx + 55 * Math.Cos(a) - 32);
    global.s[i].SetY(global.cy + 20 + 55 * Math.Sin(a) - 32);
    global.s[i].SetOpacity(1 - i * 0.16);
    global.s[i].SetZ(5);
  }
}
Plymouth.SetRefreshFunction(refresh);
EOF

mkdir -p config/includes.chroot/usr/local/bin
cat > config/includes.chroot/usr/local/bin/vistaos-welcome <<'EOF'
#!/bin/bash
yad --title="VistaOS" --center --width=640 --height=340 --no-escape \
  --image=/usr/share/vistaos/logo.png \
  --text="<span size='xx-large'><b>Bienvenue sur VistaOS</b></span>\n\nBase Debian - XFCE - leger et elegant" \
  --button="Essayer VistaOS:0" --button="Installer VistaOS:2"
if [ $? -eq 2 ]; then sudo -E calamares; fi
EOF
chmod +x config/includes.chroot/usr/local/bin/vistaos-welcome

cat > $S/.config/autostart/welcome.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Bienvenue VistaOS
Exec=/usr/local/bin/vistaos-welcome
EOF

echo ">>> [7/8] Theme GRUB, images et branding..."
mkdir -p config/hooks/live
cat > config/hooks/live/010-vistaos.hook.chroot <<'HOOK'
#!/bin/bash
set -e
mkdir -p /usr/share/vistaos /usr/share/grub/themes/vistaos /usr/share/backgrounds

# Orbe lumineux
convert -size 64x64 radial-gradient:'#e8ffff-#0a84d8' \
  \( -size 64x64 xc:black -fill white -draw 'circle 32,32 32,3' \) \
  -alpha off -compose CopyOpacity -composite /usr/share/plymouth/themes/vistaos/orb.png
cp /usr/share/plymouth/themes/vistaos/orb.png /usr/share/vistaos/orb.png

# Logo VistaOS (original) : orbe vitre + "V" bicolore
L=/usr/share/vistaos
convert -size 512x512 radial-gradient:'#8fe6ff-#04408a' \
  \( -size 512x512 xc:black -fill white -draw 'circle 256,256 256,8' \) \
  -alpha off -compose CopyOpacity -composite /tmp/orb512.png
convert /tmp/orb512.png \
  -fill none -stroke 'rgba(255,255,255,0.85)' -strokewidth 8 -draw 'circle 256,256 256,12' \
  -stroke none -fill 'rgba(255,255,255,0.32)' -draw 'ellipse 256,125 185,90 0,360' \
  -fill 'rgba(0,0,0,0.25)' -draw 'polygon 158,182 223,182 262,312 301,182 366,182 291,386 233,386' \
  -fill white -draw 'polygon 150,170 215,170 256,300 297,170 362,170 285,372 227,372' \
  -fill '#7dffb0' -draw 'polygon 297,170 362,170 327,262 268,262' \
  $L/logo-512.png
convert $L/logo-512.png -resize 256x256 $L/logo.png
convert $L/logo-512.png -resize 44x44 $L/start-orb.png

# Fond d'ecran et fond GRUB
convert -size 1920x1080 radial-gradient:'#4fd0ff-#02163a' \
  \( -size 1920x1080 xc:none -fill 'rgba(255,255,255,0.28)' -draw 'ellipse 600,1150 1500,300 0,360' -blur 0x45 \) -composite \
  \( -size 1920x1080 xc:none -fill 'rgba(120,255,220,0.22)' -draw 'ellipse 1550,180 900,170 0,360' -blur 0x70 \) -composite \
  /usr/share/backgrounds/vistaos.png
cp /usr/share/backgrounds/vistaos.png /usr/share/grub/themes/vistaos/background.png

# Theme GRUB
cat > /usr/share/grub/themes/vistaos/theme.txt <<'EOT'
desktop-image: "background.png"
title-text: "VistaOS"
title-color: "#ffffff"
terminal-font: "Unifont Regular 16"
+ boot_menu {
  left = 25%
  top = 30%
  width = 50%
  height = 40%
  item_color = "#bfe9ff"
  selected_item_color = "#ffffff"
  item_height = 36
  item_spacing = 8
}
+ progress_bar {
  id = "__timeout__"
  left = 25%
  top = 80%
  width = 50%
  height = 12
  fg_color = "#3fd0ff"
  bg_color = "#0a2a4a"
  text = "@TIMEOUT_NOTIFICATION_SHORT@"
  text_color = "#ffffff"
}
EOT

# Reglages GRUB du systeme installe
mkdir -p /etc/default/grub.d
cat > /etc/default/grub.d/vistaos.cfg <<'EOT'
GRUB_DISTRIBUTOR="VistaOS"
GRUB_THEME="/usr/share/grub/themes/vistaos/theme.txt"
GRUB_TIMEOUT=5
GRUB_GFXMODE=1024x768
EOT

# Nom du systeme et de l'installeur
sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="VistaOS (base Debian)"/; s/^NAME=.*/NAME="VistaOS"/' /etc/os-release
find /etc/calamares /usr/share/calamares -name branding.desc -exec sed -i 's/Debian GNU\/Linux/VistaOS/g' {} + 2>/dev/null || true

# Logo et couleurs de l'installeur Calamares
BDESC=$(find /usr/share/calamares/branding -name branding.desc 2>/dev/null | head -n1)
if [ -n "$BDESC" ]; then
  BRD=$(dirname "$BDESC")
  for n in $(grep -o '[A-Za-z0-9_.-]*\.png' "$BDESC" | sort -u); do
    f="$BRD/$n"
    [ -f "$f" ] || continue
    dims=$(identify -format '%w %h' "$f" 2>/dev/null || true)
    [ -n "$dims" ] || continue
    w=${dims% *}; h=${dims#* }
    convert $L/logo-512.png -resize "${w}x${h}" -background none -gravity center -extent "${w}x${h}" "$f" || true
  done
  sed -i 's/^\(\s*sidebarBackground:\).*/\1 "#0a3a78"/; s/^\(\s*sidebarText:\).*/\1 "#ffffff"/; s/^\(\s*sidebarTextSelect:\).*/\1 "#3fd0ff"/' "$BDESC" || true
fi

# Theme Plymouth
plymouth-set-default-theme vistaos
update-initramfs -u
HOOK
chmod +x config/hooks/live/010-vistaos.hook.chroot

# Menu GRUB de l'ISO live
if [ -d /usr/share/live/build/bootloaders ]; then
  cp -r /usr/share/live/build/bootloaders config/
  convert -size 640x480 radial-gradient:'#1fa8e0-#02102a' \
    -gravity north -fill white -pointsize 44 -annotate +0+30 'VistaOS' splash.png
  cp splash.png config/bootloaders/grub-pc/splash.png 2>/dev/null || true
  cp splash.png config/bootloaders/grub-efi/splash.png 2>/dev/null || true
  sed -i 's/Debian GNU\/Linux/VistaOS/g; s/Debian Live/VistaOS Live/g' config/bootloaders/grub-pc/*.cfg* config/bootloaders/grub-efi/*.cfg* 2>/dev/null || true
fi

echo ">>> [8/8] Construction de l'ISO (patience, 20 a 60 min)..."
$SUDO lb build 2>&1 | tee build.log

ISO=$(ls "$WORK"/*.iso 2>/dev/null | head -n1 || true)
if [ -n "$ISO" ]; then
  cp "$ISO" "$OUT_DIR/VistaOS.iso"
  if [ -n "$HOST_UID" ]; then chown "$HOST_UID":"$HOST_GID" "$OUT_DIR/VistaOS.iso"; else $SUDO chown "$USER":"$USER" "$OUT_DIR/VistaOS.iso"; fi
  echo ""
  echo "=========================================="
  echo " TERMINE ! Ton ISO : $OUT_DIR/VistaOS.iso"
  echo " Mets-le sur une cle USB avec Balena Etcher."
  echo "=========================================="
else
  echo "Le build a echoue. Regarde la fin de $WORK/build.log"
  exit 1
fi
