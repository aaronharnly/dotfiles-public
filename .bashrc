#
# Aaron's .bashrc
#
source "$HOME/.bash-functions.sh"
source_if "$HOME/.bashrc.private"

#
# ==================== ENV var setup ====================
#
#  The meat of the bashrc: set up all those env vars
#   for all those special things.
#

function setup_env_vars()
{
   set_env_vars_basic
   set_env_vars_colors
   set_env_vars_general
   set_env_vars_apps
   set_env_vars_projects
   set_env_vars_private
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

function set_env_vars_colors()
{
  export TERM_BLACK=$(tput setaf 0)
  export TERM_RED=$(tput setaf 1)
  export TERM_GREEN=$(tput setaf 2)
  export TERM_YELLOW=$(tput setaf 3)
  export TERM_BLUE=$(tput setaf 4)
  export TERM_PURPLE=$(tput setaf 5)
  export TERM_CYAN=$(tput setaf 6)
  export TERM_WHITE=$(tput setaf 7)
  export TERM_RESET=$(tput sgr0)
  export TERM_BOLD=$(tput smso)
  export TERM_BOLD_END=$(tput rmso)
}

function set_env_vars_general()
{
   #
   # ---------------- General ENV variables ---------------------
   #
   if [ "$OS" = "Darwin" ]; then
   	export EDITOR="mate_wait"
   else
   	export EDITOR="vim"
   fi
   export EMAIL="aaron@cs.columbia.edu"
   export PAGER="less"
   export LANG="en_US.UTF-8"
   export LC_CTYPE="en_US.UTF-8"

   # X11
   if [ -z $DISPLAY ]; then
   	export DISPLAY=:0.0
   fi

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

   # Location-specific settings
   if [ ! -z "$LOCATION" -a "$LOCATION" = "Microsoft" ]; then
      # curl
      export ALL_PROXY="http://itgproxy.redmond.corp.microsoft.com:80"
      # ssh
      cp "$HOME/.ssh/config.microsoft" "$HOME/.ssh/config"
   else
      # curl
      unset http_proxy
      # ssh
      cp "$HOME/.ssh/config.default" "$HOME/.ssh/config"
   fi

   #
   # ---------------- General Paths ---------------------
   #
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
   # Fink
   if [ -f /sw/bin/init.sh ]; then
   	. /sw/bin/init.sh
   fi

   # External apps
   path_prepend "$HOME/external-software/crossplatform/bin"
   path_prepend "$HOME/external-software/$PLATFORM/bin"

   # My own scripts and such
   path_prepend "$HOME/software/crossplatform/bin"
   path_prepend "$HOME/software/$PLATFORM/bin"

   # Private scripts and such
   path_prepend "$HOME/private-software/crossplatform/bin"
   path_prepend "$HOME/private-software/$PLATFORM/bin"

	# Temporary file path
	path_set "/tmp" TMP
	path_set "$HOME/tmp" TMP
}

function set_env_vars_apps()
{
   #
   # ---------------- Application-specific vars ---------------------
   #
   #  maintained in roughly alphabetic order by appname

   # Gnu coreutils
   if [ ! -z $(which dircolors) ]; then
	   local dircolors_ver=$(dircolors --version | grep dircolors)
	   if [ $(echo $dircolors_ver | grep '6.' | wc -l) = "1" ]; then
	   	if [ -f "$HOME/.dircolors" ]; then
		   eval `dircolors "$HOME/.dircolors"`
		fi
	   fi
   fi

   # GCC
   path_prepend "$HOME/external-software/$PLATFORM/lib" LD_LIBRARY_PATH	

   # Less	
   export LESSCHARSET="utf-8"

   # Lynx	
   path_set "$HOME/software/crossplatform/etc/lynx.cfg" LYNX_CFG	

   # Java
	unset CLASSPATH
   path_set "/usr/local/java/java1.5" JAVA_HOME
   path_set "$HOME/external-software/$PLATFORM/stow/jdk" JAVA_HOME
   path_set "$HOME/external-software/$PLATFORM/stow/jdk1.6.0_04" JAVA_HOME
   path_set "/usr/local/java" JAVA_HOME
   path_prepend "/usr/local/java/bin"
   path_prepend "/usr/local/java/java1.5/bin"
   export JAVA_OPTS="-Xmx1024m"
	

   # MySQL
   path_append "/usr/local/mysql/bin"

   # Perl
	unset PERL5LIB
   path_append "$HOME/software/crossplatform/lib/site_perl" PERL5LIB
   path_append "$HOME/external-software/crossplatform/lib/site_perl" PERL5LIB
	export PERL_UNICODE="SDA"

   # Python
   path_append "$HOME/external-software/crossplatform/common/etc/python" 

	# R
	path_set "/Library/Frameworks/R.framework/Versions/Current/Resources" R_HOME

   # Ruby
#   unset RUBYLIB
   export RUBYOPT=rubygems
   #path_append "$HOME/software/crossplatform/lib/ruby" RUBYLIB
   #path_prepend "$HOME/external-software/$PLATFORM/stow/ruby-1.8.6-p110/bin"

   # Scala
   path_set "$HOME/external-software/crossplatform/stow/scala-2.7.1.final" SCALA_HOME
   path_append "$SCALA_HOME/lib/scala-library.jar" CLASSPATH
	export ANT_OPTS="$ANT_OPTS -Dscala.home=$SCALA_HOME"
	# some particular items for classpath
	local mvn_repo="$HOME/.m2/repository"
	path_append "$mvn_repo/org/scalacheck/scalacheck/1.2/scalacheck-1.2.jar" CLASSPATH
	path_append "$mvn_repo/org/specs/specs/1.2.5/specs-1.2.5.jar" CLASSPATH
	path_append "$mvn_repo/junit/junit/4.4/junit-4.4.jar" CLASSPATH
   # Subversion
   path_append "/usr/local/subversion/bin"

	# Tetex
	path_append "/usr/local/texlive/2007/bin/i386-darwin/"
   
   # XCode
   path_append "/Developer/Tools"
   path_append "/Volumes/MacBookPro/3rdPartyStuff/Developer-10.5/Tools"

   # -----------------------------------


}

function append_build_paths_in()
{
	local path="$1"
	# Ant build paths
   if [ -f "$path/build.xml" -a -d "$path/build" ]; then
     path_append "$proj/build" CLASSPATH
   fi

	# Maven build paths
   if [ -f "$path/pom.xml" -a -d "$path/target/classes" ]; then
     path_append "$proj/target/classes" CLASSPATH
   fi

	# Jars in "lib" folder
	if [ -d "$path/lib" ]; then
		for lib in $(ls "$path/lib"/*.jar 2>/dev/null)
		do
			path_append "$lib" CLASSPATH
		done
	fi
}

function append_build_paths_in_subdirs_of()
{
	local dir="$1"
	# Loop through the directories in there
	if [ -d "$dir" ]; then
		for proj in $(ls "$dir")
			do
			if [ -d "$proj" ]; then
				append_build_paths_in "$proj"
			fi
		done
	fi
}

function set_env_vars_projects()
{
   ######################### Projects -----------------------
   # initialize the paths of any projects we find 
   PROJECTS_DIR="$HOME/projects"
   if [ -d "$PROJECTS_DIR" ]; then
	   for proj in $(ls "$PROJECTS_DIR")
	   do
			proj_name=$(basename "$proj")
			proj__name_cap=$(echo "$proj_name" | perl -pe 's/\s+//g; s/([a-z])/\u\1/g; s/[^A-Z_]/_/g')
			eval export ${proj__name_cap}_DIR="$PROJECTS_DIR/$proj"
			if [ -d "$PROJECTS_DIR/$proj/data" ]; then
				eval export ${proj__name_cap}_DATA="$PROJECTS_DIR/$proj/data"
			fi
			PROJECT_INIT="$proj/tools/util/project_init.sh"
			source_if "$PROJECT_INIT"
	#			echo "Sourcing $PROJECT_INIT"
	 #  		source "$PROJECT_INIT"
	   done
	fi
#   PROJECT_INIT="$PROJECTS_DIR/enron/subprojects/syntax/tools/util/project_init.sh"
#   if [ -f "$PROJECT_INIT" ]; then
#		echo "Sourcing $PROJECT_INIT"
#   	source "$PROJECT_INIT"
#   fi
   
   ######################### Scala/Java projects -----------------------
   # Add build directories to our classpath
   for parent in "$HOME/git/public" "$HOME/git/private" "$HOME/git/research" "$HOME/projects"
   	do
		append_build_paths_in_subdirs_of "$parent"
   done

   # GALE
   path_set "/proj/gale-safe/system/distill" GALE_HOME
   path_set_if_empty "$HOME/projects/galesys" GALE_HOME

   path_set "$HOME/projects/enron/code-repository" ENRON_DIR
   path_set "$HOME/projects/enron/database-repository" ENRON_DB_DIR
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
	alias ll="ls -lh --color=auto"
	alias l="ls -lh --color=auto"
	alias ls="ls --color=auto"

	# ---- mate ----
	alias mate_wait="mate --wait"
	
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
# ==================== Login shell setup ====================
#


function git_info()
{
  echo $(aaron-git-info 2>/dev/null)
}

function setup_login_shell()
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

   # ----------------- Prompt  -----------------
   # Show 'root' in red
   if [ $UID = 0 ]; then
     TERM_USER_COLOR=${TERM_RED}
   else
     TERM_USER_COLOR=${TERM_GREEN}
   fi
   export PS1="[${TERM_YELLOW}\@ ${TERM_USER_COLOR}\u${TERM_RESET}@\h: \w] $(git_info)\n ★ "
   export PROMPT_COMMAND='PS1="[${TERM_YELLOW}\@ ${TERM_USER_COLOR}\u${TERM_RESET}@\h: \w] $(git_info)\n ★ "'
   export PS2=" | "

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

   # ----------------- Login greeting  -----------------
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
	
   # if we're not already in screen, offer the opportunity
   #  to reattach to detached screens:
   local screen_path=$(which screen)
   if [ ! -z "$screen_path" ]; then
      if [ -z "$RUNNING_SCREEN" ]; then
      	detached_screens=$(screen -list | awk '/Detached/ {print $1}' )
      	if [ ! -z "$detached_screens" ]; then
      		head1="Detached screens available: "
      		head2=" "
      		tail1=" "
      		tail2=" Type 'screen -r <name>' to reattach."
      		display_boxed  --centered "$head1" "$head2" $detached_screens "$tail1" "$tail2"
      	fi
      fi
   fi

}

########################### The actual execution ######################

# ----------------- Env vars  -----------------
# Only change ENV variables if they haven't already,
# but, can force a var change by unsetting this flag variable,
# or by calling the function set_env_vars.
unset BASHRC_CHANGED_ENV_VARS
if [ -z "$BASHRC_CHANGED_ENV_VARS" ]; then
	export BASHRC_CHANGED_ENV_VARS="yes"
   setup_env_vars
	# -------------------------
fi # end of ENV variable changes


# ----------------- Shell customization  -----------------
# Add aliases for all shells:
setup_aliases

# ----------------- Additional files --------------------
source_if "$HOME/.bash_profile"

# do the login stuff only for interactive shells:
if [ ! -z "$PS1" ]; then
   setup_login_shell

	#
	# if a custom bash is available, run that instead
	#
	#  (but only if we're not *already* running that custom shell)
	custom_shell="$HOME/external-software/$PLATFORM/bin/bash"

	if [ -e "$custom_shell" -a "$0" != "$custom_shell" -a -z "$SHOWED_CUSTOM_SHELL_MESSAGE" ]; then
		export SHOWED_CUSTOM_SHELL_MESSAGE="yes"
		echo "Running custom bash shell from $custom_shell"
    # Do host-specific changes
    source_if "$HOME/.bashrc.${HOST}"
		exec "$custom_shell"
	fi
fi

# Do host-specific changes
source_if "$HOME/.bashrc.${HOST}"

