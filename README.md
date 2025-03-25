# odcey
Command-line tool for .odc format, used by BlackBox Component Builder
Provides converting to plain UTF-8 text.

## Usage
    odcey text  [input [output]] { options }
    odcey git   [dir]
    odcey mc

Command 'text' prints text content of .odc; empty arguments for standard IO

    -commander-to <str>  allows in output replacing DevCommanders.StdView by the argument
    -skip-embedded-view  skips recursive writing of embedded views
    -skip-comment        skips (* Oberon comments *)
    -input-windows1251   set input charset Windows-1251 instead of Latin-1
    -tab <str>           set tabulation replacement

Command 'git' embeds odcey to git repo as text converter, what equal to commands:

    echo '*.odc diff=cp' >> .git/info/attributes
    echo '[diff "cp"]
    	binary = true
    	textconv = odcey text <' >> .git/config

Command 'mc' embeds odcey to the Midnight Commander configuration as a text converter

### Midnight Commander (old versions) integration
Add to ~/.config/mc/mc.ext

    #odc BlackBox Component Builder container document
    shell/.odc
    View=%view{ascii} odcey text < %f

## Install
    # Add deb-repo (https://wiki.oberon.org/repo) to the system, then
    /usr/bin/sudo  apt install odcey
    # or
    /usr/bin/sudo snap install odcey
    # or
    brew tap vostok-space/oberon &&
    brew install odcey
    # or
    /usr/bin/sudo npm install --global odcey

## Build
    # install vostok-translator if it still absent through snap
    /usr/bin/sudo snap install vostok --classic --beta && /usr/bin/sudo snap alias vostok ost
    # or through brew
    brew tap vostok-space/oberon && brew install vostok
    # then build
    ost to-bin odcey.Cli odcey -m . -cc 'cc -O1 -s'
