#!/bin/sh -eux
# create default command-line environment profile for appdynamics cloud kickstart user.

# set default values for input environment variables if not set. -----------------------------------
user_name="${user_name:-}"                                      # user name.
user_group="${user_group:-}"                                    # user login group.
user_home="${user_home:-/home/$user_name}"                      # [optional] user home (defaults to '/home/user_name').
user_docker_profile="${user_docker_profile:-false}"             # [optional] user docker profile (defaults to 'false').
user_prompt_color="${user_prompt_color:-green}"                 # [optional] user prompt color (defaults to 'green').
                                                                #            valid colors are:
                                                                #              'black', 'blue', 'cyan', 'green', 'magenta', 'red', 'white', 'yellow'

# set default value for kickstart home environment variable if not set. ----------------------------
kickstart_home="${kickstart_home:-/opt/appd-cloud-kickstart}"   # [optional] kickstart home (defaults to '/opt/appd-cloud-kickstart').

# define usage function. ---------------------------------------------------------------------------
usage() {
  cat <<EOF
Usage:
  All inputs are defined by external environment variables.
  Script should be run with correct privilege for the given user name.
  Example:
    [root]# export user_name="user1"                            # user name.
    [root]# export user_group="group1"                          # user login group.
    [root]# export user_home="/home/user1"                      # [optional] user home (defaults to '/home/user_name').
    [root]# export user_docker_profile="true"                   # [optional] user docker profile (defaults to 'false').
    [root]# export user_prompt_color="yellow"                   # [optional] user prompt color (defaults to 'green').
                                                                #            valid colors:
                                                                #              'black', 'blue', 'cyan', 'green', 'magenta', 'red', 'white', 'yellow'
                                                                #
    [root]# export kickstart_home="/opt/appd-cloud-kickstart"   # [optional] kickstart home (defaults to '/opt/appd-cloud-kickstart').
    [root]# $0
EOF
}

# validate environment variables. ------------------------------------------------------------------
if [ -z "$user_name" ]; then
  echo "Error: 'user_name' environment variable not set."
  usage
  exit 1
fi

if [ -z "$user_group" ]; then
  echo "Error: 'user_group' environment variable not set."
  usage
  exit 1
fi

if [ -n "$user_prompt_color" ]; then
  case $user_prompt_color in
      black|blue|cyan|green|magenta|red|white|yellow)
        ;;
      *)
        echo "Error: invalid 'user_prompt_color'."
        usage
        exit 1
        ;;
  esac
fi

# create default environment profile for the user. -------------------------------------------------
if [ "$user_name" == "root" ]; then
  master_bashprofile="${kickstart_home}/provisioners/scripts/common/users/user-root-bash_profile.sh"
  master_bashrc="${kickstart_home}/provisioners/scripts/common/users/user-root-bashrc.sh"
  user_home="/root"                                         # override user home for 'root' user.
else
  master_bashprofile="${kickstart_home}/provisioners/scripts/common/users/user-ec2-user-bash_profile.sh"
  master_bashrc="${kickstart_home}/provisioners/scripts/common/users/user-ec2-user-bashrc.sh"
fi

# copy environment profiles to user home.
cd ${user_home}
cp -p .bash_profile .bash_profile.orig
cp -p .bashrc .bashrc.orig

cp -f ${master_bashprofile} .bash_profile
cp -f ${master_bashrc} .bashrc

# set user prompt color.
sed -i "s/{green}/{${user_prompt_color}}/g" .bashrc

# remove existing vim profile if it exists.
if [ -d ".vim" ]; then
  rm -Rf ./.vim
fi

cp -f ${kickstart_home}/provisioners/scripts/common/tools/vim-files.tar.gz .
tar -zxvf vim-files.tar.gz --no-same-owner --no-overwrite-dir
rm -f vim-files.tar.gz

chown -R ${user_name}:${user_group} .
chmod 644 .bash_profile .bashrc

# create docker profile for the user. --------------------------------------------------------------
if [ "$user_docker_profile" == "true" ] && [ "$user_name" != "root" ]; then
  # add user to the 'docker' group.
  usermod -aG docker ${user_name}

  # install docker completion for bash.
  dcompletion_release="18.09.0"
  dcompletion_binary=".docker-completion.sh"

  # download docker completion for bash from github.com.
  rm -f ${user_home}/${dcompletion_binary}
  curl --silent --location "https://github.com/docker/cli/raw/v${dcompletion_release}/contrib/completion/bash/docker" --output ${user_home}/${dcompletion_binary}
  chown -R ${user_name}:${user_group} ${user_home}/${dcompletion_binary}
  chmod 644 ${user_home}/${dcompletion_binary}

  # install docker compose completion for bash.
  dcrelease="1.23.2"
  dccompletion_binary=".docker-compose-completion.sh"

  # download docker completion for bash from github.com.
  rm -f ${user_home}/${dccompletion_binary}
  curl --silent --location "https://github.com/docker/compose/raw/${dcrelease}/contrib/completion/bash/docker-compose" --output ${user_home}/${dccompletion_binary}
  chown -R ${user_name}:${user_group} ${user_home}/${dccompletion_binary}
  chmod 644 ${user_home}/${dccompletion_binary}
fi
