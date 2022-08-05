all:
	nim c -d=mingw --app=console --outdir:bin/ --cpu=amd64 NimlineExecuteAssembly.nim
