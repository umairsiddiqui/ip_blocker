ip_blocker
===================


Yet another firewall script to block country IP addresses. Tested on FirewallD (v0.4.3), CentOS 7.

----------


Usage
-------------
```{r, engine='bash', count_lines}
 sudo ./ip_blocker.sh "list-of-countries-code"
 sudo ./ip_blocker.sh pw,cc,mx
```

ip_unblocker
===================


removes IP-sets and rich-language rules added by ip_blocker.

----------


Usage
-------------
```{r, engine='bash', count_lines}
sudo ./ip_unblocker.sh "list-of-countries-code"
-or-
sudo ./ip_unblocker.sh all 

sudo ./ip_unblocker.sh pw,cc,mx
```















P.S. I'm Groot

