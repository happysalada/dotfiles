apt-get update
apt-get upgrade -y
# monitor login attemps and ban bad actors
apt-get install fail2ban

# add a deploy user
useradd deploy
mkdir /home/deploy
mkdir /home/deploy/.ssh
chmod 700 /home/deploy/.ssh

# add your key to they authorized keys
vim /home/deploy/.ssh/authorized_keys

chmod 400 /home/deploy/.ssh/authorized_keys
chown deploy:deploy /home/deploy -R

# lock down ssh
vim /etc/ssh/sshd_config
# add the following
# PermitRootLogin no
# PasswordAuthentication no

# in the future when having set up a vpn, use
# AllowUsers deploy@(your-ip) deploy@(another-ip-if-any)


# enable security upgrades
apt-get install unattended-upgrades

vim /etc/apt/apt.conf.d/10periodic
# add the following
# APT::Periodic::Update-Package-Lists "1";
# APT::Periodic::Download-Upgradeable-Packages "1";
# APT::Periodic::AutocleanInterval "7";
# APT::Periodic::Unattended-Upgrade "1";
vim /etc/apt/apt.conf.d/50unattended-upgrades
# add the following
# Unattended-Upgrade::Allowed-Origins {
#         "Ubuntu lucid-security";
# //      "Ubuntu lucid-updates";
# };

# add logwatch
apt-get install logwatch

vim /etc/cron.daily/00logwatch
# add the following
# /usr/sbin/logwatch --output mail --mailto raphael.megzari@gmail.com --detail high

# add ctop
sudo wget https://github.com/bcicen/ctop/releases/download/v0.7.1/ctop-0.7.1-linux-amd64 -O /usr/local/bin/ctop
sudo chmod +x /usr/local/bin/ctop

# add exa
apt-get install exa

# https://plusbryan.com/my-first-5-minutes-on-a-server-or-essential-security-for-linux-servers
