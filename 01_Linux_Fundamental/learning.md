# Linux Homework – Learning Notes

## Task 1: Soft Link and Hard Link

A **soft link (symbolic link)** points to the path of another file.

```bash
ln -s original.txt softlink.txt
```

A **hard link** points to the same inode as the original file.

```bash
ln original.txt hardlink.txt
```

The main difference is that a soft link points to a file path, while a hard link points to the same inode. A soft link can cross filesystems, while a hard link generally cannot.

---

## Task 2: adduser vs useradd

`useradd` is a low-level command used to create users.

`adduser` is a more user-friendly command that provides an interactive process and handles additional user configuration.

On Ubuntu/Linux, **adduser is generally preferred** for creating users.

```bash
sudo adduser testuser
```

---

## Task 3: journalctl

`journalctl` is used to view and manage logs collected by `systemd`.

View system logs:

```bash
journalctl
```

View the latest logs:

```bash
journalctl -n 20
```

View logs for a specific service:

```bash
journalctl -u ssh
```

---

## Task 4: Linux Command Cheat Sheet

| Command      | Purpose                      |
| ------------ | ---------------------------- |
| `pwd`        | Show current directory       |
| `ls`         | List files and directories   |
| `cd`         | Change directory             |
| `mkdir`      | Create a directory           |
| `touch`      | Create a file                |
| `cp`         | Copy files                   |
| `mv`         | Move or rename files         |
| `rm`         | Delete files                 |
| `cat`        | Display file contents        |
| `grep`       | Search for text              |
| `find`       | Find files and directories   |
| `chmod`      | Change file permissions      |
| `ps`         | View running processes       |
| `top`        | Monitor running processes    |
| `df`         | Check disk space             |
| `du`         | Check file or directory size |
| `systemctl`  | Manage system services       |
| `journalctl` | View system logs             |

## Conclusion

The above topics cover basic Linux file links, user management, system logging, and commonly used Linux commands.
