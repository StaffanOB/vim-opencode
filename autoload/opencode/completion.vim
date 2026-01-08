" autoload/opencode/completion.vim - Code Completion Module
" Uses Agent.Complete for context-aware code suggestions

let s:completions = []
let s:complete_position = 0
let s:loading = v:false
let s:last_context = ''

" Initialize completion module
def opencode#completion#init(): void
enddef

" Trigger completion manually
def opencode#completion#trigger(): void
  if s:loading
    echo 'Already loading completions...'
    return
  endif
  
  " Ensure we have a session
  if empty(opencode#api#get_session_id())
    let result = opencode#api#create_session('Vim Completion')
    if !result.success
      echoerr 'Failed to create session: ' .. result.error
      return
    endif
  endif
  
  " Get context around cursor
  let context = s:get_context()
  let s:last_context = context
  
  call s:fetch_completion(context)
enddef

" Main omnifunc for complete()
def opencode#completion#omnifunc(findstart: number, base: string): any
  if findstart == 1
    let s:complete_position = s:get_completion_start()
    return s:complete_position
  endif
  
  if s:loading
    return []
  endif
  
  return s:completions
enddef

" Get code context around cursor
def s:get_context(): string
  let start_line = max([1, line('.') - 10])
  let end_line = min([line('$'), line('.') + 5])
  let lines = getline(start_line, end_line)
  
  " Add cursor position marker
  let cursor_line = line('.') - start_line
  let lines[cursor_line] = lines[cursor_line] .. ' <CURSOR>'
  
  return join(lines, "\n")
enddef

" Get completion start position
def s:get_completion_start(): number
  let line = getline('.')
  let col = col('.')
  let start = col
  
  while start > 1 && line[start - 2] =~ '\k'
    let start -= 1
  endwhile
  
  return start
enddef

" Fetch completion from Opencode using Agent.Complete
def s:fetch_completion(context: string): void
  s:loading = v:true
  echo 'Requesting completion...'
  
  let session_id = opencode#api#get_session_id()
  let model = opencode#models#get_active()
  
  " Build prompt for completion agent
  let prompt = 'Complete the code at <CURSOR>. Provide only the code that should replace the cursor position. Do not include explanations.'
  
  let result = opencode#api#send_message(session_id, prompt, 'Agent.Complete', model)
  
  s:loading = v:false
  
  if result.success
    call s:parse_completion_result(result.parts)
  else
    echoerr 'Completion failed: ' .. result.error
  endif
enddef

" Parse completion result and show suggestions
def s:parse_completion_result(parts: list<dict<any>>): void
  let text = ''
  for part in parts
    if get(part, 'type', '') ==# 'text'
      let text ..= get(part, 'text', '')
    endif
  endfor
  
  if empty(text)
    echo 'No completion suggestions'
    return
  endif
  
  " Parse into completion items
  let items = s:text_to_completions(text)
  
  if len(items) > 0
    call complete(s:get_completion_start(), items)
    echo 'Select completion:'
  else
    echo 'No completions found'
  endif
enddef

" Convert completion text to Vim completion items
def s:text_to_completions(text: string): list<dict<any>>
  let items = []
  let lines = split(text, '\n')
  let word_match = matchstr(getline('.'), '\k*$')
  
  for line in lines
    let line = substitute(line, '^\s*', '', '')
    if empty(line)
      continue
    endif
    
    let word = split(line, '\s\|\.\|(\|)\|\[\|\]\|{\|}')[0]
    if empty(word)
      let word = line
    endif
    
    call add(items, {
      'word': word,
      'abbr': line,
      'menu': '[Opencode]',
      'icase': 1,
      'dup': 1
    })
  endfor
  
  return items
enddef

" Show inline diff for completion
def opencode#completion#show_diff(completion_text: string): void
  let buf = bufnr('OpencodeDiff')
  
  if bufexists(buf)
    exec buf .. 'bw!'
  endif
  
  enew
  setlocal buftype=nofile
  setlocal bufhidden=hide
  setlocal noswapfile
  
  let lines = split(completion_text, '\n')
  call setline(1, lines)
  
  diffthis
  
  nnoremap <buffer> <CR> :call <SID>accept_diff()<CR>
  nnoremap <buffer> <Esc> :bw!<CR>
  nmap <buffer> q :bw!<CR>
  
  echo 'Press <CR> to accept, <Esc> to cancel'
enddef

" Accept the diff changes
def s:accept_diff(): void
  let lines = getline(1, '$')
  let current_lines = getline(1, '$')
  
  for i in range(min([len(lines), len(current_lines)]))
    call setline(i + 1, lines[i])
  endfor
  
  if len(lines) > len(current_lines)
    call append(len(current_lines), lines[len(current_lines):])
  endif
  
  bw!
  echo 'Completion applied!'
enddef

" Complete current word using AI
def opencode#completion#complete_word(): void
  let line = getline('.')
  let col = col('.')
  let before_cursor = line[: col - 2]
  let current_word = matchstr(before_cursor, '\k*$')
  
  if empty(current_word)
    echo 'No word to complete'
    return
  endif
  
  let prompt = 'Complete this partial word: ' .. current_word
  let session_id = opencode#api#get_session_id()
  let model = opencode#models#get_active()
  
  let result = opencode#api#send_message(session_id, prompt, 'Agent.Complete', model)
  
  if result.success
    let suggestion = ''
    for part in result.parts
      if get(part, 'type', '') ==# 'text'
        let suggestion ..= get(part, 'text', '')
      endif
    endfor
    
    if !empty(suggestion)
      call complete(col, [{'word': current_word .. suggestion, 'menu': '[Opencode]'}])
    endif
  endif
enddef
