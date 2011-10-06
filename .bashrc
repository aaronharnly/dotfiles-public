#
# Aaron's bash settings for interactive shells
#

# ==================== Initialization ====================
# First, read some useful bash functions
source "$HOME/.bash-functions.sh"

function setup_interactive_shell()
{
  setup_env_vars
  setup_aliases
  setup_terminal
}

#
# ==================== Environment variables ====================
#

#
# Master function for env vars
#
function setup_env_vars()
{
  setup_whereami
  setup_path
  setup_general_prefs
  setup_app_prefs
  setup_projects
  setup_aboutme
}

# Returns the best guess of the terminal program.
# requires $TERM to be in its original state.
function get_launching_app()
{
  if [ ! -z "$TERM_PROGRAM" ]; then
    echo $TERM_PROGRAM
  elif [ ! -z "$PATH_FINDER" ]; then
    echo "Path Finder"
  elif [ ! -z "$TERM" -a "$TERM" = "terminator" ]; then
    echo "Terminator"
  elif [ ! -z "$COLORTERM" -a "$COLORTERM" = "gnome-terminal" ]; then
    echo "Gnome Terminal"
  elif [ "$OS" = "Darwin" ]; then
    frontmost_script="$HOME/software/$PLATFORM/applescripts/get_frontmost_application.scpt"
    if [ -f "$frontmost_script" ]; then
      echo $(osascript "$frontmost_script")
    else
      echo "an unknown Mac terminal"
    fi
  else
    echo "an unknown terminal"
  fi
}

#
# Environment variables that tell us about the machine we're on
#
function setup_whereami()
{
  # Platform and host
  export PLATFORM=$(uname -s)-$(uname -m | sed 's/ /_/g')
  export OS=$(uname -s)
  export HOST_LONG=$(hostname)
  export HOST_SHORT=$(hostname | awk -F\. '{print $1}')
  export HOST="$HOST_SHORT"
  
  # Terminal application
  # What terminal are we under?
  export LAUNCHING_TERM="$TERM"
  export LAUNCHING_APP=$(get_launching_app)

  # Are we logged in locally, or over ssh?
  SSH_COMBO="$SSH_CONNECTION$SSH_CLIENT"
  if [ -z "$SSH_COMBO" ]; then
   export LOCALNESS="local"
  else
   SSH_REMOTE_IP="${SSH_COMBO%% *}"
   SSH_REMOTE_HOST=$(host $SSH_REMOTE_IP 2>/dev/null | awk '/name pointer/ {print $5} /NXDOMAIN/ {print "$SSH_REMOTE_IP" }')
   if [ -z "$SSH_REMOTE_HOST" ]; then
     export SSH_REMOTE_HOST="$SSH_REMOTE_IP" 
   fi
   export LOCALNESS="remote"
  fi

  # In Mac OS X, what network location is set?
  if [ -f "/usr/sbin/scselect" ]; then
    export LOCATION=$(/usr/sbin/scselect 2>&1 | perl -ne 'if (m/^\s+\*\s+(\S+)\s+\((.+)\)$/) { print "$2\n"; }')
  fi
}

#
# Setting up the generic PATH
#
# Note that we prepend each time -- so the last path listed will
# be used first. 
#
# Thus we start with the general system paths, and then go to
# increasingly specialized paths where we might place custom versions
# of applications.
function setup_path()
{
  # Reset path --------------
  # except not on Windows
  if [ "$OS" != "CYGWIN_NT-5.1" ]; then
    unset PATH
  fi
  
  # Generic useful paths -----------------
  path_prepend /bin
  path_prepend /sbin
  path_prepend /usr/bin
  path_prepend /usr/sbin
  path_prepend /usr/X11R6/bin
  path_prepend /usr/X11/bin
  path_prepend /usr/local/bin
  path_prepend /usr/local/bin/perl/bin
  path_prepend /usr/ucb
  path_prepend /usr/local/gnu/bin
  path_prepend /opt/default/bin

  # darwinports
  path_prepend /opt/local/bin 
  path_prepend /opt/local/sbin

  # Fink
  source_if "/sw/bin/init.sh"

  # Personal versions of applications
  path_prepend "$HOME/external-software/crossplatform/bin"
  path_prepend "$HOME/external-software/$PLATFORM/bin"

  # Custom scripts and utilities
  path_prepend "$HOME/software/crossplatform/bin"
  path_prepend "$HOME/software/$PLATFORM/bin"

  # Private scripts and utilities
  path_prepend "$HOME/private-software/crossplatform/bin"
  path_prepend "$HOME/private-software/$PLATFORM/bin"
}

#
# Environment variables for system-wide preferences
#
function setup_general_prefs()
{
  #
  # ------------ Application selection ------------
  #
  
  export EDITOR="vim"
  export PAGER="less"

  #
  # ------------ Other universal stuff ------------
  #
  export LANG="en_US.UTF-8"
  export LC_CTYPE="en_US.UTF-8"

  # X11
#  if [ -z $DISPLAY ]; then
#   export DISPLAY=:0.0
#  fi

  # Temporary file path; uses $HOME/tmp if it exists
  path_set "/tmp" TMP
  path_set "$HOME/tmp" TMP
}

#
# Environment variables for specific applications
#
# Maintained in alphabetical order by application name
function setup_app_prefs()
{
  # Ant
  path_set "$HOME/external-software/crossplatform/stow/apache-ant-1.7.1" ANT_HOME
  path_prepend "$ANT_HOME/bin"

  # Eclim
  path_set "$HOME/external-software/$PLATFORM/stow/eclipse" ECLIM_ECLIPSE_HOME

  # GCC
  path_prepend "$HOME/external-software/$PLATFORM/lib" LD_LIBRARY_PATH  

  # Gnu coreutils
  if [ ! -z $(which dircolors) ]; then
    local dircolors_ver=$(dircolors --version | grep dircolors)
    if [ $(echo $dircolors_ver | grep '6.' | wc -l) = "1" ]; then
      if [ -f "$HOME/.dircolors" ]; then
        eval `dircolors "$HOME/.dircolors"`
      fi
    fi
  fi

  # Google depot_tools
  path_append "$HOME/external-src/depot_tools"

  # IDEA
  path_set "/usr/lib/jvm/java-6-openjdk" IDEA_JDK

  # Java
  unset CLASSPATH
  path_set "/usr/local/java/java1.5" JAVA_HOME
  path_set "$HOME/external-software/$PLATFORM/stow/jdk" JAVA_HOME
  path_set "$HOME/external-software/$PLATFORM/stow/jdk1.6.0_04" JAVA_HOME
  path_set "/usr/local/java" JAVA_HOME
  path_prepend "/usr/local/java/bin"
  path_prepend "/usr/local/java/java1.5/bin"
  export JAVA_OPTS="-Xmx1024m"

  # Jython
  path_append "$HOME/external-software/crossplatform/stow/jython-2.5.1/bin"

  # Less  
  export LESSCHARSET="utf-8"

  # Lynx  
  path_set "$HOME/software/crossplatform/etc/lynx.cfg" LYNX_CFG  

  # MacVim
  path_append "$HOME/external-software/$PLATFORM/stow/macvim/bin"
  path_set "/Applications/3rdPartyApplications/Develop" VIM_APP_DIR

  # MySQL
  path_append "/usr/local/mysql/bin"

  # Perl
  unset PERL5LIB
  path_append "$HOME/software/crossplatform/lib/site_perl" PERL5LIB
  path_append "$HOME/external-software/crossplatform/lib/site_perl" PERL5LIB
  export PERL_UNICODE="SDA"

  # Postgres
  path_append "/Library/PostgreSQL/8.4/bin"

  # Python
  path_append "/Library/Frameworks/Python.framework/Versions/2.6/bin"
  path_append "$HOME/external-software/crossplatform/common/etc/python" 
  export PYTHONSTARTUP="$HOME/software/crossplatform/etc/python/startup.py"

  # R
  path_set "/Library/Frameworks/R.framework/Versions/Current/Resources" R_HOME

  # Ruby
  # unset RUBYLIB
  export RUBYOPT=rubygems
  #path_append "$HOME/software/crossplatform/lib/ruby" RUBYLIB
  #path_prepend "$HOME/external-software/$PLATFORM/stow/ruby-1.8.6-p110/bin"

  # Scala
  path_set "$HOME/external-software/crossplatform/stow/scala-2.7.5.final" SCALA_HOME
  path_append "$SCALA_HOME/lib/scala-library.jar" CLASSPATH
  export ANT_OPTS="$ANT_OPTS -Dscala.home=$SCALA_HOME"
  # some particular items for classpath
  local mvn_repo="$HOME/.m2/repository"
#  path_append "$mvn_repo/org/scalacheck/scalacheck/1.2/scalacheck-1.2.jar" CLASSPATH
#  path_append "$mvn_repo/org/specs/specs/1.2.5/specs-1.2.5.jar" CLASSPATH
#  path_append "$mvn_repo/junit/junit/4.4/junit-4.4.jar" CLASSPATH
  # Subversion
  path_append "/usr/local/subversion/bin"

  # Tetex
  path_append "/usr/local/texlive/2007/bin/i386-darwin/"

  # XCode
  path_append "/Developer/Tools"
  path_append "/Volumes/MacBookPro/3rdPartyStuff/Developer-10.5/Tools"
}

#
# Environment variables that tell the system who I am
#
function setup_aboutme()
{
  export EMAIL="aaron@harnly.net"
}

#
# Environment variables for projects
#
function setup_projects()
{
  ######################### Projects -----------------------
  # initialize the paths of any projects we find 
  PROJECTS_DIR="$HOME/projects"
  if [ -d "$PROJECTS_DIR" ]; then
    for proj in $(ls "$PROJECTS_DIR")
    do
      proj_name=$(basename "$proj")
      proj_name__cap=$(echo "$proj_name" | perl -pe 's/\s+//g; s/([a-z])/\u\1/g; s/[^A-Z_]/_/g')
      eval export ${proj_name__cap}_DIR="$PROJECTS_DIR/$proj"
      if [ -d "$PROJECTS_DIR/$proj/data" ]; then
        eval export ${proj__name_cap}_DATA="$PROJECTS_DIR/$proj/data"
      fi
      PROJECT_INIT="$proj/tools/util/project_init.sh"
      source_if "$PROJECT_INIT"
    done
  fi
}

#
# ==================== Aliases ====================
#
function setup_aliases()
{
  # Alphabetical by the underlying command

  # ----- cd -----
  alias cd="mycd" ; export HISTFILE="$HOME/.dir_bash_history$PWD/${USER}_bash_history.txt"
  if [ ! -z "$WD" ]; then
    alias cdg="cd $WD"
  fi
  alias ..="cd .."

  # ----- git ----
  alias pubgit="git --git-dir=$HOME/.public.git --work-tree=$HOME"
  alias prvgit="git --git-dir=$HOME/.private.git --work-tree=$HOME"
  function git_setup()
  {
    git-init
    git-config branch.master.remote origin
    git-config branch.master.merge refs/heads/master

    relative_path=${PWD#$HOME/}
    git-config remote.origin.fetch +refs/heads/*:refs/remotes/origin/*
    git-config remote.origin.url aaron@harnly.net@harnly.net:${relative_path}
  }

  # ----- less ------
  alias more="less"

  # ----- ls -----
  alias ll="ls -lh"
  alias l="ls -lh"
  alias ls="ls"

  # ---- open ----
  if [ "$OS" = "Linux" ]; then
    alias open="gnome-open"
  fi

  # ---- rsync ---
  alias scpr="rsync --partial --progress --rsh=ssh --archive"

  # ----- Scala -----
  alias rscala="rlwrap scala -Xnojline"
  alias rconsole="rlwrap mvn -Djava.awt.headless=true scala:console"
  export SCALA_OPTS="-Xnojline"
  alias scala-latest="$HOME/external-software/crossplatform/stow/scala-latest/bin/scala"
  alias scalac-latest="$HOME/external-software/crossplatform/stow/scala-latest/bin/scalac"
  alias rscala-latest="rlwrap $HOME/external-software/crossplatform/stow/scala-latest/bin/scala -Xnojline"

  function scala_setup()
  {
    dirname=$(basename "$PWD")
    projname=${projname/scala-/}
    mkdir -p "src/main/scala/net/harnly/$projname"
    mkdir -p "src/test/scala/net/harnly/$projname"
    cp "$HOME/software/crossplatform/etc/templates/scala-project/pom.xml" pom.xml
  }


  # ----- ssh -----
  if [ "$OS" = "Darwin" ]; then
    alias ssh="ssh -Y"
  else
    alias ssh="ssh -X"
  fi
  alias renew_authorized_keys="cat \"$HOME/.ssh/keys.pub/\"* > \"$HOME/.ssh/authorized_keys2\""
   
  # ---- top ----
  alias topu="top -ocpu -R -F -s 2 -n30"

  # ---- tree ----
  alias lst="tree -AlCNh --dirsfirst"
   
  # ---- xstow ---
  alias xstow="xstow -v 3 -ire 'entries|README.txt|format|.svn-base|.svn-work|empty-file'"
  
}

#
# ==================== Terminal settings ====================
#

function setup_terminal()
{
  setup_term_colors
  setup_term_settings
  setup_term_prompt
}

#
# Environment variables for terminal colors
#
function setup_term_colors()
{
  OLD_TERM="$TERM"
  if [ -z "$TERM" -o "$TERM" = "dumb" ]; then
    export TERM=xterm-color
  fi
  export TERM_BLACK=$(tput setaf 0)
  export TERM_RED=$(tput setaf 1)
  export TERM_GREEN=$(tput setaf 2)
  export TERM_YELLOW=$(tput setaf 3)
  export TERM_BLUE=$(tput setaf 4)
  export TERM_PURPLE=$(tput setaf 5)
  export TERM_CYAN=$(tput setaf 6)
  export TERM_WHITE=$(tput setaf 7)

  export TERM_BG_BLACK=$(tput setab 0)
  export TERM_BG_RED=$(tput setab 1)
  export TERM_BG_GREEN=$(tput setab 2)
  export TERM_BG_YELLOW=$(tput setab 3)
  export TERM_BG_BLUE=$(tput setab 4)
  export TERM_BG_PURPLE=$(tput setab 5)
  export TERM_BG_CYAN=$(tput setab 6)
  export TERM_BG_WHITE=$(tput setab 7)

  export TERM_BOLD=$(tput smso)
  export TERM_BOLD_END=$(tput rmso)
  export TERM_UNDERLINE=$(tput smul)
  export TERM_UNDERLINE_END=$(tput rmul)
  export TERM_RESET=$(tput sgr0)

  export TERM="$OLD_TERM"
}

#
# Environment variables and scripts controlling some bash settings
#
function setup_term_settings()
{
  # ----------------- Shell options ------------------
  shopt -s histappend

  # ----------------- Termcap  -----------------
  if [ "$TERM" != "screen" ]; then
    if [ "$LAUNCHING_APP" = "terminator" ]; then
      export TERM="ansi"
      export TERMINFO="$HOME/.terminfo"
    else
      export TERM="xterm-color"
    fi
  fi
  # export TERMINFO="$HOME/.terminfo"
  # export TERMCAP="$HOME/software/crossplatform/etc/termcap"

  # ----------------- Command completion  -----------------
  source_if "$HOME/.bash_completion"
  source_if "$HOME/.bash_completion_svn"
  source_if "$HOME/external-software/crossplatform/etc/bash_completion_svk"
  # ignore .svn directories for path completion
  export FIGNORE=.svn 
  # ignore CVS directories for path completion
  export FIGNORE=$FIGNORE:CVS
  # after the command completion, reset manpath
  unset MANPATH
}

#
# Updates the prompt.
#
function update_prompt()
{
  update_location_vars
  update_ps1
}

#
# Updates env vars that should change with location
#
function update_location_vars()
{
  PUBGIT_DIR="$HOME/.public.git"
  # in the home dir, show the status of pubgit
  if [ "$PWD" = "$HOME" ]; then
    export GIT_DIR="$PUBGIT_DIR"
    export GIT_WORK_TREE="$PWD"
  else
    if [ ! -z "$GIT_DIR" -a "$GIT_DIR" = "$PUBGIT_DIR" ]; then
      unset GIT_DIR
      unset GIT_WORK_TREE
    fi
  fi
}

#
# Updates the PS1 prompt
#
function update_ps1()
{
  # Line 1, left side
  local now=$(date +'%I:%M:%S %p')
  local ps_time_clean="[${now}]"
  local ps_time="${TERM_YELLOW}${ps_time_clean}"

  local userpath="${USER}@${HOST_LONG}:${PWD}"
  local ps_userpath_clean="${userpath}"
  local ps_userpath="${TERM_WHITE}${ps_userpath_clean}"

  local prefix=""
  local ps_prefix_clean="${prefix}"
  local ps_prefix="${TERM_BG_COLOR}${TERM_WHITE}${ps_prefix_clean}"

  local line_1_left_clean="${ps_prefix_clean}${ps_time_clean} ${ps_userpath_clean}"
  local line_1_left="${ps_prefix}${ps_time} ${ps_userpath}"

  # Line 1, right side
  local git_info_clean=$(git_info clean)
  local git_info=$(git_info)

  local line_1_right_clean="${git_info_clean}"
  local line_1_right="${git_info}"

  # Line 1, padding
  local total_width=$(tput cols)
  local line_1_left_clean_width=$(length_of_longest_arg "$line_1_left_clean")
  local line_1_right_clean_width=$(length_of_longest_arg "$line_1_right_clean")

  local line_1_content_width=$(( $line_1_left_clean_width + $line_1_right_clean_width ))
  local line_1_padding_width=$(( $total_width - $line_1_content_width ))
  local line_1_padding=$(str_repeat " " $line_1_padding_width)

  # Line 1, combined
  local line_1="${line_1_left}${line_1_padding}${line_1_right}${TERM_RESET}"

  # Line 2
  local line_2="${prefix}"

  # Prompt
  PS1="${line_1}\n${line_2}"
}

#
# Environment variables controlling the prompt
#
function setup_term_prompt()
{
  # ----------------- Prompt  -----------------
  # Show 'root' in red
  if [ $UID = 0 ]; then
    TERM_BG_COLOR=${TERM_BG_RED}
  else
    TERM_BG_COLOR=${TERM_BG_BLUE}
  fi
  
  # A basic prompt
  export PS1="# "
  export PS2="#| "
  
  # before each prompt, run a routine to set the prompt
  export PROMPT_COMMAND='update_prompt'
}

########################### The actual execution ######################

setup_interactive_shell

# ----------------- Additional files --------------------
# Universal private settings
source_if "$HOME/.bashrc.private"
# Host-specific settings
source_if "$HOME/.bashrc.${HOST}"
