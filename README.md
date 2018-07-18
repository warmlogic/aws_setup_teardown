This is repo is inspired by the `setup` directory from the original [fast.ai course](https://github.com/fastai/courses). I've modified it significantly.

## Process to provision and set up new instance

### On your local machinne

1. Install `awscli`: `pip install -U awscli`
1. Configure `awscli`: `aws configure --profile my-profile-name`
1. `export` the appropriate environment variable: `export AWS_PROFILE=my-profile-name`
1. Run `setup_ec2_instance.sh` with the appropriate arguments
1. Add newly provisioned instance to your `~/.ssh/config`:
```
Host aws-my-instance
    Hostname ec2-ip.us-west-2.compute.amazonaws.com
    User ubuntu
    IdentityFile ~/.ssh/aws-key-my-instance.pem
    Port 22
    RemoteForward 52698 127.0.0.1:52698
```

### On the remote instance

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
1. Edit `~/.exports` as necessary (e.g., for `ANSARO_REPO_ROOT`)
1. `source ~/.bashrc`
1. Configure `awscli` (for S3 access): `aws configure --profile my-profile-name`
1. Configure jupyter notebook server
    1. `cd ~/github/warmlogic/jupyter_setup`
    1. `./jupyter_userdata.sh`
    1. Enter desired password
1. Clone other repos
    1. `mkdir -p ~/github/ansaro; cd ~/github/ansaro`
    1. `git clone git@github.com:ansaro/...`
1. Go to the home directory: `cd`
1. Start a tmux session: `tmux new -s jupyter`
1. Start a Jupyter Notebook server: `nb-server`
1. Detach from the tmux session: `C-b d`
1. Reattach to the tmux session: `tmux a -t jupyter`

### On your local machine

1. Browse to your Jupyter Notebook server's URL

# The rest of this is out of date

## List of files

| File                  | Purpose       |
| --------------------- | ------------- |
| `aws-alias.sh`        | Command aliases that make AWS server management easier. |
| `instal-gpu-azure.sh` | Installs required software on an Azure Ubuntu server. Instructions available on the [wiki](http://wiki.fast.ai/index.php/Azure_install). |
| `install-gpu.sh`      | Installs required software on an Ubuntu machine. Instructions available on the [wiki](http://wiki.fast.ai/index.php/Ubuntu_installation). |
| `setup_instance.sh`   | Sets up an AWS environment for use in the course including a server that has the required software installed. This script is used by `setup_p2.sh` or `setup_t2.sh`. You probably don't need to call it by itself. |
| `setup_p2.sh` and `setup_t2.sh` | Configure environment variables for use in `setup_instance.sh`. These files call `setup_instance.sh`, which does the actual work of setting up the AWS instance. |

## Setup Instructions

### AWS

If you haven't already, view the video at http://course.fast.ai/lessons/aws.html for the steps you need to complete before running these scripts. More information is available on the [wiki](http://wiki.fast.ai/index.php/AWS_install).
1. Decide if you will use a GPU server or a standard server. GPU servers process deep learning jobs faster than general purpose servers, but they cost more per hour. Compare server pricing at https://aws.amazon.com/ec2/pricing/on-demand/.
2. Download `setup_p2.sh` if you decided on the GPU server or `setup_t2.sh` for the general purpose server. Also download `setup_instance.sh`.
3. Run the command `bash setup_p2.sh` or `bash setup_t2.sh`, depending on the file you downloaded. Run the command locally from the folder where the files were downloaded. Running `bash setup_p2.sh` sets up a p2.xlarge GPU server. `bash setup_t2.sh` sets up a t2.xlarge general purpose server.
4. The script will set up the server you selected along with other pieces of AWS infrastructure. When it finishes, it will print out the command for connecting to the new server. The server is preloaded with the software required for the course.
5. Learn how to use the provided AWS aliases on the [wiki](http://wiki.fast.ai/index.php/AWS_install#Once_you_create_an_instance).

### Azure

Once you have an Azure GPU server set up, download and run the `install-gpu-azure.sh` script on that server. More instructions available on the [wiki](http://wiki.fast.ai/index.php/Azure_install).

### Ubuntu

Download and run the `install-gpu.sh` script to install required software on an Ubuntu machine. More instructions available on the [wiki](http://wiki.fast.ai/index.php/Ubuntu_installation).