#
# Aaron's bash settings for login shells
#

# ==================== Initialization ====================
# First, set up like we do for non-login interactive shells
source "$HOME/.bashrc"

#
# ==================== Login shell setup ====================
#

function setup_login_shell()
{
  show_connection_message
  show_screen_message
}

function show_connection_message()
{
  # Where are we logged in from?
  if [ "$LOCALNESS" = "local" ]; then
    LOCATION_MESSAGE="locally on $LAUNCHING_APP"
  else
    LOCATION_MESSAGE="via ssh from $SSH_REMOTE_HOST"
  fi

  # print info about the shell environment
  if [ -z "$SHOWED_CONNECTION_INFO" ]; then
    display_boxed --centered "Connected to $HOST $LOCATION_MESSAGE." "Platform is $PLATFORM."
    export SHOWED_CONNECTION_INFO="yes"
  fi
}

function show_screen_message()
{
  # if we're not already in screen, offer the opportunity
  #  to reattach to detached screens:
  local screen_path=$(which screen)
  if [ ! -z "$screen_path" ]; then
    if [ -z "$RUNNING_SCREEN" ]; then
      local detached_screens=$(screen -list | awk '/Detached/ {print $1}' )
      if [ ! -z "$detached_screens" ]; then
        local line_1="Detached screens available: "
        local line_2=" "
        local end_line_1=" "
        local end_line_2=" Type 'screen -r <name>' to reattach."
        display_boxed  --centered "$line_1" "$line_2" $detached_screens "$end_line_1" "$end_line_2"
      fi
    fi
  fi

}

########################### The actual execution ######################
setup_login_shell

# ----------------- Additional files --------------------
# Host-specific login messages
source_if "$HOME/.profile.${HOST}"
