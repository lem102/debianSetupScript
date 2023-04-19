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

clone_emacs_config () {
    su $username
    pushd $home
    GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no" git clone git@github.com:lem102/.emacs.d.git --depth 1
    popd
    su root
    chown -R $username $home/.emacs.d
}

refresh_emacs_packages () {
    su $username -c "emacs -q --batch --eval \"(progn (require 'package) (package-quickstart-refresh) (package-refresh-contents) (package-install 'exwm))\""
}

setup_exwm () {
    mkdir -p /usr/share/xsessions
    echo "[Desktop Entry]
Name=EXWM
Exec=emacs
Type=Application" > /usr/share/xsessions/exwm.desktop

    echo "exec emacs" >> $home/.xinitrc

    echo "xinit -- vt01" >> $home/.profile

    mkdir -p $home/.emacs.d
    echo "(require 'exwm)
(require 'exwm-config)
(exwm-config-example)" > $home/.emacs.d/environment.el
}

setup_dotnet () {
    su $username -c "dotnet tool install --global csharp-ls"
    echo "PATH=\"/home/$username/.dotnet/tools:$PATH\"" | tee -a /etc/environment
}

setup_apt () {
    configure_apt
    install_apt_packages
}

configure_apt () {
    sed -Ei 's/^# deb-src /deb-src /' /etc/apt/sources.list
    microsoft_package_repository
    docker_package_repository
    apt update
}

microsoft_package_repository () {
    wget https://packages.microsoft.com/config/debian/11/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
    dpkg -i packages-microsoft-prod.deb
    rm packages-microsoft-prod.deb
}

docker_package_repository () {
    apt update
    apt-get install -y \
         curl
    
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
        "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null

}

install_apt_packages () {
    apt install -y \
        build-essential \
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
        curl \
        git \
        zlib1g-dev \
        libgccjit-10-dev \
        dotnet-sdk-6.0 \
        dotnet-sdk-7.0 \
        fonts-noto-color-emoji \
        xinit \
        firefox-esr \
        webext-ublock-origin-firefox \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    apt build-dep emacs
}

user

setup_apt

build_emacs

setup_dotnet

ssh_key

clone_emacs_config

refresh_emacs_packages

setup_exwm

chown -R $username $home

reboot

