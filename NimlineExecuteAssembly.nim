import ./winim/winim   # currently needs the local winim library
import strformat


#[
  Starts the CLR by calling:
  - CLRCreateInstance()
  - GetRuntime()
  - IsLoadable()
  - GetInterface(CorRuntimeHost)
  - runtime.Start()
]#
proc startCLR(version = ""): ptr ICorRuntimeHost  =

  var
    hr: HRESULT
    metahost: ptr ICLRMetaHost
    runtimeInfo: ptr ICLRRuntimeInfo
    clrRuntimeHost: ptr ICLRRuntimeHost
    corRuntimeHost: ptr ICorRuntimeHost
    loadable: BOOL

  defer:
    if not metahost.isNil: metahost.Release()
    if not runtimeInfo.isNil: runtimeInfo.Release()
    if not clrRuntimeHost.isNil: clrRuntimeHost.Release()


  # Create the CLR Metahost Instance
  hr = CLRCreateInstance(&CLSID_CLRMetaHost, &IID_ICLRMetaHost, cast[ptr LPVOID](addr metahost))


  if hr != S_OK:
    echo("[-] Unable to create metahost instance")
    return nil

  echo "[+] Created metahost instance"

  hr = metahost.GetRuntime(version, &IID_ICLRRuntimeInfo, cast[ptr LPVOID](addr runtimeInfo))

  if hr != S_OK:
    echo("[-] Unable to get runtime")
    return nil

  echo(fmt"[+] Got Runtime for version {version}")

  hr = runtimeInfo.IsLoadable(&loadable)

  if hr != S_OK:
    echo("[-] Specified runtime is not loadable")
    return nil

  echo("[+] Runtime is loadable")


  hr = runtimeInfo.GetInterface(&CLSID_CorRuntimeHost, &IID_ICorRuntimeHost, cast[ptr LPVOID](addr corRuntimeHost))

  if hr != S_OK:
    echo("[-] Unable to get interface of CLRCorRuntimeHost")
    return nil

  echo("[+] Got Interface of CLRCorRuntimeHost")

  # Start the Runtime (Works if the CLR is already running)
  hr = corRuntimeHost.Start()

  if hr != S_OK:
    echo("[-] Failed to Start corRuntimeHost")
    return nil
  echo("[+] Started corRuntimeHost")

  return corRuntimeHost


#[
  Loads the CLR via startCLR(), creates a random Application Domain
  and uses Load_3 and Invoke_3 to execute the Assembly
]#
proc executeAssembly*(asmBytes: seq[byte], arguments: seq[string], version = "v4.0.30319", domainName = "rnd"): bool =


  var
    hr: HRESULT
    corRuntimeHost = startCLR(version)
    appDomainThunk: ptr IUnknown
    appDomain: ptr AppDomain
    assembly: ptr IAssembly
    methodInfo: ptr IMethodInfo
    asmSA: ptr SAFEARRAY         # The SAFEARRAY struct that will hold the assembly bytes
    asmSABound: SAFEARRAYBOUND   # The corresponding SAFEARRAYBOUND structure
    params: ptr SAFEARRAY        # The SAFEARRAY for the parameters/arguments for the assembly
    paramsBound: SAFEARRAYBOUND

  # Release everythting
  defer:
    if not corRuntimeHost.isNil:
      corRuntimeHost.UnloadDomain(appDomainThunk)
      corRuntimeHost.Release()
    if not appDomain.isNil: appDomain.Release()
    if not assembly.isNil: assembly.Release()
    if not asmSA.isNil: SafeArrayDestroy(asmSA)
    if not params.isNil: SafeArrayDestroy(params)
    if not appDomainThunk.isNil: appDomainThunk.Release()


  if corRuntimeHost == nil:
    echo "[-] Failed to start CLR"
    return false

  # init app domain
  hr = corRuntimeHost.CreateDomain(domainName, nil, addr appDomainThunk)

  if FAILED(hr):
    echo("[-] Failed to Create AppDomain")
    return false
  echo("[+] Created Domain ")


  hr = appDomainThunk.QueryInterface(&IID_AppDomain, cast[ptr pointer](addr appDomain))

  if FAILED(hr):
    echo("[-] Failed to Query Interface")
    return false
  echo("[+] Successfully created Application Domain ")


  # Allocating SAFEARRAY with len(asmBytes) items
  asmSABound.cElements = cast[ULONG](len(asmBytes)) # number of elements
  asmSABound.lLbound = 0

  asmSA = SafeArrayCreate(VT_UI1, 1, addr asmSABound)
  var ptrData: pointer

  hr = SafeArrayAccessData(asmSA, addr ptrData)

  if FAILED(hr):
    echo("[-] Failed to access data of SAFEARRAY")
    return false

  # Copy the assembly bytes into the SAFEARRAY
  copyMem(ptrData, unsafeAddr asmBytes[0], len(asmBytes))

  hr = SafeArrayUnaccessData(asmSA)

  # load the Assembly in the created Domain
  hr = appDomain.Load_3(asmSA, addr assembly)

  if FAILED(hr):
    echo(fmt"[-] Failed to load Assembly: {cast[uint32](hr):#X}")
    return false

  echo "[+] Assembly loaded successfully"

  # call the entrypoint
  assembly.get_EntryPoint(addr methodInfo)

  if FAILED(hr):
    echo(fmt"[-] Failed to get EntryPoint")
    return false

  var obj: VARIANT
  var retVal: VARIANT
  obj.vt = VT_NULL
  obj.plVal = NULL

  # Parse the supplied arguments from a commandline string
  # to an array of strings
  #let arguments = parseCmdLine(arguments)

  # The argument variant
  var args: VARIANT
  args.vt = (VT_ARRAY or VT_BSTR)
  var argsBound: SAFEARRAYBOUND
  argsBound.lLbound = 0
  argsBound.cElements = cast[ULONG](len(arguments))
  args.parray = SafeArrayCreate(VT_BSTR, 1, addr argsBound)

  var idx: LONG = 0

  # Adding the arguments into the SAFEARRAY
  for arg in arguments:
    var tmpArg = SysAllocString(arg)
    SafeArrayPutElement(args.parray, addr idx, cast[pointer](tmpArg))
    idx += 1

  idx = 0 # reset to reuise index for the OUTER BSTR SAFEARRAY)

  # Create a new SAFEARRAY for a VT_VARIANT and put the BSTR Array
  # in this struct
  # -> SAFEARRAY(VT_VARIANT, SAFEARRAY(BSTR/VT_ARRAY, "one, two, tthree"))
  paramsBound.lLbound = 0
  paramsBound.cElements = 1
  params = SafeArrayCreate(VT_VARIANT, 1, addr paramsBound)
  SafeArrayPutElement(params, addr idx, addr args)

  # Invoke the Assembly
  hr = methodInfo.Invoke_3(obj, params, addr retVal)

  if FAILED(hr):
    echo(fmt"[-] Failed to execute EntryPoint {cast[uint32](hr):#X}")
    return false

  echo "[+] Execution finishes :)"
  return true


# Example Usage #
#[
when isMainModule:
  const SB = slurp("MyAssembly.exe")
  var asmBytes = cast[seq[byte]](SB)

  discard executeAssembly(asmBytes, @["there are several arguments"])
]#
