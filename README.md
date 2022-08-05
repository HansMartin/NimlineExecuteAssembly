# NimlineExecuteAssembly

This is a Nim Implementation of InlineExecuteAssembly and was inspired by: [https://github.com/anthemtotheego/InlineExecute-Assembly](https://github.com/anthemtotheego/InlineExecute-Assembly).


It is implemented without using the `winim/clr` module. However, it would not be possible without the awesome work by [@khchen](https://github.com/khchen) for all the effort he put into the winim library!
This currently uses a local version of winim, as there were some Interfaces missing that are required to use the most traditional method of execution: `Invoke_3`.
These interfaces and the corresponding methods have been added to the provided submodule.

## Usage

It can be used as a library and has the public function:

```nim
proc executeAssembly*(asmBytes: seq[byte], arguments: seq[string], version = "v4.0.30319", domainName = "rnd")
```

This can be used to execute the EntryPoint of any .NET assembly:

```nim
import NimlineExecuteAssembly

const asm = slurp("MyAssembly.exe")
var asmBytes = cast[seq[byte]](asm)

discard executeAssembly(asmBytes, @["there are several arguments"])
```





## References

- [https://github.com/anthemtotheego/InlineExecute-Assembly](https://github.com/anthemtotheego/InlineExecute-Assembly).
- [https://0xpat.github.io/Malware_development_part_9/](https://0xpat.github.io/Malware_development_part_9/)
- [https://modexp.wordpress.com/2019/05/10/dotnet-loader-shellcode/](https://modexp.wordpress.com/2019/05/10/dotnet-loader-shellcode/)





