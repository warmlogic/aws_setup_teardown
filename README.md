# `aws_setup_teardown` README

This is repo is inspired by the `setup` directory from the original [fast.ai course](https://github.com/fastai/courses). I've modified it significantly.

## Process to provision and set up new instance

### On your local machine

1. Install `awscli`: `pip install -U awscli`
1. Configure `awscli`: `aws configure --profile my-profile-name`
1. `export` the appropriate environment variable: `export AWS_PROFILE=my-profile-name`
1. Run `setup_ec2_instance.sh` with the appropriate arguments
1. Add newly provisioned instance to your `~/.ssh/config` (includes `RemoteForward` for remote editing with Sublime or VS Code):

```txt
Host aws-my-instance
    Hostname ec2-ip.us-west-2.compute.amazonaws.com
    User ubuntu
    IdentityFile ~/.ssh/aws-key-my-instance.pem
    Port 22
    RemoteForward 52698 127.0.0.1:52698
```

### Set up the remote instance

This includes installing my dotfiles, appropriate Linux packages, a conda Python environment for data science tasks, and configuring for AWS access.

1. SSH into the instance: `ssh aws-my-instance`
1. [Generate new ssh key](https://help.github.com/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent/): `ssh-keygen -t rsa -b 4096 -C "your_email@example.com"`
1. [Add public key to GitHub account settings](https://help.github.com/articles/adding-a-new-ssh-key-to-your-github-account/) [here](https://github.com/settings/keys): `less ~/.ssh/id_rsa.pub`
1. Clone setup repos:
    1. `mkdir -p ~/github/warmlogic; cd ~/github/warmlogic`
    1. `git clone git@github.com:warmlogic/dotfiles_linux.git`
    1. `git clone git@github.com:warmlogic/jupyter_setup.git`
1. Run scripts from `dotfiles_linux`
    1. `cd ~/github/warmlogic/dotfiles_linux`
    1. `./01-bootstrap.sh`
    1. `./03-ubuntu.sh`
    1. `./04-python.sh`
1. Edit `~/.exports` as necessary
1. `source ~/.bashrc`
1. Configure `awscli` (for S3, etc. access): `aws configure --profile my-profile-name`

#### Set up a Jupyter Notebook server

1. Configure a Jupyter Notebook server
    1. `cd ~/github/warmlogic/jupyter_setup`
    1. `./jupyter_userdata.sh`
    1. Enter desired password
1. Go to the home directory: `cd`
1. Start a `tmux` session: `tmux new -s jupyter`
1. Start a Jupyter Notebook server: `nb-server`
1. Detach from the `tmux` session: `C-b d`
1. Reattach to the `tmux` session: `tmux a -t jupyter`

### Access the Jupyter Notebook server on your local machine

1. Browse to your Jupyter Notebook server's URL
