#!/usr/bin/env bash

username="jacob"
home="/home/$username"
bin="$home/bin"
dev="$home/dev"
vagrant_directory="/vagrant"

user () {
    adduser $username
    echo "$username:$PASSWORD" | chpasswd
    usermod -aG sudo $username

    mkdir -p $bin
    mkdir -p $dev

    timedatectl set-timezone Europe/London
}

install_emacs () {
    apt install -y \
        pkg-config \
        libgnutls28-dev \
        libncurses-dev \
        libx11-dev \
        libxpm-dev \
        libjpeg-dev \
        libpng-dev \
        libgif-dev \
        libtiff-dev \
        libgtk2.0-dev \
        libjansson4 \
        libjansson-dev \
        zlib1g-dev \
        libgccjit-10-dev \
        xinit

    apt build-dep -y emacs

    build_emacs
    clone_emacs_config
    refresh_emacs_packages
}

build_emacs () {
    export CC=/usr/bin/gcc-10
    export CXX=/usr/bin/gcc-10

    pushd $bin
    wget https://ftp.gnu.org/gnu/emacs/emacs-28.2.tar.gz
    tar xvfz emacs-28.2.tar.gz
    cd emacs-28.2
    ./autogen.sh
    # ./configure --with-native-compilation
    ./configure
    make -j $(nproc)
    make install
    popd
}

clone_emacs_config () {
    su $username
    pushd $home
    GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no" git clone git@github.com:lem102/.emacs.d.git --depth 1
    popd
    su root
    chown -R $username $home/.emacs.d
}

refresh_emacs_packages () {
    su $username -c "emacs -q --batch --eval \"(progn (require 'package) (package-quickstart-refresh))\""
}

ssh_key () {
    su $username
    mkdir -p $home/.ssh
    pushd $home/.ssh
    ssh-keygen -t ed25519 -C "$EMAIL" -N "" -f id_ed25519
    public_key=$(cat id_ed25519.pub)
    curl -H "Authorization: token $GITHUB_TOKEN" -u "lem102" --data "{\"title\":\"DebianScript\",\"key\":\"$public_key\"}" https://api.github.com/user/keys
    popd
    eval $(ssh-agent -s)
    ssh-add $home/.ssh/id_ed25519
    su root
}

install_dotnet () {
    setup_microsoft_package_repository

    apt install -y \
        dotnet-sdk-6.0 \
        dotnet-sdk-7.0

    su $username -c "dotnet tool install --global csharp-ls"
    echo "PATH=\"/home/$username/.dotnet/tools:$PATH\"" | tee -a /etc/environment
}

setup_microsoft_package_repository () {
    wget https://packages.microsoft.com/config/debian/11/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
    dpkg -i packages-microsoft-prod.deb
    rm packages-microsoft-prod.deb
    apt update
}

setup_apt () {
    configure_apt
    install_general_packages
}

configure_apt () {
    sed -Ei 's/^# deb-src /deb-src /' /etc/apt/sources.list
    apt update
}

install_general_packages () {
    apt install -y \
        build-essential \
        curl \
        git \
        fonts-noto-color-emoji \
        gnupg
}

install_docker () {
    apt install -y \
        ca-certificates

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
        "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt update
    apt install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin
}

install_firefox () {
    apt install -y \
        firefox-esr \
        webext-ublock-origin-firefox
}

install_google_chrome () {
    wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    apt install -y ./google-chrome-stable_current_amd64.deb
    rm google-chrome-stable_current_amd64.deb

    # TODO: figure out how to auto install adblock extension
}

install_icewm () {
    apt install -y \
        lightdm \
        icewm

    # set keyboard layout
    sed -i "s/XKBLAYOUT=\"us\"/XKBLAYOUT=\"gb\"/" /etc/default/keyboard

    # add srvukeys:none to XKBOPTIONS, disabling ctrl alt function keybindings to switch tty
    sed -i "s/XKBOPTIONS=\"ctrl:nocaps,terminate:ctrl_alt_bksp\"/XKBOPTIONS=\"ctrl:nocaps,terminate:ctrl_alt_bksp,srvrkeys:none\"/" /etc/default/keyboard

    mkdir $home/.icewm
    cp -r /usr/share/icewm/* $home/.icewm

    # unbind some keys
    sed -i "s/key \"Alt+Ctrl+t\"/#&/" $home/.icewm/keys
    sed -i "s/# KeyWinMenu=\"Alt+Space\"/KeyWinMenu=\"\"/" $home/.icewm/preferences

    # bind some keys
    echo 'key "Alt+Ctrl+F9" jumpapp emacs' >> $home/.icewm/keys
    echo 'key "Alt+Ctrl+F10" jumpapp google-chrome' >> $home/.icewm/keys
    echo 'key "Alt+Ctrl+F11" jumpapp slack' >> $home/.icewm/keys
    echo 'key "Super+z" /bin/sh -c "maim -s | xclip -selection clipboard -t image/png"' >> $home/.icewm/keys

    # hide stuff on taskbar
    sed -i "s/# TaskBarShowWorkspaces=1/TaskBarShowWorkspaces=0/" $home/.icewm/preferences
    sed -i "s/# TaskBarShowWindowListMenu=1/TaskBarShowWindowListMenu=0/" $home/.icewm/preferences
    sed -i "s/# TaskBarShowShowDesktopButton=1/TaskBarShowShowDesktopButton=0/" $home/.icewm/preferences

    # date and time
    sed -i "s/# TimeFormat=\"%X\"/TimeFormat=\"%A %d %B %H:%M\"/" $home/.icewm/preferences

    # wallpaper
    wget "https://s1.1zoom.me/b5050/782/305258-svetik_1920x1080.jpg" -O $home/wallpaper.jpg
    echo "DesktopBackgroundImage=$home/wallpaper.jpg" >> $home/.icewm/prefoverride

    # set theme
    echo 'Theme="Win95"' >> $home/.icewm/preferences

    # audio
    apt install -y \
        pulseaudio \
        pavucontrol
}

install_nodejs () {
    su $username
    git clone https://github.com/nvm-sh/nvm.git $home/.nvm
    cd $home/.nvm
    git checkout v0.39.3

    echo 'export NVM_DIR="$HOME/.nvm"' >> $home/.bashrc
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm' >> $home/.bashrc
    echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion' >> $home/.bashrc

    su root
}

install_jumpapp () {
    apt install -y \
        debhelper \
        pandoc \
        shunit2 \
        wmctrl

    git clone https://github.com/mkropat/jumpapp.git
    pushd jumpapp
    make deb
    sudo dpkg -i jumpapp*all.deb
    popd
}

setup_screenshots () {
    apt install -y \
        maim \
        xclip
}

install_slack () {
    wget https://downloads.slack-edge.com/releases/linux/4.31.155/prod/x64/slack-desktop-4.31.155-amd64.deb
    apt install -y ./slack-desktop-4.31.155-amd64.deb
}

install_vscode () {
    apt install -y \
        apt-transport-https
    
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
    rm -f packages.microsoft.gpg
    
    apt update
    apt install -y code
}

setup_apt

user

ssh_key

install_docker

install_emacs

install_dotnet

install_google_chrome

install_nodejs

install_icewm

install_jumpapp

setup_screenshots

install_slack

install_vscode

chown -R $username $home

reboot

