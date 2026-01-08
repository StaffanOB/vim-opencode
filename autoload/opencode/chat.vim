" autoload/opencode/chat.vim - Chat Interface Module
" Interactive chat with Opencode using persistent sessions

let s:chat_buffer = -1
let s:chat_window = -1
let s:chat_history = []
let s:chat_title = 'Opencode Chat'

" Initialize chat module
def opencode#chat#init(): void
enddef

" Open chat window
def opencode#chat#open(): void
  if !s:create_chat_window()
    echoerr 'Failed to create chat window'
    return
  endif
  
  call s:setup_chat_buffer()
  
  " Create session if needed
  if empty(opencode#api#get_session_id())
    let result = opencode#api#create_session('Vim Chat')
    if !result.success
      call s:show_error('Failed to create session: ' .. result.error)
      return
    endif
  endif
  
  call s:welcome_message()
enddef

" Create or reuse chat window
def s:create_chat_window(): bool
  if bufexists(s:chat_buffer) && win_findbuf(s:chat_buffer) != []
    let wins = win_findbuf(s:chat_buffer)
    if len(wins) > 0
      call win_gotoid(wins[0])
      return v:true
    endif
  endif
  
  vertical topleft new
  setlocal buftype=acwrite
  setlocal bufhidden=hide
  setlocal noswapfile
  setlocal nowrap
  setlocal modifiable
  
  let s:chat_buffer = bufnr('%')
  let s:chat_window = win_getid()
  
  call s:setup_chat_mappings()
  call s:setup_chat_autocmds()
  
  return v:true
enddef

" Setup chat buffer properties
def s:setup_chat_buffer(): void
  setlocal filetype=opencode-chat
  setlocal nonumber
  setlocal norelativenumber
  setlocal cursorline
  
  if exists('&winbar')
    set winbar=Opencode\ Chat
  endif
enddef

" Setup chat-specific mappings
def s:setup_chat_mappings(): void
  nnoremap <buffer> <CR> :call <SID>send_message()<CR>
  nnoremap <buffer> <C-CR> :call <SID>send_message(v:true)<CR>
  nnoremap <buffer> q :call <SID>close_chat()<CR>
  nnoremap <buffer> :w<CR> :call <SID>send_message()<CR>
  nnoremap <buffer> <Esc> :call <SID>close_chat()<CR>
  
  inoremap <buffer> <CR> <Esc>:call <SID>send_message()<CR>
  inoremap <buffer> <C-CR> <Esc>:call <SID>send_message(v:true)<CR>
enddef

" Setup autocommands
def s:setup_chat_autocmds(): void
  augroup OpencodeChat
    autocmd!
    autocmd BufUnload <buffer> call <SID>on_chat_unload()
    autocmd BufEnter <buffer> call <SID>on_chat_enter()
  augroup END
enddef

" Show welcome message
def s:welcome_message(): void
  let model = opencode#models#get_active()
  let model_display = empty(model) ? 'Opencode Default' : opencode#models#get_display_name(model)
  
  call append('$', '═══════════════════════════════════════════════════════')
  call append('$', '  Opencode Chat')
  call append('$', '═══════════════════════════════════════════════════════')
  call append('$', '')
  call append('$', 'Model: ' .. model_display)
  call append('$', 'Session: ' .. opencode#api#get_session_id())
  call append('$', '')
  call append('$', '───────────────────────────────────────────────────────')
  call append('$', 'Enter your question and press <CR> to send.')
  call append('$', 'Press <Esc> or q to close.')
  call append('$', '───────────────────────────────────────────────────────')
  call append('$', '')
  call append('$', 'You:')
  normal! G$
  startinsert!
enddef

" Send message to Opencode
def s:send_message(include_code: bool = v:false): void
  let current_line = line('.')
  
  if current_line < 10
    return
  endif
  
  let message = getline(current_line)
  
  if message =~? '^You:'
    let message = substitute(message, '^You:\s*', '', '')
  endif
  
  if empty(message)
    echo 'Please enter a message first'
    return
  endif
  
  " Add selected code if requested
  if include_code
    let code_context = s:get_selected_code()
    if !empty(code_context)
      let message = message .. "\n\nRelevant code:\n```\n" .. code_context .. "\n```"
    endif
  endif
  
  " Update the message line
  call setline(current_line, 'You: ' .. message)
  
  " Show thinking indicator
  call append('$', '')
  call append('$', 'Opencode: *thinking*')
  normal! G$
  redraw
  
  " Send to Opencode
  let session_id = opencode#api#get_session_id()
  let model = opencode#models#get_active()
  
  let result = opencode#api#send_message(session_id, message, '', model)
  
  " Remove thinking indicator
  if line('$') > 1
    let last_line = line('$')
    if getline(last_line) =~# '\*thinking\*'
      exec last_line .. 'delete'
    endif
  endif
  
  if result.success
    " Extract text from response
    let response_text = ''
    for part in result.parts
      if get(part, 'type', '') ==# 'text'
        let response_text ..= get(part, 'text', '')
      endif
    endfor
    
    call append('$', 'Opencode: ' .. response_text)
    call append('$', '')
    call append('$', 'You:')
    normal! G$
    startinsert!
    
    " Add to history
    call add(s:chat_history, {'role': 'user', 'content': message})
    call add(s:chat_history, {'role': 'assistant', 'content': response_text})
    
    if len(s:chat_history) > 50
      let s:chat_history = s:chat_history[-50:]
    endif
  else
    call append('$', 'Opencode: Error - ' .. result.error)
    call append('$', '')
    call append('$', 'You:')
    normal! G$
    startinsert!
  endif
enddef

" Get selected code from current buffer
def s:get_selected_code(): string
  let reg = getreg('"')
  let regtype = getregtype('"')
  
  normal! gv"ay
  
  let selected = getreg('"')
  
  call setreg('"', reg, regtype)
  
  return selected
enddef

" Close chat window
def s:close_chat(): void
  if win_getid() == s:chat_window
    close
  endif
enddef

" Handle chat unload
def s:on_chat_unload(): void
  let s:chat_buffer = -1
  let s:chat_window = -1
enddef

" Handle chat enter
def s:on_chat_enter(): void
  if line('$') > 1 && getline('$') =~? '^You:'
    normal! G$
    startinsert!
  endif
enddef

" Clear chat history
def opencode#chat#clear(): void
  if bufexists(s:chat_buffer)
    let wins = win_findbuf(s:chat_buffer)
    if len(wins) > 0
      call win_gotoid(wins[0])
      silent! normal! ggdG
      let s:chat_history = []
      call s:welcome_message()
    endif
  endif
enddef

" Show error message in chat
def s:show_error(msg: string): void
  call append('$', '')
  call append('$', 'Error: ' .. msg)
  normal! G$
enddef

" Get session ID for external use
def opencode#chat#get_session_id(): string
  return opencode#api#get_session_id()
enddef
