#!/bin/bash
echo 'STARTING POST UPDATE'
echo $(printenv)

# Bugfix for revert on first update. 0.0.7 had a bug in update.sh where the companion directory was not copied correctly (no -r option)
# Do it the right way here so we can revert if
cd $HOME/companion
WAS_0_0_7=$(git rev-list --count revert-point...0.0.7)
if [ $WAS_0_0_7 == 0 ]; then
    echo '0.0.7 update, repairing fall-back...'
    cp -r $HOME/companion $HOME/.companion
    cd $HOME/.companion
    git reset --hard 0.0.7
fi

cd $HOME/companion/br-webui

if ! npm list nodegit 2>&1 | grep -q nodegit@0.18.3; then
    echo 'Fetching nodegit packages for raspberry pi...'
    wget --timeout=15 --tries=2 https://s3.amazonaws.com/downloads.bluerobotics.com/Pi/dependencies/nodegit/nodegit_required_modules.zip -O /tmp/nodegit_required_modules.zip
    if [ $? -ne 0 ] # If "wget" failed:
    then
        echo 'Failed to retrieve nodegit packages; Aborting update'
        echo 'Rebooting to repair installation, this will take a few minutes'
        echo 'Please DO NOT REMOVE POWER FROM THE ROV! (until QGC makes a connection again)'
        sleep 0.1
        sudo reboot
    fi

    echo 'Extracting prebuilt packages...'
    unzip -q /tmp/nodegit_required_modules.zip -d ~/companion/br-webui/node_modules/
fi

# TODO prune unused npm modules here

echo 'run npm install'
npm install
if [ $? -ne 0 ] # If "npm install" failed:
then
    echo 'Failed to install required npm modules; Aborting update'
        echo 'Rebooting to repair installation, this will take a few minutes'
        echo 'Please DO NOT REMOVE POWER FROM THE ROV! (until QGC makes a connection again)'
    sleep 0.1
    sudo reboot
fi

cd $HOME/companion

echo 'Updating submodules...'
git submodule init && git submodule sync
if [ $? -ne 0 ] # If either "git submodule" failed:
then
    echo 'Failed to update submodules; Aborting update'
        echo 'Rebooting to repair installation, this will take a few minutes'
        echo 'Please DO NOT REMOVE POWER FROM THE ROV! (until QGC makes a connection again)'
    sleep 0.1
    sudo reboot
fi

# https://git-scm.com/docs/git-submodule#git-submodule-status--cached--recursive--ltpathgt82308203

echo 'Checking mavlink status...'
MAVLINK_STATUS=$(git submodule status | grep mavlink | head -c 1)
if [[ ! -z $MAVLINK_STATUS && ($MAVLINK_STATUS == '+' || $MAVLINK_STATUS == '-') ]]; then
    # Remove old mavlink directory if it exists
    [ -d ~/mavlink ] && sudo rm -rf ~/mavlink
    echo 'mavlink needs update.'
    git submodule update --recursive --init -f submodules/mavlink
    if [ $? -ne 0 ] # If mavlink submodule update failed:
    then
        echo 'Failed to update mavlink submodule; Aborting update'
        echo 'Rebooting to repair installation, this will take a few minutes'
        echo 'Please DO NOT REMOVE POWER FROM THE ROV! (until QGC makes a connection again)'
        sleep 0.1
        sudo reboot
    fi

    echo 'Installing mavlink...'
    cd $HOME/companion/submodules/mavlink/pymavlink
    sudo python setup.py build install
    if [ $? -ne 0 ] # If mavlink installation update failed:
    then
        echo 'Failed to install mavlink; Aborting update'
        echo 'Rebooting to repair installation, this will take a few minutes'
        echo 'Please DO NOT REMOVE POWER FROM THE ROV! (until QGC makes a connection again)'
        sleep 0.1
        sudo reboot
    fi
else
    echo 'mavlink is up to date.'
fi

cd $HOME/companion

echo 'Checking MAVProxy status...'
MAVPROXY_STATUS=$(git submodule status | grep MAVProxy | head -c 1)
if [[ ! -z $MAVPROXY_STATUS && ($MAVPROXY_STATUS == '+' || $MAVPROXY_STATUS == '-') ]]; then
    echo 'MAVProxy needs update.'
    git submodule update --recursive -f submodules/MAVProxy
    if [ $? -ne 0 ] # If MAVProxy submodule update failed:
    then
        echo 'Failed to update MAVProxy submodule; Aborting update'
        echo 'Rebooting to repair installation, this will take a few minutes'
        echo 'Please DO NOT REMOVE POWER FROM THE ROV! (until QGC makes a connection again)'
        sleep 0.1
        sudo reboot
    fi

    echo 'Installing MAVProxy...'
    cd $HOME/companion/submodules/MAVProxy
    sudo python setup.py build install
    if [ $? -ne 0 ] # If MAVProxy installation update failed:
    then
        echo 'Failed to install MAVProxy; Aborting update'
        echo 'Rebooting to repair installation, this will take a few minutes'
        echo 'Please DO NOT REMOVE POWER FROM THE ROV! (until QGC makes a connection again)'
        sleep 0.1
        sudo reboot
    fi
else
    echo 'MAVProxy is up to date.'
fi

echo 'checking for github in known_hosts'

# Check for github key in known_hosts
if ! ssh-keygen -H -F github.com; then
    mkdir ~/.ssh

    # Get gihub public key
    ssh-keyscan -t rsa -H github.com > /tmp/githost

    # Verify fingerprint
    if ssh-keygen -lf /tmp/githost | grep -q 16:27:ac:a5:76:28:2d:36:63:1b:56:4d:eb:df:a6:48; then
        # Add to known_hosts
        cat /tmp/githost >> ~/.ssh/known_hosts
    fi
fi

cd /home/pi/companion
echo 'Checking ping-python status...'
PING_STATUS=$(git submodule status | grep ping-python | head -c 1)
if [[ ! -z $PING_STATUS && ($PING_STATUS == '+' || $PING_STATUS == '-') ]]; then
    echo 'ping-python needs update.'
    git submodule update --recursive -f submodules/ping-python
    echo 'Installing ping-python...'
    cd /home/pi/companion/submodules/ping-python
    sudo python setup.py build install
    if [ $? -ne 0 ] # If "pip install ping-python" failed:
    then
        echo 'Failed to install ping-python; Aborting update'
        echo 'Rebooting to repair installation, this will take a few minutes'
        echo 'Please DO NOT REMOVE POWER FROM THE ROV! (until QGC makes a connection again)'
        sleep 0.1
        sudo reboot
    fi
else
    echo 'ping-python is up to date.'
fi

# install pynmea2 if neccessary
if pip list | grep pynmea2; then
    echo 'pynmea2 already installed'
else
    echo 'installing pynmea2...'
    sudo pip install pynmea2
    if [ $? -ne 0 ] # If "pip install pynmea2" failed:
    then
        echo 'Failed to install pynmea2; Aborting update'
        echo 'Rebooting to repair installation, this will take a few minutes'
        echo 'Please DO NOT REMOVE POWER FROM THE ROV! (until QGC makes a connection again)'
        sleep 0.1
        sudo reboot
    fi
fi

# install grequests if neccessary
if pip list | grep grequests; then
    echo 'grequests already installed'
else
    echo 'Fetching grequests packages for raspberry pi...'
    wget --timeout=15 --tries=2 https://s3.amazonaws.com/downloads.bluerobotics.com/Pi/dependencies/grequests/grequests.zip -O /tmp/grequests.zip
    if [ $? -ne 0 ] # If "wget" failed:
    then
        echo 'Failed to retrieve grequests packages; Aborting update'
        echo 'Rebooting to repair installation, this will take a few minutes'
        echo 'Please DO NOT REMOVE POWER FROM THE ROV! (until QGC makes a connection again)'
        sleep 0.1
        sudo reboot
    fi
    echo 'Extracting prebuilt packages...'
    sudo unzip -q -o /tmp/grequests.zip -d /
    echo 'installing grequests...'
    sudo pip install grequests
    if [ $? -ne 0 ] # If "pip install grequests" failed:
    then
        echo 'Failed to install grequests; Aborting update'
        echo 'Rebooting to repair installation, this will take a few minutes'
        echo 'Please DO NOT REMOVE POWER FROM THE ROV! (until QGC makes a connection again)'
        sleep 0.1
        sudo reboot
    fi
fi

# copy default parameters if neccessary
cd $HOME/companion/params

for default_param_file in *; do
    if [[ $default_param_file == *".param.default" ]]; then
        param_file="$HOME/"$(echo $default_param_file | sed "s/.default//")
        if [ ! -e "$param_file" ]; then
            cp $default_param_file $param_file
        fi
    fi
done

# change the pi user password to 'bluerobotics' instead of the default 'raspberry'
PRE_0_0_8=$(( git rev-list --count --left-right 0.0.8...revert-point || echo 0 ) | cut -f1)
if (( $PRE_0_0_8 > 0 )); then
    echo "changing default password to 'companion'..."
    echo "pi:companion" | sudo chpasswd
fi

# We need to load bcm v4l2 driver in case Raspberry Pi camera is in use
PRE_0_0_11=$(( git rev-list --count --left-right 0.0.11...revert-point || echo 0 ) | cut -f1)
if (( $PRE_0_0_11 > 0 )); then
    echo "restarting video stream"
    ~/companion/scripts/start_video.sh $(cat ~/companion/params/vidformat.param.default)
fi

# add local repo as a remote so it will show up in webui
cd ~/companion
if ! git remote | grep -q local; then
    echo 'Adding local reference'
    git remote add local ~/companion
fi

#Install isc-dhcp-server
cd $HOME/companion
echo "Checking for isc-dhcp-server..."
while true
do
    if dpkg-query -W -f='${Status} ${Version}' isc-dhcp-server | grep 4.3; then
        echo "Already installed"
        sudo dpkg --configure -a
        break
    else
        echo "Installing isc-dhcp-server"
        sudo apt-get update --yes
        sudo apt-get install isc-dhcp-server=4.3.* --yes
        sudo dpkg --configure -a
        #Copy network configuration files from Companion directory to respective configuration directories
        sudo cp /home/pi/companion/eth0-config /etc/network/interfaces.d/
        sudo cp /home/pi/companion/interfaces /etc/network/
        cp /home/pi/companion/dhcp-server-conf /home/pi
        cp /home/pi/companion/dhcp-server-defaults /home/pi 

        #Source configuration for dhcp server in the default configuration files
        sudo sh -c "echo 'include \"/home/pi/dhcp-server-conf\";' >> /etc/dhcp/dhcpd.conf"
        sudo sh -c "echo '. /home/pi/dhcp-server-defaults' >> /etc/default/isc-dhcp-server"

        #Copy mapping script from companion directory to home directory
        cp /home/pi/companion/eth0-mapping-config.sh /home/pi

        #Copy network configuration information to network-conf
        cp /home/pi/companion/network-conf /home/pi
        echo "isc-dhcp-server installed"
    fi
done

#Delete ip address if present from /boot/cmdline.txt
# e.g. sed command removes any ip address with any combination of digits [0-9] between decimal points
sudo sed -i -e 's/\s*ip=[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*//' /boot/cmdline.txt

sudo sed -i '\%stopscreens%d' ~/.bash_aliases
echo "alias stopscreens=\"screen -ls | grep Detached | cut -d. -f1 | awk '{print \$1}' | xargs kill\"" >> ~/.bash_aliases

source ~/.bashrc

echo 'Update Complete, refresh your browser'

sleep 0.1

sudo -H -u pi echo 'quit webui' >> $HOME/.update_log
screen -X -S webui quit

sudo -H -u pi echo 'restart webui' >> $HOME/.update_log
sudo -H -u pi screen -dm -S webui $HOME/companion/scripts/start_webui.sh

sudo -H -u pi echo 'removing lock' >> $HOME/.update_log
rm -f $HOME/.updating
