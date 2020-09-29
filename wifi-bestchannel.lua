#!/usr/bin/lua
require "ubus"

function ubus.start()
    conn = ubus.connect()
    if not conn then error("Failed to connect to ubusd.") end
end
function ubus.stop()
    conn:close()
end
function get_mac_list(wlan)
    data = {}
    local status = conn:call("hostapd." .. wlan,"get_clients",{})
    if status ~= nil then
        for index,value in pairs(status) do
            if index == "clients" then
                for mac,client in pairs(value) do
                    table.insert(data,mac)
                    print("mac",mac)
                end
            end
        end
    end
    return data
end
function scan_channel_signal(wlan)
    data = {}
    local status = conn:call("iwinfo","scan",{device=wlan})
    if status ~= nil then
        for _,v in pairs(status) do
            for _,ap in pairs(v) do
                local bssid = ap["bssid"]
                data[bssid] = {}
                data[bssid]["ssid"] = ap["ssid"]
                data[bssid]["channel"] = ap["channel"]
                data[bssid]["signal"] = ap["signal"]
                data[bssid]["quality"] = ap["quality"]
                --print(bssid,data[bssid]["channel"],data[bssid]["signal"],data[bssid]["quality"],data[bssid]["ssid"])
            end
        end
    end
    return data
end
function table.match(tbl,value)
    for k,v in ipairs(tbl) do
        if v == value then
            return true,k
        end
    end
    return false,nil
end
function find_best_channel_24g(ap,white_list,best_signal)
    local max_signal = -110
    local min_count = 0
    local min_channel = 0
    local count_channel = {0,0,0,0,0,0,0,0,0,0,0,0,0}
    local main_channel = {1,6,11,13}
    for bssid,value in pairs(ap) do
        if not table.match(white_list,bssid) then 
            --print(bssid,value["channel"],value["signal"],value["quality"],value["ssid"])
            if value["signal"] > max_signal then
                max_signal = value["signal"]
            end
        else
            --print(bssid,value["channel"],value["signal"],value["quality"],value["ssid"],"\t* White list *")
        end
    end
    if max_signal < best_signal then max_signal = best_signal end
    for bssid,value in pairs(ap) do
        if value["signal"] <= max_signal and value["signal"] >= max_signal - 10 then
            count_channel[value["channel"]] = count_channel[value["channel"]] + 1
        end
    end
    --邻频干扰，纳入评测，可删除
    count_channel[1] = count_channel[1] + count_channel[2]
    count_channel[6] = count_channel[5] + count_channel[6] + count_channel[7]
    count_channel[11] = count_channel[10] + count_channel[11] + count_channel[12]
    count_channel[13] = count_channel[12] + count_channel[13]
    --邻频干扰，纳入评测，可删除
    min_count = count_channel[1]
    min_channel = 1
    for _,v in pairs(main_channel) do
        if count_channel[v] < min_count then
            min_count = count_channel[v]
            min_channel = v
        end
    end
    return min_channel
end
function get_current_channel(wlan)
    local status = conn:call("iwinfo","info",{device=wlan})
    if status ~= nil then
        return status["channel"]
    else 
        return nil
    end    
end
function switch_channel_24g(wlan,channel_num)
    local channel = {2412,2417,2422,2427,2432,2437,2442,2447,2452,2457,2462,2467,2472}
    local status = conn:call("hostapd." .. wlan,"switch_chan",{freq=channel[channel_num]})
    if status ~= nil then return true else return false end    
end
--如果不是在路由器上运行，可以将路由器的MAC地址，纳入white list，则路由器信号不会纳入对比范围
white_list={"00:00:00:00:00:00"}    
ubus.start()
wlan = "wlan0"
get_current_channel(wlan)
ap_signal = scan_channel_signal(wlan)
min_channel = find_best_channel_24g(ap_signal,white_list,-50)
last_channel = get_current_channel(wlan)
switch_channel_24g(wlan,min_channel)
print("[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] Change channel ".. last_channel .." to " .. min_channel )
ubus.stop()
