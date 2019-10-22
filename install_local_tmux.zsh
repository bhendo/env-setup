#!/bin/zsh

set -e

TMUX_VERSION=2.9a
LIBEVENT_VERSION=2.1.11-stable
NCURSES_VERSION=6.1

INSTALL_DIR=${ZDOTDIR:-$HOME}/.local
TEMP_DIR=${ZDOTDIR:-$HOME}/tmp

mkdir -p $INSTALL_DIR $TEMP_DIR
cd $TEMP_DIR

curl -sL --proto-redir --all,https https://github.com/tmux/tmux/releases/download/${TMUX_VERSION}/tmux-${TMUX_VERSION}.tar.gz > tmux-${TMUX_VERSION}.tar.gz
curl -sL --proto-redir --all,https https://github.com/libevent/libevent/releases/download/release-${LIBEVENT_VERSION}/libevent-${LIBEVENT_VERSION}.tar.gz > libevent-${LIBEVENT_VERSION}.tar.gz
curl -sL --proto-redir --all,https https://github.com/mirror/ncurses/archive/v${NCURSES_VERSION}.tar.gz > ncurses-${NCURSES_VERSION}.tar.gz

tar xvzf libevent-${LIBEVENT_VERSION}.tar.gz
cd libevent-${LIBEVENT_VERSION}
./configure --prefix=$INSTALL_DIR --disable-shared
make
make install
cd ..

if [[ $(fs --version) =~ "afs" ]] && fs whereis "$INSTALL_DIR" ; then
    NCURSES_OPTION=" --enable-symlinks"
else
    NCURSES_OPTION=""
fi

tar xvzf ncurses-${NCURSES_VERSION}.tar.gz
cd ncurses-${NCURSES_VERSION}
./configure --prefix=$INSTALL_DIR $NCURSES_OPTION
make
make install
cd ..

tar xvzf tmux-${TMUX_VERSION}.tar.gz
cd tmux-${TMUX_VERSION}
./configure CFLAGS="-I$INSTALL_DIR/include -I$INSTALL_DIR/include/ncurses" LDFLAGS="-L$INSTALL_DIR/lib -L$INSTALL_DIR/include/ncurses -L$INSTALL_DIR/include"
CPPFLAGS="-I$INSTALL_DIR/include -I$INSTALL_DIR/include/ncurses" LDFLAGS="-static -L$INSTALL_DIR/include -L$INSTALL_DIR/include/ncurses -L$INSTALL_DIR/lib" make
cp tmux $INSTALL_DIR/bin
cd ..

rm -rf $TEMP_DIR

echo "$INSTALL_DIR/bin/tmux is now available. You can optionally add $INSTALL_DIR/bin to your PATH."
