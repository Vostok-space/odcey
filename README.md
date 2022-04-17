# odcey
Command-line tool for .odc format, used by BlackBox Component Builder
Provides converting to plain text.

## Usage
    odcey text  [input [output]] { options }
    odcey git   [dir]

Command 'text' prints text content of .odc; empty arguments for standard IO

    -commander-to <str>  allows in output replacing DevCommanders.StdView by the argument
    -skip-embedded-view  skips recursive writing of embedded views
    -skip-comment        skips (* Oberon comments *)
    -tab <str>           set tabulation replacement

Command 'git' embeds to git repo as text converter, what equal to commands:

    echo '*.odc diff=cp' >> .git/info/attributes
    echo '[diff "cp"]' >> .git/config
    echo '	binary = true' >> .git/config
    echo '	textconv = odcey text <' >> .git/config

## Install
    /usr/bin/sudo snap install odcey
    # or
    brew tap vostok-space/oberon &&
    brew install odcey

## Build

    # install vostok-translator if it still absent through snap
    /usr/bin/sudo snap install vostok --classic --beta && /usr/bin/sudo snap alias vostok ost
    # or through brew
    brew tap vostok-space/oberon && brew install vostok
    # then build
    ost to-bin odcey.Cli odcey -m . -cc 'cc -O1 -s'
