/*REXX*/
load_REXXUTIL=0
if RxFuncQuery('SysLoadFuncs') then
  do
    load_REXXUTIL=1
    call RxFuncAdd 'SysLoadFuncs', 'REXXUTIL', 'SysLoadFuncs'
    call SysLoadFuncs
  end
    
call SysSetIcon '..\pnp32_o.exe', 'pnp32.ico'
call SysSetIcon '..\pnp32_d.cmd', 'pnp32.ico'
    

if load_REXXUTIL=1 then
  do
    SysDropFuncs
  end