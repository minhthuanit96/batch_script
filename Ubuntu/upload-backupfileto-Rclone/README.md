# UniFi Controller Backup and Rclone Upload Script

This script automates the process of backing up a UniFi Network Controller, uploading the backups to a remote storage provider using Rclone, and sending notifications to a Telegram channel.

## Features

-   **Automated Backups:** Automatically detects new UniFi backup files (`.unf`).
-   **Rclone Integration:** Securely uploads backups to any cloud storage provider supported by Rclone.
-   **Telegram Notifications:** Sends real-time notifications to a Telegram chat to monitor the backup status.
-   **Automated Cleanup:** Keeps the two newest backups and deletes older ones, both locally and on the remote storage, to save space.
-   **Logging:** Maintains a detailed log file for debugging and auditing purposes.
-   **Error Handling:** Exits immediately if any command fails and sends a failure notification.
-   **Easy Configuration:** All settings are managed through a simple `.env` file.

## Prerequisites

Before using this script, ensure you have the following tools installed on your system:

-   [Rclone](https://rclone.org/install/): For uploading files to remote storage.
-   [rsync](https://rsync.samba.org/): For efficiently syncing files.
-   [curl](https://curl.se/): For sending Telegram notifications.

You can check if these tools are installed by running:

```bash
command -v rclone
command -v rsync
command -v curl
```

## Configuration

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/your-username/your-repository.git
    cd your-repository
    ```

2.  **Create the configuration file:**
    Rename the `.env.txt` file to `.env` and customize the variables:
    ```bash
    mv .env.txt .env
    ```

3.  **Edit the `.env` file:**
    Open the `.env` file and set the following variables:

    -   `BACKUP_DIR`: The absolute path to the directory where the UniFi Controller saves its automatic backups (e.g., `/var/lib/unifi/backup/autobackup`).
    -   `UPLOAD_FOLDER`: A temporary local directory to stage the backups before uploading (e.g., `/home/user/unifi-backups`).
    -   `REMOTE_DIR`: The destination directory on your Rclone remote (e.g., `gdrive:UniFi-Backups`).
    -   `LOG_FILE`: The absolute path to the log file (e.g., `/var/log/unifi-backup.log`).
    -   `TELEGRAM_BOT_TOKEN`: Your Telegram bot token.
    -   `CHAT_ID`: The ID of the Telegram chat where you want to receive notifications.
    -   `MESSAGE_THREAD_ID`: (Optional) The message thread ID if you are using topics in your Telegram group.

## Usage

To run the backup script manually, execute the following command:

```bash
bash backup-unifi-script.sh
```

## Scheduling with Cron

To automate the backup process, you can schedule the script to run at regular intervals using a cron job.

1.  **Open the crontab editor:**
    ```bash
    crontab -e
    ```

2.  **Add a new cron job:**
    Add the following line to run the script every day at 2:00 AM:

    ```cron
    0 2 * * * /path/to/your/repository/backup-unifi-script.sh
    ```
    Replace `/path/to/your/repository/` with the actual path to the script.

## How It Works

1.  The script is executed by a cron job or manually.
2.  It checks for new `.unf` files in the `BACKUP_DIR`.
3.  If new backup files are found, they are copied to the `UPLOAD_FOLDER`.
4.  The script then uses Rclone to upload the `.unf` files from the `UPLOAD_FOLDER` to the `REMOTE_DIR`.
5.  After a successful upload, the script performs a cleanup, deleting older backups from both the `UPLOAD_FOLDER` and the `REMOTE_DIR`, keeping only the two most recent backups.
6.  A notification is sent to the configured Telegram chat, indicating the success or failure of the backup process.
