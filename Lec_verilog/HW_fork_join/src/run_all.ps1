# hw fork join 분석 — 예제 5 개를 차례로 컴파일 · 실행하고 $display 결과만 보여 준다
#   사용 (VS Code 터미널 · PowerShell) :
#     powershell -ExecutionPolicy Bypass -File C:\Users\LG\Developer\Lec_verilog\HW_fork_join\src\run_all.ps1
#   실행 폴더 : C:\work\forkjoin_run\ex1 ~ ex5 (경로에 한글이 없어야 Vivado 가 안전)
$ErrorActionPreference = 'Continue'
$src = Split-Path -Parent $MyInvocation.MyCommand.Path
$bin = 'C:\Xilinx\Vivado\2022.2\bin'
$files = @('ex1_join.sv', 'ex2_join_any.sv', 'ex3_join_none.sv', 'ex4_nested.sv', 'ex5_disable_fork.sv')
$i = 0
foreach ($f in $files) {
    $i++
    $dir = "C:\work\forkjoin_run\ex$i"
    New-Item -ItemType Directory -Force $dir | Out-Null
    Copy-Item (Join-Path $src $f) (Join-Path $dir 'tb.sv') -Force
    Push-Location $dir
    & "$bin\xvlog.bat" -sv tb.sv *> compile.txt
    & "$bin\xelab.bat" --debug typical tb_fork_join -s snap *> elab.txt
    & "$bin\xsim.bat" snap -runall *> run.txt
    Pop-Location
    Write-Host ""
    Write-Host "===== Example $i : $f =====" -ForegroundColor Yellow
    $err = Select-String -Path "$dir\compile.txt", "$dir\elab.txt" -Pattern 'ERROR' -SimpleMatch
    if ($err) { $err | ForEach-Object { Write-Host $_.Line -ForegroundColor Red } }
    Get-Content "$dir\run.txt" | Where-Object { $_ -match ' : ' -or $_ -match '\$stop|\$finish|Stopped' } |
        Where-Object { $_ -notmatch '^(INFO|source|#|\*\*)' } | ForEach-Object { Write-Host $_ }
}
Write-Host ""
Write-Host "Done - logs : C:\work\forkjoin_run\ex1 ~ ex5\run.txt" -ForegroundColor Green
