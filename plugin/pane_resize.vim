if exists('g:loaded_pane_resize')
    finish
endif
let g:loaded_pane_resize = 1

function! s:IsEdge(dir) abort
    let cur = winnr()
    noautocmd exec 'wincmd' a:dir
    let edge = (cur == winnr())
    if !edge | noautocmd exec cur 'wincmd w' | endif
    return edge
endfunction

function! s:Resize(dir, amount) abort
    let actions = {
        \ 'h': 'vertical resize -',
        \ 'j': 'resize +',
        \ 'k': 'resize -',
        \ 'l': 'vertical resize +'
        \ }
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

    " Keep cmdheight sane (optional)
    if &cmdheight != 1
        let &cmdheight = 1
    endif
endfunction

function! s:Conquer(dir) abort
    if winnr('$') == 1
        return
    endif

    noautocmd exec 'wincmd ' . a:dir

    if a:dir ==# 'H' || a:dir ==# 'L'
        let target = max([1, &columns / 2])
        exec 'vertical resize ' . target
    elseif a:dir ==# 'J' || a:dir ==# 'K'
        " Usable height = total lines minus UI chrome
        let usable = &lines - &cmdheight
                    \ - (&laststatus  ? 1 : 0)
                    \ - (&showtabline ? 1 : 0)
        let target = max([1, usable / 2])
        exec 'resize ' . target
    endif
endfunction

" Plug definitions
nnoremap <silent> <Plug>(ResizeLeft)    :call <SID>Resize('h', 1)<CR>
nnoremap <silent> <Plug>(ResizeDown)    :call <SID>Resize('j', 1)<CR>
nnoremap <silent> <Plug>(ResizeUp)      :call <SID>Resize('k', 1)<CR>
nnoremap <silent> <Plug>(ResizeRight)   :call <SID>Resize('l', 1)<CR>

nnoremap <silent> <Plug>(ConquerLeft)   <Cmd>call <SID>Conquer('H')<CR>
nnoremap <silent> <Plug>(ConquerBottom) <Cmd>call <SID>Conquer('J')<CR>
nnoremap <silent> <Plug>(ConquerTop)    <Cmd>call <SID>Conquer('K')<CR>
nnoremap <silent> <Plug>(ConquerRight)  <Cmd>call <SID>Conquer('L')<CR>

nnoremap <silent> <Plug>(FairShare)     <Cmd>wincmd =<CR>

if !get(g:, 'pane_resize_disable_defaults', 0)
    nmap <silent> <M-h> <Plug>(ResizeLeft)
    nmap <silent> <M-j> <Plug>(ResizeDown)
    nmap <silent> <M-k> <Plug>(ResizeUp)
    nmap <silent> <M-l> <Plug>(ResizeRight)
    nmap <silent> <M-H> <Plug>(ConquerLeft)
    nmap <silent> <M-J> <Plug>(ConquerBottom)
    nmap <silent> <M-K> <Plug>(ConquerTop)
    nmap <silent> <M-L> <Plug>(ConquerRight)
    nmap <silent> <M-=> <Plug>(FairShare)
endif