"********** * User Interface
:syntax on
colorscheme aaron " set the colorscheme
set showmode " display current mode and partial commands in status line
set showcmd " display current command as I type it
set laststatus=2 " always show status line
set ruler " always show cursor
set number " show line numbers

" command behavior
set history=50 " command-line
set wildmode=list:longest,full " use command-line completion

" misc. UI behavior
set mouse=a " enable mouse
" set nomodeline " don't let files override .vimrc
set modeline
set modelines=5

" *********** Text Formatting - Formats
filetype on " enable filetype detection
filetype indent on
set softtabstop=2
set tabstop=2
set shiftwidth=2
set expandtab
" autocmd FileType perl set smartindent

" *********** Search & Replace
" case-insensitive, unless contain upper-case letters
set ignorecase
set smartcase
set incsearch  " show best match so far
map <F5> :set hls!<bar>set hls?<CR> " F5 clears the search highlighting
set gdefault " assume /g flag by default

" *********** Editing Behaviors
set whichwrap=<,>,h,l,[,] " movement: allow movement keys to wrap between lines
set backspace=indent,eol,start " allow insert-mode to delete whitespace, but not pre-extant text

" ********** Bindings
map <C-o> :split

