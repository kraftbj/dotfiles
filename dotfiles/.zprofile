# The following lines were added by Docker Desktop to add commands to your PATH.
export PATH="$PATH:/Users/kraft/.docker/bin"
# End of Docker Desktop section.

# Kiro CLI pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zprofile.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zprofile.pre.zsh"
export PATH="$HOME/.cargo/bin:$PATH"


# Added by Toolbox App
export PATH="$PATH:/usr/local/bin"
ssh-add --apple-use-keychain ~/.ssh/id_rsa > /dev/null 2>&1

eval "$(/opt/homebrew/bin/brew shellenv)"

# Setting PATH for Python 3.13
# The original version is saved in .zprofile.pysave
PATH="/Library/Frameworks/Python.framework/Versions/3.13/bin:${PATH}"
export PATH

# Kiro CLI post block. Keep at the bottom of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zprofile.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zprofile.post.zsh"
