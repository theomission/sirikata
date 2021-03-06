/*  Sirikata
 *  Breakpad.cpp
 *
 *  Copyright (c) 2011, Ewen Cheslack-Postava
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions are
 *  met:
 *  * Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *  * Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in
 *    the documentation and/or other materials provided with the
 *    distribution.
 *  * Neither the name of Sirikata nor the names of its contributors may
 *    be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
 * IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
 * OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <sirikata/core/util/Standard.hh>
#include <sirikata/core/service/Breakpad.hpp>

#include <sirikata/core/util/Platform.hpp>
#include <sirikata/core/options/CommonOptions.hpp>

#ifdef HAVE_BREAKPAD
#if SIRIKATA_PLATFORM == SIRIKATA_PLATFORM_WINDOWS
#include <client/windows/handler/exception_handler.h>
#elif SIRIKATA_PLATFORM == SIRIKATA_PLATFORM_LINUX
#include <client/linux/handler/exception_handler.h>
#endif
#endif // HAVE_BREAKPAD

#include <sirikata/core/util/Paths.hpp>
#include <boost/filesystem.hpp>

namespace Sirikata {
namespace Breakpad {

#ifdef HAVE_BREAKPAD

// Each implementation of ExceptionHandler and the setup are different enough
// that these are worth just completely separating. Each just needs to setup the
// exception handler. Currently, all should set it up to save minidumps to the
// current directory.

namespace {

// Get the path to the crash reporter based on this binary's location. The
// returned string can be precomputed, so you can prime this during safe
// execution (initialization) so no more work will be done after the crash
// occurs.
const String& getCrashReporterPath() {
    static String cr_full_path = "";

    if (!cr_full_path.empty()) return cr_full_path;

    String reporter_name =
#if SIRIKATA_DEBUG
      "crashreporter_d"
#else
      "crashreporter"
#endif
        ;
#if SIRIKATA_PLATFORM == SIRIKATA_PLATFORM_WINDOWS
    reporter_name = reporter_name + ".exe";
#endif

    String exe_path = Path::Get(Path::DIR_EXE_BUNDLE);
    if (exe_path.empty())
        cr_full_path = reporter_name;
    else
        cr_full_path = ( boost::filesystem::path(exe_path) / reporter_name ).string();

    return cr_full_path;
}

}

#if SIRIKATA_PLATFORM  == SIRIKATA_PLATFORM_WINDOWS
namespace {

static google_breakpad::ExceptionHandler* breakpad_handler = NULL;
static std::string breakpad_url;

std::string wchar_to_string(const wchar_t* orig) {
  size_t origsize = wcslen(orig) + 1;
  const size_t newsize = origsize;
  size_t convertedChars = 0;
  char* nstring = new char[newsize];
  wcstombs_s(&convertedChars, nstring, origsize, orig, _TRUNCATE);
  std::string res(nstring);
  delete nstring;
  return res;
}

// Convert to a wchar_t*
std::wstring str_to_wstring(const std::string& orig) {
    size_t origsize = orig.size() + 1;
    const size_t newsize = origsize;
    size_t convertedChars = 0;
    wchar_t* wcstring = new wchar_t[newsize];
    mbstowcs_s(&convertedChars, wcstring, origsize, orig.c_str(), _TRUNCATE);
    std::wstring res(wcstring);
    delete wcstring;
    return res;
}

bool finishedDump(const wchar_t* dump_path,
    const wchar_t* minidump_id,
    void* context,
    EXCEPTION_POINTERS* exinfo,
    MDRawAssertionInfo* assertion,
    bool succeeded) {
    printf("Finished breakpad dump at %s/%s.dmp: success %d\n", dump_path, minidump_id, succeeded ? 1 : -1);


// Only run the reporter in release mode. This is a decent heuristic --
// generally you'll only run the debug mode when you have a dev environment.
#if SIRIKATA_DEBUG
    return succeeded;
#else
    if (breakpad_url.empty()) return succeeded;

    STARTUPINFO info={sizeof(info)};
    PROCESS_INFORMATION processInfo;
    std::string cmd =
        getCrashReporterPath() + std::string(" ") +
        breakpad_url + std::string(" ") +
        wchar_to_string(dump_path) + std::string(" ") +
        wchar_to_string(minidump_id) + std::string(" ") +
        std::string(SIRIKATA_VERSION) + std::string(" ") +
        std::string(SIRIKATA_GIT_REVISION);
    CreateProcess(getCrashReporterPath().c_str(), (LPSTR)cmd.c_str(), NULL, NULL, TRUE, 0, NULL, NULL, &info, &processInfo);

    return succeeded;
#endif // SIRIKATA_DEBUG
}
}

// Must match crashreporter
static const wchar_t kPipeName[] = L"\\\\.\\pipe\\SirikataCrashServices";

void init() {
    if (breakpad_handler != NULL) return;

    // This is needed for CRT to not show dialog for invalid param
    // failures and instead let the code handle it.
    _CrtSetReportMode(_CRT_ASSERT, 0);

    // Prime the location of the crashreporter binary
    getCrashReporterPath();

    breakpad_url = GetOptionValue<String>(OPT_CRASHREPORT_URL);

    using namespace google_breakpad;

    // Setup info about this process
    static std::vector<CustomInfoEntry> custom_entries;
    std::wstring version = str_to_wstring(std::string(SIRIKATA_VERSION));
    std::wstring githash = str_to_wstring(std::string(SIRIKATA_GIT_REVISION));
    custom_entries.push_back(CustomInfoEntry(L"version", version.c_str()));
    custom_entries.push_back(CustomInfoEntry(L"githash", githash.c_str()));
    static CustomClientInfo custom_client_info;
    custom_client_info.entries = &custom_entries.front();
    custom_client_info.count = custom_entries.size();


    // Try to run the external minidump processing server

    STARTUPINFO info={sizeof(info)};
    PROCESS_INFORMATION processInfo;
    wchar_t* w_dump_path = L".\\";
    std::string cmd =
        getCrashReporterPath() + std::string(" ") +
        breakpad_url + std::string(" ") +
        wchar_to_string(w_dump_path);
    std::cout << "Dump process: " << cmd << std::endl;
    CreateProcess(getCrashReporterPath().c_str(), (LPSTR)cmd.c_str(), NULL, NULL, TRUE, 0, NULL, NULL, &info, &processInfo);
    // FIXME better way to make sure the reporter gets a chance to
    // start up?
    Sleep(250);

    // Finally instantiate the exception handler, which should connect
    // to the external process, or in the worst case, setup to handle
    // minidumps internally
    const wchar_t* pipe_name = kPipeName;
    breakpad_handler = new ExceptionHandler(w_dump_path,
        NULL,
        finishedDump,
        NULL,
        ExceptionHandler::HANDLER_ALL,
        MiniDumpNormal,
        pipe_name,
        &custom_client_info);

    if (!breakpad_handler->IsOutOfProcess())
        SILOG(breakpad, error, "Using in-process dump generation.");
}

#elif SIRIKATA_PLATFORM == SIRIKATA_PLATFORM_LINUX

namespace {

static google_breakpad::ExceptionHandler* breakpad_handler = NULL;
static std::string breakpad_url;

bool finishedDump(const google_breakpad::MinidumpDescriptor& descriptor,
    void* context,
    bool succeeded) {
    printf("Finished breakpad dump at %s: success %d\n", descriptor.path(), succeeded ? 1 : -1);

// Only run the reporter in release mode. This is a decent heuristic --
// generally you'll only run the debug mode when you have a dev environment.
#if SIRIKATA_DEBUG
    return succeeded;
#else
    // If no URL, just finish crashing after the dump.
    if (breakpad_url.empty()) return succeeded;

    // Because we need compatibility with the old version for now (since win32
    // is still using it) and this keeps the crashreporter code simpler, we need
    // to split the path into parts -- dump_path/minidump_id.dmp
    const char* dump_path = descriptor.directory().c_str();
    const char* minidump_id_start = descriptor.path() + strlen(dump_path) + strlen("/");
    int minidump_id_len = strlen(minidump_id_start) - strlen(".dmp");
    std::string minidump_id(minidump_id_start, minidump_id_len);

    // Fork and exec the crashreporter
    pid_t pID = fork();

    if (pID == 0) {
        execlp(getCrashReporterPath().c_str(), getCrashReporterPath().c_str(), breakpad_url.c_str(), dump_path, minidump_id.c_str(), SIRIKATA_VERSION, SIRIKATA_GIT_REVISION, (char*)NULL);
        // If crashreporter not in path, try current directory
        execl(getCrashReporterPath().c_str(), getCrashReporterPath().c_str(), breakpad_url.c_str(), dump_path, minidump_id.c_str(), SIRIKATA_VERSION, SIRIKATA_GIT_REVISION, (char*)NULL);
    }
    else if (pID < 0) {
        printf("Failed to fork crashreporter\n");
    }

    return succeeded;
#endif //SIRIKATA_DEBUG
}
}

void init() {
    if (breakpad_handler != NULL) return;

    // Prime the location of the crashreporter binary
    getCrashReporterPath();

    breakpad_url = GetOptionValue<String>(OPT_CRASHREPORT_URL);

    using namespace google_breakpad;
    breakpad_handler = new ExceptionHandler(MinidumpDescriptor("."), NULL, finishedDump, NULL, true, -1);
}

#elif SIRIKATA_PLATFORM == SIRIKATA_PLATFORM_MAC
// No mac support currently
void init() {
}

#endif

#else //def HAVE_BREAKPAD
// Dummy implementation
void init() {
}
#endif

} // namespace Breakpad
} // namespace Sirikata
