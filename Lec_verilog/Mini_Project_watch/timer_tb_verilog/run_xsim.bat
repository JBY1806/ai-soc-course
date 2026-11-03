@echo off
rem 타이머 Verilog TB 를 Vivado xsim 으로 GUI 없이 돌린다 (, 10/17)
rem 사용: run_xsim.bat tb_tm_1_add_cap      (TB 이름 하나)
rem (선택) run_xsim.bat TB이름 설계폴더 이름표  → 다른 설계 폴더(예: bug 넣은 사본)로 돌림
rem 결과: run_<TB 이름>\xsim.log 마지막 줄 "TOTAL MISMATCH = 0" 이면 통과
set TB=%1
set SRC=C:\work\BEST_Stop_watch_project\verification_v2\source_file
set HERE=%~dp0
set RUN=run_%TB%
if not "%~2"=="" set SRC=%~2
if not "%~3"=="" set RUN=run_%TB%_%~3
call C:\Xilinx\Vivado\2022.2\settings64.bat
if not exist "%HERE%%RUN%" mkdir "%HERE%%RUN%"
cd /d "%HERE%%RUN%"
type nul > compile.log
for %%f in (%SRC%\*.v) do call xvlog "%%f" >> compile.log 2>&1
for %%f in (%SRC%\*.sv) do call xvlog -sv "%%f" >> compile.log 2>&1
call xvlog "%HERE%%TB%.v" >> compile.log 2>&1
call xelab %TB% -s %TB%_snap -debug off >> compile.log 2>&1
call xsim %TB%_snap -runall -log xsim.log > nul 2>&1
