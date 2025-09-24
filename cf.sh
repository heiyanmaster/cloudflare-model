#!/bin/bash

# 确保 jq 已安装
if ! command -v jq &>/dev/null; then
  echo "❌ jq 未安装，请先安装 jq"
  exit 1
fi

# 清空现有规则
iptables -F
iptables -X
ip6tables -F
ip6tables -X

# 默认策略：禁入，放出
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

ip6tables -P INPUT DROP
ip6tables -P FORWARD DROP
ip6tables -P OUTPUT ACCEPT

# 本地回环
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

ip6tables -A INPUT -i lo -j ACCEPT
ip6tables -A OUTPUT -o lo -j ACCEPT

# 已建立的连接
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
ip6tables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# 放行 SSH
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
ip6tables -A INPUT -p tcp --dport 22 -j ACCEPT

# ⚡ 始终放行 27769 端口（宝塔面板）
iptables -A INPUT -p tcp --dport 27769 -j ACCEPT
ip6tables -A INPUT -p tcp --dport 27769 -j ACCEPT

# 下载 Cloudflare IP 段
CF_API="https://api.cloudflare.com/client/v4/ips"
CF_IPV4=$(curl -s "$CF_API" | jq -r '.result.ipv4_cidrs[]')
CF_IPV6=$(curl -s "$CF_API" | jq -r '.result.ipv6_cidrs[]')

# 仅允许 Cloudflare 访问 80/443
for ip in $CF_IPV4; do
  iptables -A INPUT -p tcp -s "$ip" --dport 80 -j ACCEPT
  iptables -A INPUT -p tcp -s "$ip" --dport 443 -j ACCEPT
done

for ip in $CF_IPV6; do
  ip6tables -A INPUT -p tcp -s "$ip" --dport 80 -j ACCEPT
  ip6tables -A INPUT -p tcp -s "$ip" --dport 443 -j ACCEPT
done

# 记录并丢弃
iptables -A INPUT -j LOG --log-prefix "iptables-drop: " --log-level 4
ip6tables -A INPUT -j LOG --log-prefix "ip6tables-drop: " --log-level 4

# 保存
mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6

echo "✅ 已切换为严格模式：仅允许 Cloudflare 访问 80/443，27769 端口始终放行，其它一律丢弃"
