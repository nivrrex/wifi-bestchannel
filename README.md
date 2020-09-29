# wifi-bestchannel
OpenWrt下 2.4G Wifi 最优信道选择，use lua and ubus

# 说明
1. 实现很简单，就是路由器 scan 附近的所有 2.4G wifi 信道，然后对比所有主要频段的信号强度，选择当中高强度信号最少的频段（干扰最小）的，进行选择
2. 如果附近最强的信号不超过 -50dbm ，则默认用 -50dbm 进行信道对比。 可以通过 find_best_channel_24g(ap_signal,white_list,-50) 进行调整
3. 默认使用 1 6 11 13 这几个主要频段，最终结果也是对比并采用这几个频段
4. 因为部分路由器采用了非标准频段，即非 1 6 11 13 频段，所以也将邻频干扰稍微考虑了下
5. 暂不考虑 5G 的自动选择频段

# 备注
很简单的算法，效果尚可，可以放在 crontab 中定时执行