" test/run.vim - Vim Opencode Test Runner
" Run with: vim -u NONE -c "set rtp+=." -c "source test/run.vim" -c "qa!"

function! s:run_all_tests() abort
  echo 'Running Opencode Tests...'
  echo '========================='
  echo ''
  
  let l:passed = 0
  let l:failed = 0
  let l:tests = []
  
  for testfile in split(glob('test/*.vimspec'), '\n')
    echo 'Running: ' .. fnamemodify(testfile, ':t')
    try
      exec 'source ' .. testfile
      let l:passed = l:passed + 1
      call add(l:tests, {'name': fnamemodify(testfile, ':t'), 'status': 'PASS'})
    catch
      let l:failed = l:failed + 1
      call add(l:tests, {'name': fnamemodify(testfile, ':t'), 'status': 'FAIL', 'error': v:exception})
      echo '  FAIL: ' .. v:exception
    endtry
  endfor
  
  echo ''
  echo 'Results:'
  echo '--------'
  echo 'Passed: ' . l:passed
  echo 'Failed: ' . l:failed
  echo ''
  
  if l:failed > 0
    echo 'Failed tests:'
    for test in l:tests
      if test.status ==# 'FAIL'
        echo '  - ' . test.name . ': ' . test.error
      endif
    endfor
    cq
  else
    echo 'All tests passed!'
  endif
endfunction

function! s:run_single_test(file) abort
  if empty(a:file)
    echo 'Usage: vim -u NONE -c "source test/run.vim" -c "call RunSingleTest(''.test/my_test.vimspec'')"
    return
  endif
  
  echo 'Running: ' . a:file
  try
    exec 'source ' . a:file
    echo 'PASS'
  catch
    echo 'FAIL: ' . v:exception
    cq
  endtry
endfunction

command! -nargs=0 TestAll call <SID>run_all_tests()
command! -nargs=1 TestOne call <SID>run_single_test(<q-args>)

if empty($OPENCODE_TEST_FILE)
  call <SID>run_all_tests()
else
  call <SID>run_single_test($OPENCODE_TEST_FILE)
endif
