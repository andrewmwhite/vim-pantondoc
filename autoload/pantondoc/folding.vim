" vim: foldmethod=marker :
"
" Init: {{{1
function! pantondoc#folding#Init()
    " set up defaults {{{2
    " How to decide fold levels {{{3
    " 'syntax': Use syntax
    " 'relative': Count how many parents the header has
    if !exists("g:pandoc#folding#mode")
	let g:pandoc#folding#mode = 'syntax'
    endif
    " Fold the YAML frontmatter {{{3
    if !exists("g:pandoc#folding#fold_yaml")
	let g:pandoc#folding#fold_yaml = 0
    endif
    " What <div> classes to fold {{{3
    if !exists("g:pandoc#folding#fold_div_classes")
	let g:pandoc#folding#fold_div_classes = ["notes"]
    endif
    if !exists("b:pandoc_folding_basic")
        let b:pandoc_folding_basic = 0
    endif

    " set up folding {{{2
    setlocal foldmethod=expr
    " might help with slowness while typing due to syntax checks
    augroup EnableFastFolds
	au!
	autocmd InsertEnter <buffer> setlocal foldmethod=manual
	autocmd InsertLeave <buffer> setlocal foldmethod=expr
    augroup end   
    setlocal foldexpr=pantondoc#folding#FoldExpr()
    setlocal foldtext=pantondoc#folding#FoldText()
    "}}}
endfunction

" Main foldexpr function, includes support for common stuff. {{{1 
" Delegates to filetype specific functions.
function! pantondoc#folding#FoldExpr()

    let vline = getline(v:lnum)
    " fold YAML headers
    if g:pandoc#folding#fold_yaml == 1
	if vline =~ '\(^---$\|^...$\)' && synIDattr(synID(v:lnum , 1, 1), "name") == "Delimiter"
	    if vline =~ '^---$' && v:lnum == 1
		return ">1"
	    elseif synIDattr(synID(v:lnum - 1, 1, 1), "name") == "yamlkey" 
		return "<1"
	    elseif synIDattr(synID(v:lnum - 1, 1, 1), "name") == "pandocYAMLHeader" 
		return "<1"
	    else 
		return "="
	    endif
	endif
    endif

    " fold divs for special classes
    let div_classes_regex = "\\(".join(g:pandoc#folding#fold_div_classes, "\\|")."\\)"
    if vline =~ "<div class=.".div_classes_regex
	return "a1"
    " the `endfold` attribute must be set, otherwise we can remove folds
    " incorrectly (see issue #32)
    " pandoc ignores this attribute, so this is safe.
    elseif vline =~ '</div endfold>'
	return "s1"
    endif

    " Delegate to filetype specific functions
    if &ft == "markdown" || &ft == "pandoc"
	" vim-pandoc-syntax sets this variable, so we can check if we can use
	" syntax assistance in our foldexpr function
	if exists("g:vim_pandoc_syntax_exists") && b:pandoc_folding_basic != 1
	    return pantondoc#folding#MarkdownLevelSA()
	" otherwise, we use a simple, but less featureful foldexpr
	else
	    return pantondoc#folding#MarkdownLevelBasic()
	endif
    elseif &ft == "textile"
	return pantondoc#folding#TextileLevel()
    endif

endfunction

" Main foldtext function. Like ...FoldExpr() {{{1
function! pantondoc#folding#FoldText()
    " first line of the fold
    let f_line = getline(v:foldstart)
    " second line of the fold
    let n_line = getline(v:foldstart + 1)
    " count of lines in the fold
    let line_count = v:foldend - v:foldstart + 1
    let line_count_text = " / " . line_count . " lines / "

    if n_line =~ 'title\s*:'
	return v:folddashes . " [yaml] " . matchstr(n_line, '\(title\s*:\s*\)\@<=\S.*') . line_count_text
    endif
    if f_line =~ "fold-begin"
	return v:folddashes . " [custom] " . matchstr(f_line, '\(<!-- \)\@<=.*\( fold-begin -->\)\@=') . line_count_text
    endif
    if f_line =~ "<div class="
	return v:folddashes . " [". matchstr(f_line, "\\(class=[\"']\\)\\@<=.*[\"']\\@="). "] " . n_line[:30] . "..." . line_count_text
    endif
    if &ft == "markdown" || &ft == "pandoc"
	return pantondoc#folding#MarkdownFoldText() . line_count_text
    elseif &ft == "textile"
	return pantondoc#folding#TextileFoldText() . line_count_text
    endif
endfunction

" Markdown: {{{1
"
" Originally taken from http://stackoverflow.com/questions/3828606
"
" Syntax assisted (SA) foldexpr {{{2
function! pantondoc#folding#MarkdownLevelSA()
    let vline = getline(v:lnum)
    let synName = synIDattr(synID(v:lnum, 1, 1), "name")
    if synName !~? '\(pandocDelimitedCodeBlock\|clojure\|comment\)'
        " may need to match against stack of highlight groups
        if synName =~? 'pandocAtxHeader' " && vline !~ '^\s*$'
            " in ATX header; not empty line (see 'pandoc_blank_before_header')
            if g:pandoc#folding#mode == 'relative'
                return ">". len(markdown#headers#CurrentHeaderAncestors(v:lnum))
            else
                return ">". len(matchstr(vline, '^#\{1,6}'))
            endif
        elseif synName =~? 'pandocSetexHeader' && vline =~ '^[^-=].\+$'
            " in Setex header but not the dash/equals line
            if getline(v:lnum + 1) =~ '^-\+$'
                " next line is dashes => level 2
                if g:pandoc#folding#mode == 'relative'
                    return ">". len(markdown#headers#CurrentHeaderAncestors(v:lnum))
                else
                    return ">2"
                endif
            else
                " no dashes => equals => level 1
                return ">1"
            endif
        elseif vline =~ '^<!--.*fold-begin -->'
            return "a1"
        elseif vline =~ '^<!--.*fold-end -->'
            return "s1"
        endif
    endif
    return "="
endfunction

" Basic foldexpr {{{2
function! pantondoc#folding#MarkdownLevelBasic()
    if getline(v:lnum) =~ '^#\{1,6}'
	return ">". len(matchstr(getline(v:lnum), '^#\{1,6}'))
    elseif getline(v:lnum) =~ '^[^-=].\+$' && getline(v:lnum+1) =~ '^=\+$'
	return ">1"
    elseif getline(v:lnum) =~ '^[^-=].\+$' && getline(v:lnum+1) =~ '^-\+$'
	return ">2"
    elseif getline(v:lnum) =~ '^<!--.*fold-begin -->'
	return "a1"
    elseif getline(v:lnum) =~ '^<!--.*fold-end -->'
	return "s1"
    endif
    return "="
endfunction

" Markdown foldtext {{{2
function! pantondoc#folding#MarkdownFoldText()
    let c_line = getline(v:foldstart)
    let atx_title = match(c_line, '#') > -1
    if atx_title
        return "- ". c_line 
    else
	if match(getline(v:foldstart+1), '=') != -1
	    let level_mark = '#'
	else
	    let level_mark = '##'
	endif
	return "- ". level_mark. ' '.c_line
    endif
endfunction

" Textile: {{{1
"
function! pantondoc#folding#TextileLevel()
    let vline = getline(v:lnum)
    if vline =~ '^h[1-6]\.'
	return ">" . matchstr(getline(v:lnum), 'h\@1<=[1-6]\.\=')
    elseif vline =~ '^.. .*fold-begin'
	return "a1"
    elseif vline =~ '^.. .*fold end'
	return "s1"
    endif
    return "="
endfunction

function! pantondoc#folding#TextileFoldText()
    return "- ". substitute(v:folddashes, "-", "#", "g"). " " . matchstr(getline(v:foldstart), '\(h[1-6]\. \)\@4<=.*')
endfunction

