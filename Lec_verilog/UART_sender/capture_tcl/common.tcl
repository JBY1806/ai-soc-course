# sender 캡처 공통 : 색 (빨강 · 파랑 안 씀) · 마커 · 이벤트 시각 기록 (HW9 capture_tcl 과 같은 방식)
set YEL #FFFF00; set ORG #FFA500; set PNK #FF69B4; set GRN #00FF00; set CYN #00FFFF; set WHT #FFFFFF
proc mark {name ns} { add_wave_marker -name $name $ns; puts "MARK $name $ns" }
proc now {} { set t [current_time -s]; foreach {u k} {fs 1e-6 ps 1e-3 ns 1 us 1e3 ms 1e6} { if {[string match *$u $t]} { set v [expr {[string map [list $u ""] $t] * $k}]; if {$v == int($v)} { return [expr {int($v)}] }; return $v } }; return $t }
proc rec {k} { lappend ::ev($k) [now] }
proc evn {k n} { if {[info exists ::ev($k)] && [llength $::ev($k)] >= $n} { return [lindex $::ev($k) [expr {$n-1}]] }; return "" }
proc markn {k n name} { set t [evn $k $n]; if {$t ne ""} { mark $name $t } }
proc markall {k label} { if {[info exists ::ev($k)]} { set i 1; foreach t $::ev($k) { mark ${label}_$i $t; incr i } } }
proc dumpev {k} { if {[info exists ::ev($k)]} { puts "EV $k [llength $::ev($k)] : [lrange $::ev($k) 0 40]" } }
