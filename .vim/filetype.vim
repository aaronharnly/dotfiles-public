" prolog files
if exists("did_load_filetypes")
  finish
endif

augroup filetypedetect
  au! BufRead,BufNewFile *.pro         setfiletype prolog
  au! BufRead,BufNewFile *.json        setfiletype json
augroup END

