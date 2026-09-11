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
    endi
endfunction

function! s:Conquer(dir) abort
    if winnr('$') == 1
        return
    endif
    noautocmd exec 'wincmd ' . a:dir
    if a:dir ==# 'H' || a:dir ==# 'L'
        exec 'vertical resize ' . (&columns / 2)
    elseif a:dir ==# 'J' || a:dir ==# 'K'
        exec 'resize ' . (&lines / 2)
    endif
endfunction

" Remaps
nnoremap <silent> <Plug>(ResizeLeft)    :call <SID>Resize('h', 1)<CR>
nnoremap <silent> <Plug>(ResizeDown)    :call <SID>Resize('j', 1)<CR>
nnoremap <silent> <Plug>(ResizeUp)      :call <SID>Resize('k', 1)<CR>
nnoremap <silent> <Plug>(ResizeRight)   :call <SID>Resize('l', 1)<CR>

nnoremap <silent> <Plug>(ConquerLeft)   <Cmd>call <SID>Conquer('H')<CR>
nnoremap <silent> <Plug>(ConquerBottom) <Cmd>call <SID>Conquer('J')<CR>
nnoremap <silent> <Plug>(ConquerTop)    <Cmd>call <SID>Conquer('K')<CR>
nnoremap <silent> <Plug>(ConquerRight)  <Cmd>call <SID>Conquer('L')<CR>
nnoremap <silent> <Plug>(FairShare)     <Cmd>wincmd =<CR>

" Apply default mappings unless the user disables them
if !get(g:, 'pane_resize_disable_defaults', 0)
    nmap H      <Plug>(ResizeLeft)
    nmap J      <Plug>(ResizeDown)
    nmap K      <Plug>(ResizeUp)
    nmap L      <Plug>(ResizeRight)

    nmap <C-h>  <Plug>(ConquerLeft)
    nmap <C-j>  <Plug>(ConquerBottom)
    nmap <C-k>  <Plug>(ConquerTop)
    nmap <C-l>  <Plug>(ConquerRight)
    
    nmap <C-=>  <Plug>(FairShare)
endif