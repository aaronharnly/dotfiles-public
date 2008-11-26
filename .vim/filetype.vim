" prolog files
if exists("did_load_filetypes")
  finish
endif

augroup filetypedetect
  au! BufRead,BufNewFile *.pro         setfiletype prolog
augroup END

