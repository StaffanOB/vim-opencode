" autoload/opencode/models.vim - Model Selection Module
" Lists and selects models from Opencode configuration

let s:selected_model = ''
let s:model_list = []

" Initialize models module
def opencode#models#init(): void
  if exists('g:opencode_model') && !empty(g:opencode_model)
    let s:selected_model = g:opencode_model
  endif
enddef

" Get the currently selected model
def opencode#models#get_selected(): string
  return s:selected_model
enddef

" Get selected model or use Opencode's default
def opencode#models#get_active(): string
  if !empty(s:selected_model)
    return s:selected_model
  endif
  return ''
enddef

" Refresh model list from Opencode server
def opencode#models#refresh(): list<dict<any>>
  call opencode#api#clear_cache()
  let s:model_list = opencode#api#get_models()
  return s:model_list
enddef

" Get all available models
def opencode#models#get_all(): list<dict<any>>
  if len(s:model_list) == 0
    let s:model_list = opencode#api#get_models()
  endif
  return s:model_list
enddef

" Show model selection picker
def opencode#models#select(): void
  let models = opencode#models#get_all()
  
  if len(models) == 0
    echoerr 'No models available. Make sure Opencode server is running: opencode serve'
    return
  endif

  " Create completion list
  let items = []
  for model in models
    call add(items, model.id .. ' | ' .. model.name)
  endfor

  " Show completion picker
  echo 'Select a model (Tab to browse, Enter to confirm):'
  let selected = complete(1, items)
  
  if !empty(selected)
    let choice = selected[0]
    let model_id = substitute(choice, ' |.*$', '', '')
    call opencode#models#set(model_id)
  endif
enddef

" Set the selected model
def opencode#models#set(model_id: string): bool
  " Validate model exists
  let models = opencode#models#get_all()
  for model in models
    if model.id ==# model_id
      let s:selected_model = model_id
      let g:opencode_model = model_id
      echo 'Model set to: ' .. model_id
      return v:true
    endif
  endfor
  
  echoerr 'Unknown model: ' .. model_id
  return v:false
enddef

" Save model to vimrc
def opencode#models#save_to_vimrc(model_id: string): bool
  " Find model info
  let models = opencode#models#get_all()
  let model_name = model_id
  for model in models
    if model.id ==# model_id
      let model_name = model.name
      break
    endif
  endfor

  " Get vimrc path
  let vimrc = $MYVIMRC
  if empty(vimrc)
    let vimrc = expand('~/.vimrc')
  endif
  
  " Check if already set
  if filereadable(vimrc)
    let content = join(readfile(vimrc), "\n")
    if content =~# 'g:opencode_model'
      " Update existing line
      let new_content = substitute(content, 'let g:opencode_model\s*=\s*[''"].*[''"]', "let g:opencode_model = '" .. model_id .. "'", '')
      call writefile(split(new_content, "\n"), vimrc)
      echo 'Updated ' .. vimrc .. ' with model: ' .. model_id
      return v:true
    endif
  endif
  
  " Append new line
  let line = "let g:opencode_model = '" .. model_id .. "'"
  call writefile(['', line], vimrc, 'a')
  echo 'Added to ' .. vimrc .. ': ' .. model_id
  
  return v:true
enddef

" Show model selection with vimrc save
def opencode#models#select_and_save(): void
  let models = opencode#models#get_all()
  
  if len(models) == 0
    echoerr 'No models available. Make sure Opencode server is running.'
    return
  endif

  let items = []
  for model in models
    call add(items, model.id)
  endfor

  echo 'Select a model (Tab to browse, Enter to confirm):'
  let selected = complete(1, items)
  
  if !empty(selected)
    let model_id = selected[0]
    if opencode#models#set(model_id)
      call opencode#models#save_to_vimrc(model_id)
    endif
  endif
enddef

" Show model info
def opencode#models#info(): void
  echo 'Opencode Model Configuration'
  echo '=============================='
  echo ''
  
  let server_info = opencode#api#get_server_info()
  echo 'Server: ' .. server_info.url
  echo 'Version: ' .. server_info.version
  echo 'Connected: ' .. (server_info.connected ? 'Yes' : 'No')
  echo ''
  
  echo 'Current Model: ' .. (empty(s:selected_model) ? '(default)' : s:selected_model)
  echo ''
  
  let models = opencode#models#get_all()
  echo 'Available Models (' .. len(models) .. '):'
  
  for model in models
    let prefix = model.id ==# s:selected_model ? '* ' : '  '
    echo prefix .. model.id .. ' - ' .. model.name
  endfor
  
  echo ''
  echo 'Use :OpencodeModels to select a model'
  echo 'Use :OpencodeConnect to check connection'
enddef

" Get model display name
def opencode#models#get_display_name(model_id: string): string
  if empty(model_id)
    return 'Opencode Default'
  endif
  
  let models = opencode#models#get_all()
  for model in models
    if model.id ==# model_id
      return model.name
    endif
  endfor
  
  return model_id
enddef

" Check if a model is available
def opencode#models#is_available(model_id: string): bool
  let models = opencode#models#get_all()
  for model in models
    if model.id ==# model_id
      return v:true
    endif
  endfor
  return v:false
enddef
