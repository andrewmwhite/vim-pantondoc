" vim: set fdm=marker: 

" File: pantondoc.vim
" Description: pandoc support for vim
" Author: Felipe Morales

" Should we load? {{{1
if exists("g:pandoc#loaded") && g:pandoc#loaded || &cp
	finish
endif
let g:pandoc#loaded = 1
" }}}1

" Globals: {{{1

" we use this to configure to what filetypes we attach to
let g:pandoc_extensions_table = {
			\"extra": ["text", "txt"],
			\"html": ["html", "htm"],
			\"json" : ["json"],
			\"latex": ["latex", "tex", "ltx"],
			\"markdown" : ["markdown", "mkd", "md", "pandoc", "pdk", "pd", "pdc"],
			\"native" : ["hs"],
			\"rst" : ["rst"],
			\"textile": ["textile"] }
" }}}1

" Defaults: {{{1

" Modules: {{{2
" Enabled modules {{{3
if !exists("g:pandoc#modules#enabled")
	let g:pandoc#modules#enabled = [
				\"bibliographies",
				\"completion",
				\"command",
				\"folding",
				\"formatting",
				\"menu",
				\"metadata",
				\"keyboard" ,
				\"toc"	]
endif

" Auxiliary module blacklist. {{{3
if !exists("g:pandoc#modules#disabled")
    let g:pandoc#modules#disabled = []
endif
if v:version < 704
    let s:module_disabled = 0
    for incompatible_module in ["bibliographies", "command"]
	" user might have disabled them himself, check that
	if index(g:pandoc#modules#disabled, incompatible_module) == -1
	    let g:pandoc#modules#disabled = add(g:pandoc#modules#disabled, incompatible_module)
	    let s:module_disabled = 1
	endif
    endfor
    " only message the user if we have extended g:pandoc#modules#disabled
    " automatically
    if s:module_disabled == 1 
	echomsg "pantondoc: 'bibliographies' and 'command' modules require vim >= 7.4 and have been disabled."
    endif
endif
"}}}
" Filetypes: {{{2
"Markups to handle {{{3
if !exists("g:pandoc#filetypes#handled")
	let g:pandoc#filetypes#handled = [
				\"markdown",
				\"rst",
				\"textile"]
endif
"}}}
" Use pandoc extensions to markdown for all markdown files {{{3
if !exists("g:pandoc#filetypes#pandoc_markdown")
	let g:pandoc#filetypes#pandoc_markdown = 1
endif
"}}}
"}}}1
 
" Autocommands: {{{1
" We must do this here instead of ftdetect because we need to be able to use
" the value of g:pandoc#filetypes#handled and
" g:pandoc#filetypes#pandoc_markdown

" augroup pandoc {{{2
" this sets the filetype for pandoc files
augroup pandoc
    au BufNewFile,BufRead *.pandoc,*.pdk,*.pd,*.pdc set filetype=pandoc
    if g:pandoc#filetypes#pandoc_markdown == 1
	au BufNewFile,BufRead *.markdown,*.mkd,*.md set filetype=pandoc
    endif
augroup END
"}}}
" augroup pantondoc {{{2
" this loads the pantondoc functionality for configured extensions 
augroup pantondoc
    let s:exts = []
    for ext in g:pandoc#filetypes#handled
	call extend(s:exts, map(g:pandoc_extensions_table[ext], '"*." . v:val'))
    endfor
    execute 'au BufRead,BufNewFile '.join(s:exts, ",").' runtime ftplugin/pantondoc.vim'
augroup END
"}}}
" }}}1
