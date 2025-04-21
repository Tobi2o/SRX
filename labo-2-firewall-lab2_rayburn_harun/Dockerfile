FROM ubuntu

RUN apt update 
RUN apt install -y net-tools nftables iptables iputils-ping \
    iproute2 curl netcat nginx ssh nano traceroute vim lynx \
    tcpdump

RUN ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N "" -q
RUN cp /root/.ssh/id_ed25519.pub /root/.ssh/authorized_keys

# Wait forever
CMD tail -f /dev/null