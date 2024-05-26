sudo rm -f /usr/local/bin/java
sudo ln -s ~/.asdf/shims/java /usr/local/bin/java
set -x JAVA_HOME /usr/local
set -x FZF_DEFAULT_COMMAND 'rg --files --hidden --glob "!.git"'

set -x ANDROID_HOME $HOME/work/android
set -x PATH $PATH $ANDROID_HOME/cmdline-tools/bin
set -x CHROME_EXECUTABLE /mnt/c/Program\ Files/Google/Chrome/Application/chrome.exe

set -x BROWSER "/mnt/c/Users/yusuk/AppData/Local/Programs/Opera GX/launcher.exe"
