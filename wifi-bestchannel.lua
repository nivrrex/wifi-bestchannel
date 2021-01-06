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
function get_current_channel(wlan)
    local status = conn:call("iwinfo","info",{device=wlan})
    if status ~= nil then
        return status["channel"]
    else 
        return nil
    end    
end
function find_best_channel_24g(ap,white_list,best_signal,interval_value)
    local max_signal = -110
    local min_count = 0
    local min_channel = 0
    local count_channel = {0,0,0,0,0,0,0,0,0,0,0,0,0}
    local count_channel_adjacent = {0,0,0,0,0,0,0,0,0,0,0,0,0}
    --local main_channel = {1,6,11,13} --频点仅选择常用的1 6 11 13
    local main_channel = {1,2,3,4,5,6,7,8,9,10,11,13}  --频点仅选择全部的
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
        if value["signal"] <= max_signal and value["signal"] >= max_signal - interval_value then
            count_channel[value["channel"]] = count_channel[value["channel"]] + 1
        end
    end
    --邻频干扰，纳入评测，针对常用的1 6 11 13等频点
    --count_channel_adjacent[1] = count_channel[1] + count_channel[2]
    --count_channel_adjacent[6] = count_channel[5] + count_channel[6] + count_channel[7]
    --count_channel_adjacent[11] = count_channel[10] + count_channel[11] + count_channel[12]
    --count_channel_adjacent[13] = count_channel[12] + count_channel[13]
    --邻频干扰2，纳入评测，针对全部频点
    count_channel_adjacent[1] = count_channel[1] + count_channel[2] + count_channel[3]
    count_channel_adjacent[2] = count_channel[1] + count_channel[2] + count_channel[3] + count_channel[4]
    count_channel_adjacent[3] = count_channel[1] + count_channel[2] + count_channel[3] + count_channel[4] + count_channel[5]
    count_channel_adjacent[4] = count_channel[2] + count_channel[3] + count_channel[4] + count_channel[5] + count_channel[6]
    count_channel_adjacent[5] = count_channel[3] + count_channel[4] + count_channel[5] + count_channel[6] + count_channel[7]
    count_channel_adjacent[6] = count_channel[4] + count_channel[5] + count_channel[6] + count_channel[7] + count_channel[8]
    count_channel_adjacent[7] = count_channel[5] + count_channel[6] + count_channel[7] + count_channel[8] + count_channel[9]
    count_channel_adjacent[8] = count_channel[6] + count_channel[7] + count_channel[8] + count_channel[9] + count_channel[10]
    count_channel_adjacent[9] = count_channel[7] + count_channel[8] + count_channel[9] + count_channel[10] + count_channel[11]
    count_channel_adjacent[10] = count_channel[8] + count_channel[9] + count_channel[10] + count_channel[11]
    count_channel_adjacent[11] = count_channel[9] + count_channel[10] + count_channel[11] + count_channel[13]
    count_channel_adjacent[13] = count_channel[11] + count_channel[13]
    min_count = count_channel_adjacent[1]
    min_channel = 1
    for _,v in pairs(main_channel) do
        if count_channel_adjacent[v] < min_count then
            min_count = count_channel_adjacent[v]
            min_channel = v
        end
    end
    return min_channel
end
function find_best_channel_5g(ap,white_list,best_signal)
    local max_signal = -110
    local min_count = 0
    local min_channel = 0
    local count_channel = {}
    count_channel[36]=0
    count_channel[40]=0
    count_channel[44]=0
    count_channel[48]=0
    count_channel[149]=0
    count_channel[153]=0
    count_channel[157]=0
    count_channel[161]=0
    count_channel[165]=0
    --local main_channel = {36,40,44,48,149,153,157,161,165}
    local main_channel = {149,153,157,161,165}
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
    min_count = count_channel[149]
    min_channel = 149
    for _,v in pairs(main_channel) do
        if count_channel[v] < min_count then
            min_count = count_channel[v]
            min_channel = v
        end
    end
    return min_channel
end
function switch_channel_24g(wlan,channel_num)
    local channel = {2412,2417,2422,2427,2432,2437,2442,2447,2452,2457,2462,2467,2472}
    local status = conn:call("hostapd." .. wlan,"switch_chan",{freq=channel[channel_num],bandwidth=20,ht=true})
    if status ~= nil then return true else return false end
    --local status = os.execute("uci set wireless.radio0.channel=" .. channel_num .. " && uci commit wireless && wifi")
    --if status ~= 0 then return true else return false end    
end
function switch_channel_5g(wlan,channel_num)
    local channel ={}
    channel[36]=5180
    channel[40]=5200
    channel[44]=5220
    channel[48]=5240
    channel[149]=5745
    channel[153]=5765
    channel[157]=5785
    channel[161]=5805
    channel[165]=5825
    local status = conn:call("hostapd." .. wlan,"switch_chan",{freq=channel[channel_num],bandwidth=20,ht=true})
    if status ~= nil then return true else return false end    
    --local status = os.execute("uci set wireless.radio1.channel=" .. channel_num .. " && uci commit wireless && wifi")
    --if status ~= 0 then return true else return false end    
end
function arg_check(arg,check)
    if arg == nil then 
        return false 
    else
        if string.upper(arg) == string.upper(check) then
            return true
        end
    end
end
--如果不是在路由器上运行，可以将路由器的MAC地址，纳入white list，则路由器信号不会纳入对比范围
white_list={"00:00:00:00:00:00"}
signal_24g_check=-50
signal_5g_check=-60

ubus.start()
--增加命令行参数，arg[1]是all,2.4g,5g等三种设置，决定scan的频段
--arg[2]如果是true，则进行信道调整，否则不调整
if arg[1] == nil then arg[1] = "ALL" end
if arg_check(arg[1],"ALL") then 
    wlan = "wlan0"
    get_current_channel(wlan)
    ap_signal = scan_channel_signal(wlan)
    min_channel = find_best_channel_24g(ap_signal,white_list,signal_24g_check)
    last_channel = get_current_channel(wlan)
    if arg_check(arg[2],"TRUE") then
        switch_channel_24g(wlan,min_channel)
    end
    if last_channel == min_channel then
        print("[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] [2.4G] Best channel is also ".. last_channel)
    else
        print("[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] [2.4G] Change channel ".. last_channel .." to " .. min_channel )
    end
    
    wlan = "wlan1"
    get_current_channel(wlan)
    ap_signal = scan_channel_signal(wlan)
    min_channel = find_best_channel_5g(ap_signal,white_list,signal_5g_check)
    last_channel = get_current_channel(wlan)
    if arg_check(arg[2],"TRUE") then
        switch_channel_5g(wlan,min_channel)
    end
    if last_channel == min_channel then
        print("[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] [ 5G ] Best channel is also ".. last_channel)
    else
        print("[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] [ 5G ] Change channel ".. last_channel .." to " .. min_channel )
    end
elseif arg_check(arg[1],"2.4G") then 
    wlan = "wlan0"
    get_current_channel(wlan)
    ap_signal = scan_channel_signal(wlan)
    min_channel = find_best_channel_24g(ap_signal,white_list,signal_24g_check)
    last_channel = get_current_channel(wlan)
    if arg_check(arg[2],"TRUE") then
        switch_channel_24g(wlan,min_channel)
    end
    if last_channel == min_channel then
        print("[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] [2.4G] Best channel is also ".. last_channel)
    else
        print("[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] [2.4G] Change channel ".. last_channel .." to " .. min_channel )
    end
elseif arg_check(arg[1],"5G") then 
    wlan = "wlan1"
    get_current_channel(wlan)
    ap_signal = scan_channel_signal(wlan)
    min_channel = find_best_channel_5g(ap_signal,white_list,signal_5g_check)
    last_channel = get_current_channel(wlan)
    if arg_check(arg[2],"TRUE") then
        switch_channel_5g(wlan,min_channel)
    end
    if last_channel == min_channel then
        print("[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] [ 5G ] Best channel is also ".. last_channel)
    else
        print("[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] [ 5G ] Change channel ".. last_channel .." to " .. min_channel )
    end
end
ubus.stop()
