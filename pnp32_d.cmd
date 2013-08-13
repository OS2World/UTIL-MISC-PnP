@echo off
set dossetting.DOS_UMB=0
set dossetting.EMS_MEMORY_LIMIT=0
set dossetting.EMS_FRAME_LOCATION=NONE
set dossetting.EMS_LOW_OS_MAP_REGION=0
set dossetting.DPMI_MEMORY_LIMIT=120
set dossetting.DPMI_DOS_API=ENABLED
rem pnp32_d.bat
pnp32_d.bat N
if [%edit%]==[] e pnp32_d.log
if not [%edit%]==[] %edit% pnp32_d.log

