if exists('g:loaded_pane_resize')
    finish
endif
let g:loaded_pane_resize = 1

let s:win_restore_cmd = ''
let s:orig_cmdheight = &cmdheight

function! s:IsEdge(dir) abort
    let cur = winnr()
    noautocmd exec 'wincmd' a:dir
    let edge = (cur == winnr())
    if !edge | noautocmd exec cur 'wincmd w' | endif
    return edge
endfunction

function! s:Resize(dir, amount) abort
    let actions = {'h': 'vertical resize -', 'j': 'resize +',
                \ 'k': 'resize -', 'l': 'vertical resize +'}
    let opposites = {'h': 'l', 'j': 'k', 'k': 'j', 'l': 'h'}

    if (a:dir ==# 'j' || a:dir ==# 'l') && s:IsEdge(a:dir)
        let opp = opposites[a:dir]
        let cur = winnr()
        noautocmd exec 'wincmd' opp
        exec actions[a:dir] . a:amount
        noautocmd exec cur 'wincmd w'
    elseif (a:dir ==# 'h' || a:dir ==# 'k') && s:IsEdge(opposites[a:dir])
        let cur = winnr()
        noautocmd exec 'wincmd' a:dir
        exec actions[a:dir] . a:amount
        noautocmd exec cur 'wincmd w'
    else
        exec actions[a:dir] . a:amount
    endif
    if &cmdheight != 1
        let &cmdheight = 1
    endif
endfunction

nnoremap <silent> <C-h> :call <SID>Resize('h', 1)<CR>
nnoremap <silent> <C-j> :call <SID>Resize('j', 1)<CR>
nnoremap <silent> <C-k> :call <SID>Resize('k', 1)<CR>
nnoremap <silent> <C-l> :call <SID>Resize('l', 1)<CR>

nnoremap <silent> <C-a> <Cmd>wincmd H <Bar> exe 'vertical resize' . (&columns/2)<CR>
nnoremap <silent> <C-d> <Cmd>wincmd J <Bar> exe 'resize' . (&lines/2)<CR>
nnoremap <silent> <C-s> <Cmd>wincmd K <Bar> exe 'resize' . (&lines/2)<CR>
nnoremap <silent> <C-f> <Cmd>wincmd L <Bar> exe 'vertical resize' . (&columns/2)<CR>
nnoremap <silent> <C-=> <Cmd>wincmd =<CR>