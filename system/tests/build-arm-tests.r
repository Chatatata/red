REBOL [
  Title:   "Builds a set of Red/System Tests to run on an ARM host"
	File: 	 %build-arm-tests.r
	Author:  "Peter W A Wood"
	Version: 0.2.0
	License: "BSD-3 - https://github.com/dockimbel/Red/blob/master/BSD-3-License.txt"
]

;; Change dir to Red/system dir to keep compiler happy
change-dir %../

;; supress script messages
store-quiet-mode: system/options/quiet
system/options/quiet: true

;; init
file-chars: charset [#"a" - #"z" #"A" - #"Z" #"0" - #"9" "-" "/"]
a-file-name: ["%" some file-chars ".reds" ] 
a-test-file: ["--run-test-file-quiet " copy file a-file-name]
a-dll-file: ["--compile-dll " copy file a-file-name]

target: ask {
Choose ARM target:
1) Linux
2) Android
=> }
target: pick ["Linux-ARM" "Android"] to-integer target

;; helper function
compile-test: func [test-file [file!]] [
		do/args %../red.r rejoin ["-t " target " " test-file]
		exe: copy find/last/tail test-file "/"
		exe: to file! replace exe ".reds" ""
		write/binary join %../quick-test/runnable/arm-tests/ exe read/binary exe
		delete exe
]

;; make the Arm dir if needed
arm-dir: %../quick-test/runnable/arm-tests/
make-dir/deep arm-dir

;; empty the Arm dir
foreach file read arm-dir [delete join arm-dir file]

;; compile any dlls
comment {
dlls: copy []
src: read %source/units/make-dylib-auto-test.r
parse/all src [any [a-dll-file (append dlls to file! file) | skip] end]
save-dir: what-dir
change-dir %../
foreach dll dlls [
	if none = find dll "dylib" [
	insert next dll "tests/"
	do/args %rsc.r rejoin ["-dlib -t " target " " dll]
	lib: copy find/last/tail dll "/"
	lib: replace lib ".reds" ".so"
	write/binary join %tests/runnable/arm-tests/ lib read/binary join %builds/ lib	
	]
]

}

;; get the list of test source files
test-files: copy []
all-tests: read %tests/run-all.r
parse/all all-tests [any [a-test-file (append test-files to file! file) | skip] end]

;; compile the tests and move the executables to runnable/arm-tests
foreach test-file test-files [
	if none = find test-file "dylib" [      		;; ignore any dylibs tests
		insert next test-file "tests/"
		compile-test test-file
	]
]

;; generate and compile the dylib tests
comment {

dylib-source: %tests/runnable/arm-tests/dylib-auto-test.reds
test-script-header: read %tests/source/units/dylib-test-script-header.txt
replace test-script-header "%../../../../../quick-test/quick-test.reds"
						   "%../../../../quick-test/quick-test.reds"
libs: read %tests/source/units/dylib-libs.txt
replace libs "***test-dll1***" clean-path %runnable/arm-tests/libtest-dll1.dylib
replace libs "***test-dll2***" clean-path %runnable/arm-tests/libtest-dll2.dylib
tests: read %tests/source/units/dylib-tests.txt
test-script-footer: read %tests/source/units/dylib-test-script-footer.txt
write dylib-source join test-script-header [
	libs tests test-script-footer
]
compile-test dylib-source
if exists? dylib-source [
	delete dylib-source
]
}

;; copy the bash script and mark it as executable
write/binary %../quick-test/runnable/arm-tests/run-all.sh read/binary %tests/run-all.sh
runner: open %../quick-test/runnable/arm-tests/run-all.sh
set-modes runner [
  owner-execute: true
  group-execute: true
  world-execute: true
]
close runner

;; tidy up
system/options/quiet: store-quiet-mode

print "ARM tests built"
