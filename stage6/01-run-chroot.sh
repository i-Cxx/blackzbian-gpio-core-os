#!/bin/bash

# Definieren von ANSI-Farbcodes
# ---
COLOR_RESET='\033[0m'
COLOR_RED='\033[0;31m'    # Rot für ERROR
COLOR_GREEN='\033[0;32m'  # Grün für INFO
COLOR_YELLOW='\033[0;33m' # Gelb für WARN
COLOR_BLUE='\033[0;34m'   # Blau für DEBUG

# ---
# Die eco-Funktion
# ---
eco() {
    local type="$1"
    shift # Entfernt das erste Argument (den Typ)
    local message="$*" # Speichert den Rest der Argumente als Nachricht

    case "$type" in
        i|info)
            echo -e "${COLOR_GREEN}INFO:${COLOR_RESET} ${message}"
            ;;
        w|warn)
            echo -e "${COLOR_YELLOW}WARN:${COLOR_RESET} ${message}"
            ;;
        e|error)
            echo -e "${COLOR_RED}ERROR:${COLOR_RESET} ${message}"
            ;;
        d|debug)
            echo -e "${COLOR_BLUE}DEBUG:${COLOR_RESET} ${message}"
            ;;
        *)
            # Standardausgabe, wenn kein bekannter Typ angegeben wurde
            echo -e "${message}"
            ;;
    esac
}

# Beispiel: pi-gen/stage2/01-run-chroot.sh

# Installiere Git, falls noch nicht vorhanden
# stage2 installiert normalerweise git, aber es schadet nicht, es hier hinzuzufügen
apt-get update
apt-get install -y git

# Klonen Sie Ihr Repository
# Erstellen Sie den Zielordner im Root-Dateisystem des Images
mkdir -p /opt/share

# Klonen Sie das Repository
# Ersetzen Sie <REPO_URL> durch die tatsächliche URL Ihres Git-Repos
# Ersetzen Sie <BRANCH> durch den gewünschten Branch (optional)
git clone https://github.com/WiringPi/WiringPi /opt/share/WiringPi
git clone https://github.com/WiringPi/WiringPi-Perl /opt/share/WiringPi-Perl
git clone https://github.com/WiringPi/WiringPi-Ruby /opt/share/WiringPi-Ruby
git clone https://github.com/WiringPi/WiringPi-Python /opt/share/WiringPi-Python
git clone https://github.com/WiringPi/WiringPi-Node /opt/share/WiringPi-Node
git clone https://github.com/WiringPi/WiringPi-PHP /opt/share/WiringPi-PHP
git clone https://github.com/rm-hull/luma.oled /opt/share/luma.oled

# Oder für einen spezifischen Branch:
# git clone -b <BRANCH> https://github.com/yourusername/your_repository.git /home/pi/my_project

# Setzen Sie den Besitzer des geklonten Ordners auf den Standard-Pi-Benutzer
chown -hR blackzberry:blackzberry /opt/share/

apt-get install -y \
    python3-pip \
    python3-dev \
    python3-setuptools \
    python3-wheel

python3 -m pip install --upgrade pip 
python3 -m pip install --upgrade setuptools wheel
python3 -m pip install --upgrade rpi.gpio gpiozero luma.oled 
# Optional: Zusätzliche Schritte nach dem Klonen (z.B. Installation von Abhängigkeiten)
# Wenn Ihr Projekt Python-Abhängigkeiten hat:
# pip3 install -r /home/pi/my_project/requirements.txt

# Oder wenn es ein Shell-Skript ist, das ausgeführt werden soll:
# chmod +x /home/pi/my_project/setup.sh
# /home/pi/my_project/setup.sh

#!/bin/bash

# Diese Skript wird im Chroot ausgeführt.

# Funktion zum Installieren von Paketen aus einer 00-packages Datei
install_packages_from_file() {
    local packages_file="$1"
    if [ -f "$packages_file" ]; then
        echo "INFO: Installing packages from $packages_file..."
        # Verwende xargs, um Leerzeilen und Kommentare zu ignorieren
        # und Pakete in einem Rutsch zu installieren
        cat "$packages_file" | grep -vE '^\s*($|#)' | xargs -r apt-get install -y
        if [ $? -ne 0 ]; then
            echo "ERROR: Failed to install packages from $packages_file"
            exit 1
        fi
    else
        echo "WARN: Package file $packages_file not found."
    fi
}

# Funktion zum Ausführen eines Shell-Skripts
run_script_in_chroot() {
    local script_path="$1"
    if [ -f "$script_path" ]; then
        echo "INFO: Running script $script_path..."
        # Führe das Skript im aktuellen Shell-Kontext aus,
        # damit die Umgebung des Chroots genutzt wird.
        bash "$script_path"
        if [ $? -ne 0 ]; then
            echo "ERROR: Script $script_path failed!"
            exit 1
        fi
    else
        echo "WARN: Script $script_path not found."
    fi
}

# Reihenfolge der Ausführung Ihrer Unter-Stages
# ---

echo "INFO: Processing custom stage_zero0 sub-sections..."

# 1. 00-system-packages
install_packages_from_file "./00-system-packages/00-packages"
run_script_in_chroot "./00-system-packages/01-run.sh"

# 2. 00-build-packages
install_packages_from_file "./00-build-packages/00-packages"
run_script_in_chroot "./00-build-packages/01-run.sh"

# 3. 00-gpio-packages
install_packages_from_file "./00-gpio-packages/00-packages"
run_script_in_chroot "./00-gpio-packages/01-run.sh"

# 4. 00-networking-packages
install_packages_from_file "./00-networking-packages/00-packages"
run_script_in_chroot "./00-networking-packages/01-run.sh"

# 5. 00-webserver-packages
install_packages_from_file "./00-webserver-packages/00-packages"
run_script_in_chroot "./00-webserver-packages/01-run.sh"

# 6. 00-install-packages (Standardname, den Sie auch als Unterordner nutzen)
# Beachten Sie, dass der Standard-pi-gen-Mechanismus _eine_ 00-packages Datei
# direkt in stage_zero0 erwarten würde. Wenn Sie diese Struktur verwenden,
# stellen Sie sicher, dass keine andere 00-packages Datei in stage_zero0 liegt,
# die parallel vom pi-gen-Kernsystem verarbeitet werden könnte.
install_packages_from_file "./00-install-packages/00-packages"
run_script_in_chroot "./00-install-packages/01-run.sh"


echo "INFO: Finished processing custom stage_zero0 sub-sections."