@echo off
call D:\CMD\PASVPDSP pnp32 .\ @PNP32.CFG
copy pnp32.exe ..\pnp32_d.exe
call D:\CMD\PASVPO pnp32 .\ @PNP32.CFG
copy pnp32.exe ..\pnp32_o.exe
if exist pnp32.exe del pnp32.exe
call copywdx ..
call seticon.cmd
