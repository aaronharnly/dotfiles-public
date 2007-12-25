#
# Aaron's .bashrc
#
source "$HOME/.bash-functions.sh"

#
# ==================== ENV var setup ====================
#
#  The meat of the bashrc: set up all those env vars
#   for all those special things.
#

function setup_env_vars()
{
   set_env_vars_basic
   set_env_vars_general
   set_env_vars_apps
   set_env_vars_projects
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
   export LAUNCHING_APP="An unknown terminal"
   if [ "$OS" = "Darwin" -a 0 ]; then
   	# find out which app launched this terminal
   	if [ ! -z "$TERM_PROGRAM" ]; then
   		export LAUNCHING_APP="$TERM_PROGRAM"
   	elif [ ! -z "$PATH_FINDER" ]; then
   		export LAUNCHING_APP="Path Finder"
   	else
   	   frontmost_script="$HOME/software/$PLATFORM/applescripts/get_frontmost_application.scpt"
   	   if [ -f "$frontmost_script" ]; then
   	      export LAUNCHING_APP=$(osascript "$frontmost_script")
   	   fi
   	fi
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
   # Generic useful paths -----------------
   path_prepend /usr/X11R6/bin
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
}

function set_env_vars_apps()
{
   #
   # ---------------- Application-specific vars ---------------------
   #
   #  maintained in roughly alphabetic order by appname

   # GCC
   path_prepend "$HOME/external-software/$PLATFORM/lib" LD_LIBRARY_PATH	

   # Less	
   export LESSCHARSET="utf-8"

   # Lynx	
   path_set "$HOME/software/crossplatform/etc/lynx.cfg" LYNX_CFG	

   # Java
   path_set "/usr/local/java/java1.5" JAVA_HOME
   path_prepend "/usr/local/java/java1.5/bin"
   export JAVA_OPTS="-Xmx1024m"

   # MySQL
   path_append "/usr/local/mysql/bin"

   # Perl
   path_append "$HOME/software/crossplatform/lib/site_perl" PERL5LIB
   path_append "$HOME/external-software/crossplatform/lib/site_perl" PERL5LIB

   # Python
   path_append "$HOME/external-software/crossplatform/common/etc/python" 

   # Ruby
   export RUBYOPT=rubygems
   path_append "$HOME/software/crossplatform/lib/ruby" RUBYLIB
   path_prepend "$HOME/external-software/$PLATFORM/stow/ruby-1.8.6-p110/bin"

   # Scala
   export SCALA_HOME="$HOME/external-software/crossplatform/share/scala"
   path_append "$SCALA_HOME/lib/scala-library.jar" CLASSPATH

   # Subversion
   path_append "/usr/local/subversion/bin"
   
   # XCode
   path_append "/Developer/Tools"
   path_append "/Volumes/MacBookPro/3rdPartyStuff/Developer-10.5/Tools"

   # -----------------------------------


}

function set_env_vars_projects()
{
   ######################### Projects -----------------------
   # initialize the paths of any projects we find 
   PROJECTS_DIR="$HOME/projects"
   for proj in "$PROJECTS_DIR"/*
   do
   	if [ -f "$proj/tools/util/project_init.sh" ]; then
   		PROJECT_INIT="$proj/tools/util/project_init.sh"
   		source "$PROJECT_INIT"
   	fi
   done
   PROJECT_INIT="$PROJECTS_DIR/enron/subprojects/syntax/tools/util/project_init.sh"
   if [ -f "$PROJECT_INIT" ]; then
   	source "$PROJECT_INIT"
   fi
   
   ######################### Scala/Java projects -----------------------
   # Add build directories to our classpath
   for proj in "$HOME/git/public"/* "$HOME/git/private"/* "$HOME/git/research"/*
   do
      if [ -f "$proj/build.xml" -a -d "$proj/build" ]; then
        path_append "$proj/build" CLASSPATH
      fi
   done

   # GALE
   path_set "/proj/gale-safe/system/distill" GALE_HOME
   path_set_if_empty "$HOME/projects/galesys" GALE_HOME
}

#
# ==================== Login shell setup ====================
#


function setup_login_shell()
{
   # ----------------- Shell options ------------------
   shopt -s histappend

   # ----------------- Aliases --------------------------
   #
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

   # ----- less ------
   alias more="less"

   # ----- ls -----
   if [ "$OS" = "Linux" ]; then
   	alias ls="ls --color=never"
   	alias ll="ls -lh --color=never"
   else
   	alias ll="ls -lh"
   fi
   if [ "$OS" = "Darwin" ]; then
   	# Spotlight-savvy ls!
   	myls="$HOME/software/$PLATFORM/bin/spotlightls"
   	if [ -f "$myls" ]; then
   		alias ls="$myls"
   	fi
   fi
   
   # ---- mate ----
#   alias mate_wait="mate --wait"

   # ---- rsync ---
   alias scpr="rsync --partial --progress --rsh=ssh --archive"

   # ----- Scala -----
   alias rscala="rlwrap scala"

   # ----- ssh -----
   if [ "$OS" = "Darwin" ]; then
   	alias ssh="ssh -Y"
   else
   	alias ssh="ssh -X"
   fi
      
   # ---- top ----
   alias topu="top -ocpu -R -F -s 2 -n30"
      
   # ---- xstow ---
   alias xstow="xstow -v 3 -ire 'entries|README.txt|format|.svn-base|.svn-work|empty-file'"

   # ----------------- Termcap  -----------------
   if [ "$TERM" != "screen" ]; then
	   export TERM="xterm-color"
   fi
   # export TERMINFO="$HOME/.terminfo"
   # export TERMCAP="$HOME/software/crossplatform/etc/termcap"

   # ----------------- Prompt  -----------------
   # decide whether to include xterm window title code
   if [ "$TERM" = "xterm" -o "$TERM" = "xterm-color" -o "$TERM" = "ansi" ]; then
   	# include xterm window title code
   	XTERM_TITLE="\[\033]0;\h: \w\007\]"
   else
   	XTERM_TITLE=""
   fi
   if [ $UID = 0 ]; then
   	# this makes a prompt of the form: [root@hostname: ~] 
   	#   with 'root' in red
   	export PS1="${XTERM_TITLE}[\[\e[1;33m\]\@ \e[0;31m\]\u\[\e[0m\]@\h: \W] "
   else
   	# this makes a prompt of the form: [user@hostname: ~] 
   	#  with 'user' in green
   	export PS1="${XTERM_TITLE}[\[\e[1;33m\]\@ \e[0;32m\]\u\[\e[0m\]@\h: \W] "
   fi
   if [ "$TERM" = "screen" ]; then
   	# if we're within a 'screen' environment, then update the window name
   	# 	with the name of the current dir
   	#export PROMPT_COMMAND='echo -ne "\033k$(basename $PWD)\033\134"'
#   	export PROMPT_COMMAND='echo -ne "\033k$(basename $PWD)\033\134\033]0..2;$PWD"'
	export PROMPT_COMMAND="$PROMPT_COMMAND"
   fi
   if [ ! -z "$LAUNCHING_APP" ]; then
   	if [ "$LAUNCHING_APP" = "Path Finder" ]; then
   		export PROMPT_COMMAND="if [ -z "$DONT_RUN_PFF" ]; then pff; fi; unset DONT_RUN_PFF"
   	fi
   fi

   # ----------------- Command completion  -----------------
   if [ -f "$HOME/.bash_completion" ]; then
   	source "$HOME/.bash_completion"
   fi
   if [ -f "$HOME/.bash_completion_svn" ]; then
   	source "$HOME/.bash_completion_svn"
   fi
   if [ -f "$HOME/external-software/crossplatform/etc/bash_completion_svk" ]; then
   	source "$HOME/external-software/crossplatform/etc/bash_completion_svk"
   fi
   # ignore .svn directories for path completion
   export FIGNORE=.svn 
   # after the command completion, reset manpath
   unset MANPATH

   # ----------------- Login greeting  -----------------
   # notice a few things about our environment
   SSH_COMBO="$SSH_CONNECTION$SSH_CLIENT"
   if [ ! -z "$SSH_COMBO" ]; then
   	SSH_REMOTE_IP="${SSH_COMBO%% *}"
   	SSH_REMOTE_HOST=$(host $SSH_REMOTE_IP | awk '/name pointer/ {print $5} /NXDOMAIN/ {print "$SSH_REMOTE_IP" }')   	
   	if [ -z "$SSH_REMOTE_HOST" ]; then
   	  SSH_REMOTE_HOST="$SSH_REMOTE_IP" 
	   fi
   	LOCALNESS="via ssh from $SSH_REMOTE_HOST"
   else
   	LOCALNESS="locally on $LAUNCHING_APP"
   fi

   # print info about the shell environment
   if [ -z "$SHOWED_CONNECTION_INFO" ]; then
   	display_boxed --centered "Connected to $HOST $LOCALNESS." "Platform is $PLATFORM."
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
# do this login stuff only for interactive shells:
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
		exec "$custom_shell"
	fi
fi

