@echo off
del ergo.exe
copy ecv10.exe compressor\ergo.exe
cd Compressor\
InfoRem ergo.exe
20to4 -f0 -ornix -v ergo.exe ergo.exe
rem upack ergo.exe -c6 -f273 -set -srt -rai -force
move ergo.exe ..\ergo.exe
cd ..\

del updater.stub
copy ecvupdater.exe compressor\updater.stub
cd Compressor\
InfoRem updater.stub
20to4 -f0 -ornix -v updater.stub updater.stub
rem upack updater.stub -c6 -f273 -set -srt -rai -force
move updater.stub ..\updater.stub
cd ..\

pause


