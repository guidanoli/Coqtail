" File: coqtail.vim
" Author: Wolf Honore (inspired by/partially adapted from Coquille)
"
" Coquille Credit:
" Copyright (c) 2013, Thomas Refis
"
" Permission to use, copy, modify, and/or distribute this software for any
" purpose with or without fee is hereby granted, provided that the above
" copyright notice and this permission notice appear in all copies.
"
" THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
" REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND
" FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
" INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
" LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
" OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
" PERFORMANCE OF THIS SOFTWARE.
"
" FIXME: add description

" Only source once
if exists('g:coqtail_sourced')
    finish
endif
let g:coqtail_sourced = 1

" Check python version
if has('python')
    command! -nargs=1 Py py <args>
elseif has('python3')
    command! -nargs=1 Py py3 <args>
else
    echoerr 'Coqtail requires python support.'
    finish
endif

" Initialize global variables
let g:counter = 0

if !exists('g:coq_proj_file')
    let g:coq_proj_file = '_CoqProject'
endif

" Load vimbufsync if not already done
call vimbufsync#init()

" Add current directory to path so python functions can be called
let s:current_dir = expand('<sfile>:p:h')
Py import sys, vim
Py if not vim.eval('s:current_dir') in sys.path:
\    sys.path.append(vim.eval('s:current_dir'))
Py import coqtail

" FIXME: add description
function! coqtail#GetCurWord()
    " Add '.' to definition of a keyword
    setlocal iskeyword+=.

    " Check if current word ends in '.' and remove it if so
    let l:cword = expand('<cword>')
    if l:cword =~ '.*[.]$'
       let l:cword = l:cword[:-2]
    endif

    " Reset iskeyword
    " TODO: actually restore in case '.' was already in keyword
    setlocal iskeyword-=.

    return l:cword
endfunction

" FIXME: add description
function! coqtail#SetTimeout()
    let l:old_timeout = b:coq_timeout

    let b:coq_timeout = input('Set timeout to (secs): ')

    " TODO: recognize string vs number
    if b:coq_timeout < 0
        echoerr 'Invalid timeout, keeping old value.'
        let b:coq_timeout = l:old_timeout
    elseif b:coq_timeout == 0
        echo 'Timeout of 0 will disable timeout.'
    endif

    let b:coq_timeout = str2nr(b:coq_timeout)
    echo 'timeout=' . b:coq_timeout
endfunction

" Create buffers for the goals and info panels.
function! coqtail#InitPanels()
    let l:coq_buf = bufnr('%')

    " Add goals panel
    execute 'hide edit Goals' . g:counter
    setlocal buftype=nofile
    setlocal filetype=coq-goals
    setlocal noswapfile
    let b:coq_buf = l:coq_buf  " Assumes buffer number won't change
    let l:goal_buf = bufnr('%')

    " Add info panel
    execute 'hide edit Infos' . g:counter
    setlocal buftype=nofile
    setlocal filetype=coq-infos
    setlocal noswapfile
    let b:coq_buf = l:coq_buf
    let l:info_buf = bufnr('%')

    " Switch back to main panel
    execute 'hide edit #' . l:coq_buf
    let b:goal_buf = l:goal_buf
    let b:info_buf = l:info_buf

    Py coqtail.splash()
    let g:counter += 1
endfunction

" FIXME: add description
" TODO: loses highlighting when switching back from another window
function! coqtail#OpenPanels()
    let l:coq_win = winnr()

    let l:goal_buf = b:goal_buf
    let l:info_buf = b:info_buf

    execute 'rightbelow vertical sbuffer ' . l:goal_buf
    execute 'rightbelow sbuffer ' . l:info_buf

    " Switch back to main panel
    execute l:coq_win . 'wincmd w'

    Py coqtail.reset_color()
    Py coqtail.restore_goal()
    Py coqtail.show_info()
endfunction

" FIXME: add description
function! coqtail#HidePanels()
    " Switch back to main panel
    " Assumes that there are only the 3 expected panels
    if exists('b:coq_buf')
        let l:coq_win = bufwinnr(b:coq_buf)
        execute l:coq_win . 'wincmd w'
    endif

    " Hide other panels
    only

    Py coqtail.hide_color()
endfunction

" FIXME: add description
function! coqtail#Query(...)
    Py coqtail.query(*vim.eval('a:000'))
endfunction

" FIXME: add description
function! coqtail#QueryMapping()
    map <silent> <leader>cs :Coq SearchAbout <C-r>=expand(coqtail#GetCurWord())<CR>.<CR>
    map <silent> <leader>ch :Coq Check <C-r>=expand(coqtail#GetCurWord())<CR>.<CR>
    map <silent> <leader>ca :Coq About <C-r>=expand(coqtail#GetCurWord())<CR>.<CR>
    map <silent> <leader>cp :Coq Print <C-r>=expand(coqtail#GetCurWord())<CR>.<CR>
    map <silent> <leader>cf :Coq Locate <C-r>=expand(coqtail#GetCurWord())<CR>.<CR>

    map <silent> <leader>co :FindDef <C-r>=expand(coqtail#GetCurWord())<CR><CR>
endfunction

" FIXME: add description
function! coqtail#Mapping()
    map <silent> <leader>cc :CoqStart<CR>
    map <silent> <leader>cq :CoqStop<CR>

    map <silent> <leader>cj :CoqNext<CR>
    map <silent> <leader>ck :CoqUndo<CR>
    map <silent> <leader>cl :CoqToCursor<CR>
    map <silent> <leader>cT :CoqToTop<CR>

    imap <silent> <leader>cj <C-\><C-o>:CoqNext<CR>
    imap <silent> <leader>ck <C-\><C-o>:CoqUndo<CR>
    imap <silent> <leader>cl <C-\><C-o>:CoqToCursor<CR>

    map <silent> <leader>cG :JumpToEnd<CR>

    map <silent> <leader>ct :call coqtail#SetTimeout()<CR>

    call coqtail#QueryMapping()
endfunction

" FIXME: add description
function! coqtail#Stop()
    if b:coq_running == 1
        let b:coq_running = 0

        try
            Py coqtail.stop()

            execute 'bdelete' . b:goal_buf
            execute 'bdelete' . b:info_buf

            autocmd! coqtail#Autocmds * <buffer>

            unlet b:goal_buf b:info_buf
        catch
        endtry
    endif
endfunction

" FIXME: add description
function! coqtail#Start(...)
    if b:coq_running == 1
        echo 'Coq is already running.'
    else
        let b:coq_running = 1

        " Check for a Coq project file
        if filereadable(g:coq_proj_file)
            let l:proj_args = split(join(readfile(g:coq_proj_file)))
        else
            let l:proj_args = []
        endif

        " Launch coqtop
        try
            Py coqtail.start(*vim.eval('map(copy(l:proj_args+a:000),"expand(v:val)")'))

            " Coqtail commands

            " Stop Coqtail
            command! -buffer CoqStop call coqtail#Stop()

            " Move Coq position
            command! -buffer CoqNext Py coqtail.next()
            command! -buffer CoqUndo Py coqtail.rewind()
            command! -buffer CoqToCursor Py coqtail.to_cursor()
            command! -buffer CoqToTop coqtail.to_top()

            " Coq query
            command! -buffer -nargs=* Coq call coqtail#Query(<f-args>)

            " Move cursor
            command! -buffer JumpToEnd Py coqtail.jump_to_end()
            command! -buffer -nargs=1 FindDef Py coqtail.find_def(<f-args>)

            " Initialize goals and info panels
            call coqtail#InitPanels()
            call coqtail#OpenPanels()

            " Autocmds to do some detection when editing an already check portion of
            " the code, and to hide and restore the info and goal panels as needed.
            augroup coqtail#Autocmds
                autocmd InsertEnter <buffer> Py coqtail.sync()
                autocmd BufWinLeave <buffer> call coqtail#HidePanels()
                autocmd BufWinEnter <buffer> call coqtail#OpenPanels()
            augroup end
        catch /coq_start_fail/
            call coqtail#Stop()
        endtry
    endif
endfunction

" FIXME: add description
function! coqtail#Register()
    " Highlighting for checked parts
    hi default CheckedByCoq ctermbg=17 guibg=LightGreen
    hi default SentToCoq ctermbg=60 guibg=LimeGreen
    hi link CoqError Error

    " Initialize once
    if !exists('b:coq_running')
        let b:coq_running = 0
        let b:checked = -1
        let b:sent    = -1
        let b:errors  = -1
        let b:coq_timeout = 3

        " TODO: find a less hacky solution
        " Define a dummy command for Coq so it does not autocomplete to CoqStart and cause coqtop to hang
        command! -buffer -nargs=* Coq echoerr 'Coq is not running.'

        command! -bar -buffer -nargs=* -complete=file CoqStart call coqtail#Start(<f-args>)
    endif
endfunction