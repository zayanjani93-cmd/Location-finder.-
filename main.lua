require "import"
import "android.app.*"
import "android.content.*"
import "android.widget.*"
import "android.view.*"
import "android.location.*"
import "java.util.Locale"
import "java.util.Calendar"
import "java.text.SimpleDateFormat"
import "android.net.Uri"
import "android.graphics.Typeface"
import "android.text.TextWatcher"
import "android.content.ClipboardManager"
import "android.content.ClipData"
import "android.speech.tts.TextToSpeech"

-- [[ SECTION 1: MOMIN ASSISTANT UPDATE LOGIC - IMPROVED VERSION ]]
local PLUGIN_DIR = "/storage/emulated/0/解说/Plugins/Location finder. /"
local PLUGIN_PATH = PLUGIN_DIR .. "main.lua"
local VERSION_FILE = PLUGIN_DIR .. "version.txt"
local GITHUB_URL = "https://raw.githubusercontent.com/zayanjani93-cmd/Location-finder.-/main/"

-- Local version ko trim karne ka better function
local function getLocalVersion()
    local f = io.open(VERSION_FILE, "r")
    if f then
        local v = f:read("*a"):match("%S+") or "1.0"
        f:close()
        return v:gsub("%s+", "")
    end
    return "1.0"
end

local CURRENT_VERSION = getLocalVersion()

_G.checkLocationUpdate = function()
    -- Improved update check with better error handling
    local function safeUpdateCheck()
        -- Internet check with timeout
        local cm = ctx.getSystemService(Context.CONNECTIVITY_SERVICE)
        local activeNetwork = cm.getActiveNetworkInfo()
        local isConnected = activeNetwork ~= nil and activeNetwork.isConnectedOrConnecting()
        
        if not isConnected then
            -- Internet nahi hai, par koi error nahi show karna
            return
        end
        
        -- Version file fetch with timeout
        Http.get(GITHUB_URL .. "version.txt", {timeout=5000}, function(code, onlineV, headers)
            if code == 200 and onlineV and #onlineV > 0 then
                local v = tostring(onlineV):match("%S+") or "1.0"
                v = v:gsub("%s+", "")
                
                -- DEBUG: Print versions for testing
                print("Local version:", CURRENT_VERSION)
                print("Online version:", v)
                
                if v ~= CURRENT_VERSION then
                    -- 2 second delay for better UX
                    service.handler.postDelayed(Runnable({
                        run = function()
                            local AlertDialogBuilder = luajava.bindClass("android.app.AlertDialog$Builder")
                            local builder = AlertDialogBuilder(ctx)
                            builder.setTitle("Update Available")
                            builder.setMessage("Location Finder ka naya version ("..v..") available hai. Update karein?\n\nCurrent: "..CURRENT_VERSION.."\nNew: "..v)
                            
                            builder.setPositiveButton("Update Now", {
                                onClick = function(dialog, which)
                                    dialog.dismiss()
                                    service.speak("Update download ho rahi hai...")
                                    
                                    -- Download new main.lua
                                    Http.get(GITHUB_URL .. "main.lua", {timeout=10000}, function(c, content, h)
                                        if c == 200 and content and #content > 500 then
                                            -- Backup old file
                                            local backup_path = PLUGIN_PATH .. ".backup"
                                            os.execute("cp "..PLUGIN_PATH.." "..backup_path)
                                            
                                            -- Write new file
                                            local f = io.open(PLUGIN_PATH, "w")
                                            if f then 
                                                f:write(content) 
                                                f:close() 
                                            end
                                            
                                            -- Update version file
                                            local vf = io.open(VERSION_FILE, "w")
                                            if vf then 
                                                vf:write(v) 
                                                vf:close() 
                                            end
                                            
                                            service.speak("Update successful ho gayi hai. App restart ho rahi hai.")
                                            
                                            -- Restart the plugin
                                            service.handler.postDelayed(Runnable({
                                                run = function()
                                                    service.click({{"Location finder. ", 1}})
                                                end
                                            }), 1500)
                                        else
                                            service.speak("Update download nahi ho saki. Internet check karein.")
                                        end
                                    end)
                                end
                            })
                            
                            builder.setNegativeButton("Later", {
                                onClick = function(dialog, which)
                                    dialog.dismiss()
                                end
                            })
                            
                            local dlg = builder.create()
                            -- Set dialog type for overlay
                            pcall(function()
                                dlg.getWindow().setType(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY)
                            end)
                            dlg.show()
                        end
                    }), 2000)
                else
                    -- Versions same hain
                    print("Already up to date")
                end
            else
                -- Failed to fetch version file
                print("Failed to fetch version. Code:", code)
            end
        end)
    end
    
    -- Safely try update check in background
    local ok, err = pcall(function()
        -- 5 second delay se check shuru karein
        service.handler.postDelayed(Runnable({
            run = function()
                safeUpdateCheck()
            end
        }), 5000)
    end)
    
    if not ok then
        print("Update check error:", err)
    end
end

-- [[ SECTION 2: MAIN APPLICATION LOGIC ]]
-- ... (baaki ka code waisa hi rahega) ...

local function start_app()
    -- Update check ko pehle call karein
    _G.checkLocationUpdate()  
    init_tts()
    show_main_ui()
end

start_app()
return true