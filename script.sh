# #!/bin/bash 
    echo I am provisioning script ...
    date > /etc/vagrant_provisioned_at
    username=$BOX_USER_NAME
    password=$BOX_USER_PASSWORD
    echo ********** setting hostname  ************
    sudo hostnamectl set-hostname $BOX_HOSTNAME
    echo ********** updating yum  ************
    if sudo grep -Fxq "18.192.40.85" /etc/hosts >/dev/null; then
      echo "host file is fine nothing to do"
    else
      echo "adding to /etc/host 18.192.40.85 mirrors.fedoraproject.org"  
      sudo echo "18.192.40.85 mirrors.fedoraproject.org" >> /etc/hosts
    fi    
   
    sudo subscription-manager register --username $REDHAT_USER_NAME --password $REDHAT_USER_PASS --auto-attach
    sudo yum update -y
    if id -nG "${username}" | grep -qw "wheel"; then
      echo ${username} belongs to wheel meaing can sudo
    else  
      echo Creating user ${username} with password ${password} and adding to sudoers
      adduser ${username} -G wheel
    #  passwd ${username} << EOD
    #  ${password}
    #  ${password}
    #  EOD
    #echo -e "${password}\${password}" | (sudo passwd ${username})
    echo "$username:$password" | sudo chpasswd
    fi
    
    echo ********** fixing sshd  ************
    case `sudo grep -Fx "${username}      ALL=(ALL) " "/etc/sudoers" >/dev/null; echo $?` in
      0)
        # code if found
        ;;
      1)
        # code if not found
        sudo echo "${username}      ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers
        sudo echo "sysadmin         ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers
        ;;
      *)
        # code if an error occurred
        echo "can't fix sudoers error is $?"
        ;;
    esac
    echo checking if new user is a sudoer
    sudo -u ${username} cat /etc/passwd

    sudo sed -i "s/.*AllowUsers.*/AllowUsers ${username}/g" /etc/ssh/sshd_config
    sudo sed -i "s/.*RSAAuthentication.*/RSAAuthentication yes/g" /etc/ssh/sshd_config
    sudo sed -i "s/.*PubkeyAuthentication.*/PubkeyAuthentication yes/g" /etc/ssh/sshd_config
    sudo sed -i "s/.*PasswordAuthentication.*/PasswordAuthentication yes/g" /etc/ssh/sshd_config
    sudo sed -i "s/.*AuthorizedKeysFile.*/AuthorizedKeysFile\t\.ssh\/authorized_keys/g" /etc/ssh/sshd_config
    sudo sed -i "s/.*PermitRootLogin.*/PermitRootLogin no/g" /etc/ssh/sshd_config
    sudo -u ${username} mkdir -p /home/${username}/.ssh
    sudo -u ${username} chmod 700 /home/${username}/.ssh
    FILE=/vagrant_data/${username}/.ssh/id_rsa.pub
    if test -f "$FILE"; then
      echo "$FILE exists. copying into .ssh"
      sudo cp /vagrant_data/${username}/.ssh/* /home/${username}/.ssh
    else
      echo "$FILE does NOT exists. generating keys in .ssh"
      sudo -u ${username} ssh-keygen -t rsa -b 2048 -N "" -f /home/${username}/.ssh/id_rsa
    fi
    sudo cat /home/${username}/.ssh/id_rsa.pub > /home/${username}/.ssh/authorized_keys
    sudo chmod 600 /home/${username}/.ssh/authorized_keys
    sudo chown ${username}:${username} /home/${username}/.ssh/authorized_keys
    sudo cp /vagrant_data/${username}/.bash_aliases /home/${username}/.bash_aliases
    sudo cp /vagrant_data/${username}/.bashrc /home/${username}/.bashrc
    sudo chown ${username}:${username} /home/${username}/.bashrc
    sudo chmod 700 /home/${username}/.bashrc
    sudo chown ${username}:${username} /home/${username}/.bash_aliases
    sudo chmod 700 /home/${username}/.bash_aliases
    echo provisioning ended restarting ssh
    service sshd restart
