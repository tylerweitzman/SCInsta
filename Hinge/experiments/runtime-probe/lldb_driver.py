"""LLDB command used by probe.py. Always detaches, including on expression failure."""
import json
from pathlib import Path
import shlex
import shutil
import lldb


def run(debugger, command, result, internal_dict):
    config = json.loads(Path(shlex.split(command)[0]).read_text())
    report = {"pid": config["pid"], "queries": [], "errors": []}
    process = None
    try:
        target = debugger.CreateTarget("")
        error = lldb.SBError()
        process = target.AttachToProcessWithID(debugger.GetListener(), config["pid"], error)
        if error.Fail():
            raise RuntimeError(error.GetCString())
        main = next((thread for thread in process if thread.GetQueueName() == "com.apple.main-thread"), process.GetThreadAtIndex(0))
        process.SetSelectedThread(main)
        frame = main.GetFrameAtIndex(0)
        options = lldb.SBExpressionOptions()
        options.SetLanguage(lldb.eLanguageTypeObjC_plus_plus)
        options.SetTimeoutInMicroSeconds(10_000_000)
        options.SetIgnoreBreakpoints(True)
        options.SetUnwindOnError(True)

        def evaluate(expression):
            value = frame.EvaluateExpression(expression, options)
            if value.GetError().Fail():
                raise RuntimeError(value.GetError().GetCString())
            return value

        temp_value = evaluate('(const char *)[(id)NSTemporaryDirectory() UTF8String]')
        temp_error = lldb.SBError()
        app_temp = process.ReadCStringFromMemory(temp_value.GetValueAsUnsigned(), 16384, temp_error)
        if temp_error.Fail():
            raise RuntimeError(temp_error.GetCString())
        library = Path(app_temp) / "HingeRuntimeProbe.dylib"
        shutil.copy2(config["library"], library)
        report["helperPath"] = str(library)
        loaded = evaluate('(void *)dlopen(' + json.dumps(str(library)) + ', 2)')
        if loaded.GetValueAsUnsigned() == 0:
            reason = evaluate('(const char *)dlerror()')
            raise RuntimeError("dlopen failed: " + str(reason.GetSummary()))

        def call(message):
            value = evaluate('(const char *)[(id)[(id)objc_getClass("HingeRuntimeProbe") ' + message + '] UTF8String]')
            error = lldb.SBError()
            text = process.ReadCStringFromMemory(value.GetValueAsUnsigned(), 8 * 1024 * 1024, error)
            if error.Fail():
                raise RuntimeError(error.GetCString())
            return json.loads(text)

        report["inventory"] = call("inventory")
        for query in config["queries"]:
            try:
                report["queries"].append(call('inspectPath:@' + json.dumps(query) + ' depth:' + str(config["depth"])))
            except Exception as exc:
                report["errors"].append({"path": query, "error": str(exc)})
    except Exception as exc:
        report["errors"].append({"error": str(exc)})
    finally:
        if process and process.IsValid() and process.GetState() not in (lldb.eStateExited, lldb.eStateDetached):
            error = process.Detach()
            report["detached"] = error.Success()
            if error.Fail():
                report["errors"].append({"detach": error.GetCString()})
        Path(config["output"]).write_text(json.dumps(report, indent=2) + "\n")
    result.AppendMessage(json.dumps({"output": config["output"], "queries": len(report["queries"]), "errors": report["errors"], "detached": report.get("detached", False)}))


def __lldb_init_module(debugger, internal_dict):
    debugger.HandleCommand("command script add -f lldb_driver.run hinge-probe")
