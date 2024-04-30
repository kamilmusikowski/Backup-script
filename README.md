Backup Script
Bash script for data backup from remote to local directory. Intended to use with cron.

Features
- Performs mirror backup from remote host using `rsync` over SSH. 
- Creates compressed archives using `tar`.
- Implements a retention policy, deleting old archives.
- Provides logging and mail notifications.

Prerequisites
- Configured SSH keys for login from the script's host to the remote server.
- The `mail` command ready to use.
- Configured config file.
- Preferably, cron setup.