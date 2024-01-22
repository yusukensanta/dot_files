sudo rm -f /usr/local/bin/java
sudo ln -s ~/.asdf/shims/java /usr/local/bin/java
set -x JAVA_HOME /usr/local
set -x FZF_DEFAULT_COMMAND 'rg --files --hidden --glob "!.git"'

set -x ANDROID_HOME $HOME/work/android
set -x PATH $PATH $ANDROID_HOME/cmdline-tools/bin
set -x CHROME_EXECUTABLE /mnt/c/Program\ Files/Google/Chrome/Application/chrome.exe

set -x JIRA_API_TOKEN 'ATATT3xFfGF0NcbbOwQE3aJVLNAuWF6z2lrD6WQqZ3qQkv75m9gSzdchpPO_L9T1NJW5RA8RNzv9hnug_UhY366yHDHmLuahk24xSiY-Mr4JPLkqFm69F1JeDNxXTFn_UBMNyUhoCljCtRc5A1SeDIJLKBWuM2c6bbkONSuV1ZxfdRSCMqGi_-s=B342890B'
set -x BROWSER "/mnt/c/Users/yusuk/AppData/Local/Programs/Opera GX/launcher.exe"
