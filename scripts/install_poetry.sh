#!/usr/bin/env bash
# --- Configuration ---
POETRY_BIN_DIR="$HOME/.local/bin"
BASHRC_FILE="$HOME/.bashrc"

echo
echo "3. Installing Poetry using the official installer..."
echo "   (Installing for the current user, *not* using sudo)"

# Use curl to download and pipe directly to python3
# It installs into ~/.local/ by default
if curl -sSL https://install.python-poetry.org | python3 - ; then
    echo "   Poetry installation script finished successfully."
else
    echo "[ERROR] Poetry installation failed. Please check the messages above."
    exit 1
fi


echo
echo "4. Adding Poetry to your PATH in $BASHRC_FILE..."

# Line to add to shell config files
PATH_LINE="export PATH=\"$POETRY_BIN_DIR:\$PATH\""
COMMENT_LINE="# Add Poetry installation to PATH"

if [ -f "$BASHRC_FILE" ]; then
    # Simple check if the directory is mentioned in the file
    if ! grep -q "$POETRY_BIN_DIR" "$BASHRC_FILE"; then
        echo "   -> Adding configuration to $BASHRC_FILE"
        # Append the comment and the export line
        echo -e "\n$COMMENT_LINE" >> "$BASHRC_FILE"
        echo "$PATH_LINE" >> "$BASHRC_FILE"
        echo "   -> Added PATH line."
    else
        echo "   -> PATH configuration for Poetry likely already exists in $BASHRC_FILE. Skipping."
    fi
else
    echo "   -> $BASHRC_FILE not found. The Poetry installer *might* have added the PATH"
    echo "      configuration to another file like ~/.profile."
    echo "      If 'poetry' command doesn't work after restarting the shell,"
    echo "      you may need to manually add this line to your shell startup file:"
    echo "      $PATH_LINE"
fi

echo
echo "-----------------------------------------"
echo " Installation Complete! 🎉"
echo "-----------------------------------------"
echo
echo ">>> MOST IMPORTANT STEP <<<"
echo "To make the 'poetry' command available, you MUST either:"
echo "  1. Log out of your server session and log back in."
echo "  OR"
echo "  2. Run the command: source $BASHRC_FILE"
echo
echo "After doing one of the above, test the installation by typing:"
echo "  poetry --version"
echo
echo "If it shows a version number, you're all set! ❤️"
echo