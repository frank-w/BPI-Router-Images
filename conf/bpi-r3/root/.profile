# ~/.profile: executed by Bourne-compatible login shells.

export TERM=xterm-256color

if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi

mesg n 2> /dev/null || true
