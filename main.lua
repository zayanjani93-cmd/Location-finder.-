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

-- [[ SECTION 1: MOMIN ASSISTANT UPDATE LOGIC - FULLY REPLACED FROM 2ND CODE ]]
local PLUGIN_DIR = "/storage/emulated/0/解说/Plugins/Location finder. /"
local PLUGIN_PATH = PLUGIN_DIR .. "main.lua"
local VERSION_FILE = PLUGIN_DIR .. "version.txt"
local GITHUB_URL = "https://raw.githubusercontent.com/zayanjani93-cmd/Location-finder.-/main/"

local function getLocalVersion()
  local f = io.open(VERSION_FILE, "r")
  if f then
    local v = f:read("*a"):gsub("%s+", "")
    f:close()
    return v
  end
  return "1.0"
end

local CURRENT_VERSION = getLocalVersion()

_G.checkLocationUpdate = function()
  -- Silent update check from code 2
  local function safeUpdateCheck()
    local cm = ctx.getSystemService(Context.CONNECTIVITY_SERVICE)
    local activeNetwork = cm.getActiveNetworkInfo()
    local isConnected = activeNetwork ~= nil and activeNetwork.isConnectedOrConnecting()
    
    if not isConnected then
      return 
    end

    Http.get(GITHUB_URL .. "version.txt", function(code, onlineV)
      if code == 200 and onlineV then
        local v = tostring(onlineV):gsub("%s+", "")
        if v ~= CURRENT_VERSION then
          service.handler.postDelayed(Runnable({
            run = function()
              local dlg = LuaDialog(service or activity)
              dlg.setTitle("Update Available")
              dlg.setMessage("Location Finder ka naya version ("..v..") dastiyab hai. Update karein?")
              dlg.setButton("Update Now", function()
                dlg.dismiss()
                service.speak("Update download ho rahi hai...")
                Http.get(GITHUB_URL .. "main.lua", function(c, content)
                  if c == 200 and content and #content > 500 then
                    local f = io.open(PLUGIN_PATH, "w")
                    if f then f:write(content) f:close() end
                    local vf = io.open(VERSION_FILE, "w")
                    if vf then vf:write(v) vf:close() end
                    service.speak("Update mukammal ho gayi hai.")
                    service.handler.postDelayed(Runnable({
                      run = function() 
                        service.click({{"Location finder. ", 1}}) 
                      end
                    }), 1000)
                  end
                end)
              end)
              dlg.setButton2("Later", function() dlg.dismiss() end)
              dlg.show()
            end
          }), 100)
        end
      end
    end)
  end
  
  local ok, err = pcall(safeUpdateCheck)
end

-- [[ SECTION 2: MAIN APPLICATION LOGIC - FROM 1ST CODE ]]
local ctx = service or this or activity
local pref = ctx.getSharedPreferences("location_plugin_prefs", 0)

local function clear_all_data()
  pref.edit().clear().commit()
end

local tts = nil
local tts_initialized = false
local function init_tts()
  if tts == nil then
    tts = TextToSpeech(ctx, TextToSpeech.OnInitListener{
      onInit = function(status)
        if status == TextToSpeech.SUCCESS then
          tts_initialized = true
        end
      end
    })
  end
end

local function safe_speak(text)
  if tts_initialized and text and text ~= "" then
    tts.speak(tostring(text), TextToSpeech.QUEUE_FLUSH, nil, nil)
  end
end

local function get_saved_lang()
  local saved = pref.getString("last_saved_code", nil)
  if saved == nil then
    pref.edit().putString("last_saved_code", "en").commit()
    return "en"
  end
  return saved
end

local translations = {
  ur = {
    addr="پتہ", tehsil="تحصیل", zila="ضلع", province="صوبہ", country="ملک", 
    none="معلومات دستیاب نہیں", select_title="زبان منتخب کریں", 
    search_hint="تلاش کریں...", save_btn="محفوظ کریں", cancel_btn="کینسل",
    copy_btn="لوکیشن کاپی کریں", copy_msg="لوکیشن کاپی کر لی گئی ہے",
    morning="صبح بخیر", afternoon="دوپہر بخیر", evening="شام بخیر", night="شب بخیر",
    postal_code="ڈاک خانہ", locality="علاقہ", sub_locality="ذیلی علاقہ",
    coordinates="متناسقات",
    enable_gps="براہ کرم اپنی ڈیوائس کی سیٹنگز میں GPS یا نیٹ ورک لوکیشن سروسز کو فعال کریں۔",
    no_location="لوکیشن معلومات دستیاب نہیں",
    no_internet="انٹرنیٹ کنکشن نہیں ہے۔ لوکیشن پتہ لگانے کے لیے انٹرنیٹ کی ضرورت ہے۔",
    location_disabled="لوکیشن سروسز فعال نہیں ہیں۔ براہ کرم لوکیشن آن کریں۔",
    getting_location="نئی لوکیشن کی معلومات حاصل کی جا رہی ہیں...",
    internet_required="انٹرنیٹ کنکشن درکار ہے۔",
    refresh_btn="لوکیشن ریفریش کریں"
  },
  en = {
    addr="Address", tehsil="Tehsil", zila="District", province="Province", country="Country", 
    none="Not Available", select_title="Select Language", 
    search_hint="Search...", save_btn="Save", cancel_btn="Cancel",
    copy_btn="Copy Location", copy_msg="Location copied to clipboard",
    morning="Good Morning", afternoon="Good Afternoon", evening="Good Evening", night="Good Night",
    postal_code="Postal Code", locality="Locality", sub_locality="Sub Locality",
    coordinates="Coordinates",
    enable_gps="Please enable GPS or Network location services in your device settings.",
    no_location="Location information not available",
    no_internet="No internet connection. Internet is required for location address lookup.",
    location_disabled="Location services are not enabled. Please turn on location.",
    getting_location="Getting fresh location information...",
    internet_required="Internet connection required.",
    refresh_btn="Refresh Location"
  }
}

local function get_greeting(lang_code)
  local lang = translations[lang_code] or translations.en
  local calendar = Calendar.getInstance()
  local hour = calendar.get(Calendar.HOUR_OF_DAY)
  if hour >= 5 and hour < 12 then return lang.morning
  elseif hour >= 12 and hour < 17 then return lang.afternoon
  elseif hour >= 17 and hour < 21 then return lang.evening
  else return lang.night end
end

local function is_internet_available()
  local cm = ctx.getSystemService(Context.CONNECTIVITY_SERVICE)
  local activeNetwork = cm.getActiveNetworkInfo()
  return activeNetwork ~= nil and activeNetwork.isConnectedOrConnecting()
end

local function check_location_services()
  local lm = ctx.getSystemService(Context.LOCATION_SERVICE)
  if lm == nil then return false end
  local gps_enabled = false
  local network_enabled = false
  pcall(function()
    gps_enabled = lm.isProviderEnabled(LocationManager.GPS_PROVIDER)
    network_enabled = lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
  end)
  return gps_enabled or network_enabled
end

local function get_fresh_location_data(lang_code)
  local lang = translations[lang_code] or translations.en
  local result = {}
  if not is_internet_available() then
    table.insert(result, lang.no_internet)
    return table.concat(result, "\n")
  end
  if not check_location_services() then
    table.insert(result, lang.location_disabled)
    return table.concat(result, "\n")
  end
  table.insert(result, lang.getting_location)
  local success, location_data = pcall(function()
    local lm = ctx.getSystemService(Context.LOCATION_SERVICE)
    if lm == nil then return lang.no_location end
    local providers = {LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER}
    local best_loc = nil
    for _, provider in ipairs(providers) do
      local enabled = false
      pcall(function() enabled = lm.isProviderEnabled(provider) end)
      if enabled then
        local loc = nil
        pcall(function() loc = lm.getLastKnownLocation(provider) end)
        if loc then
          if best_loc == nil then best_loc = loc
          elseif loc.getTime() > best_loc.getTime() then best_loc = loc end
        end
      end
    end
    if best_loc == nil then return lang.no_location end
    local target_locale = Locale(lang_code)
    local geocoder_available = false
    pcall(function() geocoder_available = Geocoder.isPresent() end)
    if not geocoder_available then
      return string.format("%s: %.6f°N, %.6f°E", lang.coordinates, best_loc.getLatitude(), best_loc.getLongitude())
    end
    local addresses = nil
    pcall(function()
      local geocoder = Geocoder(ctx, target_locale)
      addresses = geocoder.getFromLocation(best_loc.getLatitude(), best_loc.getLongitude(), 1)
    end)
    result = {}
    if addresses and addresses.size() > 0 then
      local address = addresses.get(0)
      for i=0, 3 do
        local line = nil
        pcall(function() line = address.getAddressLine(i) end)
        if line and line ~= "" then
          if i == 0 then table.insert(result, string.format("%s: %s", lang.addr, line))
          else table.insert(result, line) end
        end
      end
      local fields = {
        {function() return address.getSubLocality() end, lang.sub_locality},
        {function() return address.getLocality() end, lang.locality},
        {function() return address.getSubAdminArea() end, lang.tehsil},
        {function() return address.getAdminArea() end, lang.province},
        {function() return address.getCountryName() end, lang.country},
        {function() return address.getPostalCode() end, lang.postal_code}
      }
      for _, field in ipairs(fields) do
        local value = nil
        pcall(function() value = field[1]() end)
        if value and value ~= "" then table.insert(result, string.format("%s: %s", field[2], value)) end
      end
      table.insert(result, string.format("%s: %.6f°N, %.6f°E", lang.coordinates, best_loc.getLatitude(), best_loc.getLongitude()))
    else
      table.insert(result, lang.none)
    end
    return table.concat(result, "\n")
  end)
  return success and location_data or lang.none
end

local current_loc_txt = nil
local function set_dialog_type(dialog)
  pcall(function() dialog.getWindow().setType(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY) end)
end

local show_main_ui
local current_main_dlg = nil

local function show_about()
  local dlg = AlertDialog.Builder(ctx).setTitle("Groups Information")
  .setMessage("Contact us to join our WhatsApp group Tech for V.I. Gaming Club and Tech for V.I. Technology group.")
  .setPositiveButton("Back", nil).create()
  set_dialog_type(dlg)
  dlg.show()
end

local function show_settings(parent_dlg)
  local current_lang = get_saved_lang()
  local ui = translations[current_lang] or translations.en
  local all_langs = {{name="English", code="en"}, {name="Urdu", code="ur"}}
  local dlg = AlertDialog.Builder(ctx).setTitle(ui.select_title).setNegativeButton(ui.cancel_btn, nil).create()
  local layout = LinearLayout(ctx)
  layout.setOrientation(LinearLayout.VERTICAL)
  local lv = ListView(ctx)
  local adapter = ArrayAdapter(ctx, android.R.layout.simple_list_item_single_choice)
  for _, lang in ipairs(all_langs) do adapter.add(lang.name) end
  lv.setAdapter(adapter)
  dlg.setView(layout)
  layout.addView(lv)
  dlg.setButton(DialogInterface.BUTTON_POSITIVE, ui.save_btn, {
    onClick = function()
      local pos = lv.getCheckedItemPosition()
      if pos >= 0 then
        pref.edit().putString("last_saved_code", all_langs[pos+1].code).commit()
        if parent_dlg then parent_dlg.dismiss() end
        dlg.dismiss()
        show_main_ui()
      end
    end
  })
  set_dialog_type(dlg)
  dlg.show()
end

show_main_ui = function()
  if current_main_dlg then current_main_dlg.dismiss() end
  local active_lang = get_saved_lang()
  local ui = translations[active_lang] or translations.en
  local greeting = get_greeting(active_lang)
  local loc_data = get_fresh_location_data(active_lang)
  
  local builder = AlertDialog.Builder(ctx).setTitle("Location Finder")
  local scroll = ScrollView(ctx)
  local main_layout = LinearLayout(ctx)
  main_layout.setOrientation(LinearLayout.VERTICAL)
  main_layout.setPadding(60, 50, 60, 50)
  
  local loc_txt = TextView(ctx)
  loc_txt.setText(greeting .. "\n\n" .. loc_data)
  loc_txt.setTextSize(17)
  main_layout.addView(loc_txt)
  current_loc_txt = loc_txt

  local refresh_btn = Button(ctx)
  refresh_btn.setText(ui.refresh_btn)
  refresh_btn.setOnClickListener(function()
    local new_data = get_fresh_location_data(active_lang)
    loc_txt.setText(greeting .. "\n\n" .. new_data)
    safe_speak(new_data)
  end)
  main_layout.addView(refresh_btn)

  local copy_btn = Button(ctx)
  copy_btn.setText(ui.copy_btn)
  copy_btn.setOnClickListener(function()
    local cm = ctx.getSystemService(Context.CLIPBOARD_SERVICE)
    cm.setPrimaryClip(ClipData.newPlainText("location", loc_txt.getText().toString()))
    safe_speak(ui.copy_msg)
  end)
  main_layout.addView(copy_btn)

  local settings_btn = Button(ctx)
  settings_btn.setText("Settings")
  settings_btn.setOnClickListener(function() show_settings(current_main_dlg) end)
  main_layout.addView(settings_btn)

  local exit_btn = Button(ctx)
  exit_btn.setText("Exit")
  exit_btn.setOnClickListener(function()
    clear_all_data()
    current_main_dlg.dismiss()
    if service then service.stopSelf() end
  end)
  main_layout.addView(exit_btn)

  scroll.addView(main_layout)
  builder.setView(scroll)
  current_main_dlg = builder.create()
  set_dialog_type(current_main_dlg)
  current_main_dlg.setCancelable(false)
  current_main_dlg.show()
  safe_speak(greeting .. ". " .. loc_data)
end

local function start_app()
  _G.checkLocationUpdate()
  init_tts()
  show_main_ui()
end

start_app()
return true
