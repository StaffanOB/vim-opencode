" plugin/opencode.vim - Vim Opencode Plugin Initialization
" Main entry point for the plugin

" Guard against multiple loads
if exists('g:loaded_opencode')
  finish
endif
let g:loaded_opencode = 1

" Default configuration
if !exists('g:opencode_host')
  let g:opencode_host = '127.0.0.1'
endif
if !exists('g:opencode_port')
  let g:opencode_port = 4096
endif
if !exists('g:opencode_model')
  let g:opencode_model = ''
endif
if !exists('g:opencode_reuse_session')
  let g:opencode_reuse_session = 1
endif
if !exists('g:opencode_completion_key')
  let g:opencode_completion_key = '<Tab>'
endif
if !exists('g:opencode_chat_key')
  let g:opencode_chat_key = '<C-x>'
endif
if !exists('g:opencode_review_key')
  let g:opencode_review_key = '<Leader>cr'
endif

" Load autoload functions
call opencode#api#init()
call opencode#models#init()
call opencode#completion#init()
call opencode#chat#init()
call opencode#review#init()
call opencode#util#reload()

" Define user commands
command! -nargs=0 OpencodeChat call opencode#chat#open()
command! -nargs=0 OpencodeComplete call opencode#completion#trigger()
command! -nargs=0 OpencodeReview call opencode#review#review_file()
command! -nargs=0 OpencodeReviewSelection call opencode#review#review_selection()
command! -nargs=0 OpencodeModels call opencode#models#select_and_save()
command! -nargs=0 OpencodeConnect call opencode#util#connect_check()
command! -nargs=0 OpencodeHealth call opencode#util#health_check()
command! -nargs=0 OpencodeReload call opencode#util#reload()

" Set up default key mappings
if !hasmapto('<Plug>(opencode-completion)')
  exec 'nnoremap <silent> <Plug>(opencode-completion) :OpencodeComplete<CR>'
  exec 'inoremap ' . g:opencode_completion_key . ' <C-r>=<SID>completion_wrapper()<CR>'
endif

if !hasmapto('<Plug>(opencode-chat)')
  nnoremap <silent> <Plug>(opencode-chat) :OpencodeChat<CR>
  exec 'inoremap ' . g:opencode_chat_key . ' <Esc>:OpencodeChat<CR>'
endif

if !hasmapto('<Plug>(opencode-review)')
  nnoremap <silent> <Plug>(opencode-review) :OpencodeReview<CR>'
endif

" Completion wrapper for insert mode
function! s:completion_wrapper()
  call opencode#completion#trigger()
  return ''
endfunction

" Auto commands
augroup OpencodePlugin
  autocmd!
  autocmd FileType * call <SID>setup_buffer()
augroup END

function! s:setup_buffer()
  if &buftype ==# 'nofile' || &buftype ==# 'help'
    return
  endif
  if &filetype =~# 'help\|qf\|nerdtree\|fugitive'
    return
  endif
  setlocal omnifunc=opencode#completion#omnifunc
endfunction

echo 'Opencode plugin loaded. Commands: :OpencodeChat, :OpencodeComplete, :OpencodeModels'
