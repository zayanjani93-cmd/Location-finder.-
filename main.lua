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

-- Local version ko properly read karne ka function
local function getLocalVersion()
    local f = io.open(VERSION_FILE, "r")
    if f then
        local content = f:read("*a") or ""
        f:close()
        -- Trim karo aur sirf first line lo
        content = content:gsub("^%s*(.-)%s*$", "%1")
        -- Newlines aur extra spaces hatao
        content = content:match("([^\r\n]+)") or content
        content = content:gsub("%s+$", "")
        content = content:gsub("^%s+", "")
        
        if content == "" then
            return "1.0"
        end
        return content
    end
    return "1.0"
end

local CURRENT_VERSION = getLocalVersion()

-- Debug ke liye print statement
print("Local Version: " .. tostring(CURRENT_VERSION))

_G.checkLocationUpdate = function()
    -- Silent update check without internet connectivity errors
    local function safeUpdateCheck()
        -- First check if internet is available
        local cm = ctx.getSystemService(Context.CONNECTIVITY_SERVICE)
        local activeNetwork = cm.getActiveNetworkInfo()
        local isConnected = activeNetwork ~= nil and activeNetwork.isConnectedOrConnecting()
        
        if not isConnected then
            print("No internet connection, skipping update check")
            return -- Internet nahi hai, silently skip karein
        end
        
        print("Internet available, checking for updates...")
        
        -- Version file fetch with timeout
        Http.get(GITHUB_URL .. "version.txt", {timeout=10000}, function(code, onlineV, headers)
            print("Update check response code: " .. tostring(code))
            
            if code == 200 and onlineV then
                -- Online version ko properly clean karo
                local online_version = tostring(onlineV)
                online_version = online_version:gsub("^%s*(.-)%s*$", "%1")
                online_version = online_version:match("([^\r\n]+)") or online_version
                online_version = online_version:gsub("%s+$", "")
                online_version = online_version:gsub("^%s+", "")
                
                print("Online Version: " .. online_version)
                print("Current Version: " .. CURRENT_VERSION)
                
                -- Compare karo
                if online_version ~= CURRENT_VERSION then
                    print("New version available: " .. online_version .. " (current: " .. CURRENT_VERSION .. ")")
                    
                    service.handler.postDelayed(Runnable({
                        run = function()
                            -- Use AlertDialog.Builder instead of LuaDialog for better compatibility
                            local AlertDialogBuilder = luajava.bindClass("android.app.AlertDialog$Builder")
                            local builder = AlertDialogBuilder(ctx)
                            builder.setTitle("📍 Update Available")
                            builder.setMessage("Location Finder ka naya version ("..online_version..") available hai!\n\nCurrent: "..CURRENT_VERSION.."\nNew: "..online_version.."\n\nUpdate karein?")
                            
                            builder.setPositiveButton("✅ Update Now", {
                                onClick = function(dialog, which)
                                    dialog.dismiss()
                                    service.speak("Update download ho rahi hai...")
                                    
                                    -- Download new main.lua
                                    Http.get(GITHUB_URL .. "main.lua", {timeout=15000}, function(c, content, h)
                                        print("Download response code: " .. tostring(c))
                                        
                                        if c == 200 and content and #content > 1000 then
                                            -- Pehle backup banao
                                            local backup_path = PLUGIN_PATH .. ".backup"
                                            os.execute("cp \"" .. PLUGIN_PATH .. "\" \"" .. backup_path .. "\"")
                                            
                                            -- New file likho
                                            local f = io.open(PLUGIN_PATH, "w")
                                            if f then 
                                                f:write(content) 
                                                f:close()
                                                print("Main.lua updated successfully")
                                            end
                                            
                                            -- Version file update karo
                                            local vf = io.open(VERSION_FILE, "w")
                                            if vf then 
                                                vf:write(online_version) 
                                                vf:close()
                                                print("Version file updated to: " .. online_version)
                                            end
                                            
                                            service.speak("Update successful! App restart ho rahi hai...")
                                            
                                            -- Restart the plugin
                                            service.handler.postDelayed(Runnable({
                                                run = function()
                                                    -- Clear any cached data
                                                    package.loaded[PLUGIN_PATH] = nil
                                                    -- Relaunch the plugin
                                                    service.click({{"Location finder. ", 1}})
                                                end
                                            }), 2000)
                                            
                                        else
                                            print("Download failed or content too short")
                                            service.speak("Update download nahi ho saki. Internet check karein.")
                                        end
                                    end)
                                end
                            })
                            
                            builder.setNegativeButton("⏰ Later", {
                                onClick = function(dialog, which)
                                    dialog.dismiss()
                                end
                            })
                            
                            builder.setNeutralButton("❌ Skip This Version", {
                                onClick = function(dialog, which)
                                    dialog.dismiss()
                                    -- Skip karne ke liye current version ko online version ke equal set kardo
                                    local vf = io.open(VERSION_FILE, "w")
                                    if vf then 
                                        vf:write(online_version) 
                                        vf:close()
                                    end
                                    service.speak("This version skipped. You won't be notified until next update.")
                                end
                            })
                            
                            local dlg = builder.create()
                            -- Set dialog type for overlay
                            pcall(function()
                                dlg.getWindow().setType(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY)
                            end)
                            dlg.show()
                        end
                    }), 500)
                    
                else
                    print("Already up to date")
                end
            else
                print("Failed to fetch version file. Code: " .. tostring(code))
            end
        end)
    end
    
    -- Safely try update check
    local ok, err = pcall(function()
        -- Thodi der baad check shuru karein (app load hone ke baad)
        service.handler.postDelayed(Runnable({
            run = function()
                safeUpdateCheck()
            end
        }), 3000)
    end)
    
    if not ok then
        print("Update check error: " .. tostring(err))
    end
end

-- [[ SECTION 2: MAIN APPLICATION LOGIC ]]
local ctx = service or this or activity
local pref = ctx.getSharedPreferences("location_plugin_prefs", 0)

-- Baaki ka sab code EXACTLY WAISA HI RAHEGA jaise aapka original code tha
-- Sirf UPDATE SECTION ko replace karna hai

-- ... (Yahan se baaki ka poora code EXACTLY copy paste karna) ...
-- Main location finder ka code jo aapne diya hai wo yahan paste karna
-- Bas ensure karna ke yahan se neeche ka code change na ho

local function start_app()
    _G.checkLocationUpdate()  -- Improved update check
    init_tts()
    show_main_ui()
end

start_app()
return true