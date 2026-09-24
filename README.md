# Kestrel

An immutable (bootc) daily-driver desktop built on **AlmaLinux Atomic Desktop (KDE)**, tuned for gaming on **Intel integrated graphics**.

- **KDE Plasma 6**: the newest build EPEL 10 ships, pulled in by a weekly rebuild
- **LibreWolf** as the default browser (Flatpak; Firefox removed)
- **Bazaar** app store (Flatpak) in place of KDE Discover; system Flatpaks auto-update daily
- **Only LibreWolf and Bazaar install automatically**; you choose everything else (Steam, Heroic, Lutris, …) in Bazaar
- **Steam-ready**: install Steam (Flatpak) and Kestrel adds MangoHud and gamescope Vulkan layers matched to Steam's runtime
- **Intel graphics stack**: Mesa Iris/ANV, VA-API media driver, firmware, GPU tools
- **Gaming tuning**: `vm.max_map_count`, split-lock mitigation off, zram swap, GameMode, tuned power profiles, controller udev rules (Steam, Sony, Nintendo, Xbox, 8BitDo…)
- **Claude**: use [claude.ai](https://claude.ai) in LibreWolf; for Claude Code run Anthropic's installer (see *Using it*)
- **Terminal bling** (after [Bazzite](https://github.com/ublue-os/bazzite)): Homebrew, starship prompt, Nerd Font icons, `eza`, `ugrep`, `atuin` history search (Ctrl+R), `zoxide`, Kestrel fastfetch banner — in bash, zsh and fish
- **Xbox controllers** over USB (`xpad`) and Bluetooth (`hid-microsoft`), with BlueZ tuned for reliable re-pairing
- **Podman and Distrobox** out of the box, for containers and other distros' packages (`distrobox create -i ubuntu:24.04`)
- **`kestrel` helper**: `kestrel status | update | rollback | bling on/off | controllers | secureboot`
- **Background OS updates**: new images download daily and apply on your next reboot (never an automatic reboot)
- **Atomic updates and rollback** via `bootc`

## Design notes and limitations

| Topic | What to expect |
|---|---|
| Plasma version | EPEL rebuilds Fedora's Plasma for EL10 every couple of months, so Kestrel runs about one minor release behind upstream. |
| Steam / 32-bit | EL10 has **no i686 packages**, so native Steam RPMs are impossible. Steam runs as a Flatpak (its own 32-bit runtime). |
| Mesa for games | Flatpak games use the Flatpak runtime's Mesa, which is newer than EL10's. Host Mesa only drives the desktop and native apps. |
| Kernel | Stock EL10 kernel (6.12 + Red Hat backports). No `ntsync`; Proton falls back to fsync/esync. |
| Homebrew | From [ublue-os/brew](https://github.com/ublue-os/brew). Unpacked to `/var/home/linuxbrew` on first boot and owned by the **first user account (UID 1000)**; other accounts can use but not install. Brew updates every 6h and upgrades every 8h in the background. Brew's `bin` comes *after* the system's in `PATH`, so it never overrides system tools. |
| Terminal bling | `kestrel-brew-bling.service` installs the tools in `/usr/share/kestrel/Brewfile` on first boot (needs network; retries each boot until it succeeds). Starship is on for everyone in bash; opt out with `touch ~/.config/kestrel/no-bling`. Atuin takes over Ctrl+R only, not the Up arrow. |
| Xbox controllers | Bluetooth pads use the kernel's `hid-microsoft`. EL10's kernel has no `xpad` (wired pads), so Kestrel builds it from Linux 6.12's source (`kmods/`) and signs it with the Kestrel driver key; with Secure Boot on, run `kestrel secureboot` once (see **Secure Boot** below). The **Xbox Wireless Adapter** (USB dongle) isn't supported (needs the `xone` driver + Microsoft firmware). `kestrel controllers` shows what's detected. |
| Video decode | Intel's full VA-API driver (`intel-media-driver`, "iHD") comes from **RPM Fusion** (free + nonfree), enabled in `10-base.sh`. |
| Boot test | After each image build, CI boots the image in a VM and waits for the login screen (**Boot test** workflow; serial log is kept as an artifact). The image is already published by then, so if it fails, don't reboot into the staged update. |
| Optional packages | Nice-to-haves go through `install_optional` (`files/scripts/lib.sh`). If EPEL drops one, the build logs a warning and carries on. |

## Layout

```
Dockerfile                    FROM atomic-desktop-kde:10, runs build.sh, bootc lint
kmods/                        out-of-tree drivers (xpad), built + signed by build-kmods.yml
files/scripts/
  10-base.sh                  refresh repos, upgrade to newest EPEL Plasma
  20-intel-graphics.sh        Mesa, Vulkan, VA-API, firmware
  30-gaming.sh                tuned-ppd, zram, GameMode, enables services
  40-desktop.sh               KDE apps + CLI tools
  50-branding.sh              name in os-release / About This System  ← rename here
  35-controllers.sh           Xbox pad drivers (xpad from kmods/, hid-microsoft), Bluetooth
  70-shell.sh                 Homebrew, Nerd Font symbols, zsh/fish, enables bling services
  80-updates.sh               daily background image download, no auto-reboot
  lib.sh                      install_optional helper
files/system/                 copied into / verbatim
  etc/flatpak/default-flatpaks/system/install   Flatpaks installed on first boot (LibreWolf, Bazaar)
  usr/bin/kestrel-flatpak-extras                Vulkan layers + drive access for Steam
  etc/profile.d/kestrel-bling.sh                starship, eza, ugrep, atuin, zoxide
  usr/share/kestrel/Brewfile                    CLI tools installed with Homebrew
  usr/share/kestrel/fastfetch.jsonc             fastfetch banner (+ logo.txt)
  usr/bin/kestrel                               helper command
  usr/lib/systemd/system/kestrel-os-update.*    daily `bootc upgrade` (stage only)
  usr/lib/sysctl.d/60-kestrel-gaming.conf
  usr/lib/udev/rules.d/70-kestrel-game-controllers.rules
  usr/lib/systemd/zram-generator.conf
```

## First-time setup (GitHub)

1. Create a GitHub repo (the repo name becomes the image name, e.g. `kestrel`) and push this code to `main`.
2. **Settings → Actions → General → Workflow permissions**: set to "Read and write".
3. (Recommended) Sign your images:
   ```sh
   podman run --rm -it -v /tmp:/cosign-keys bitnami/cosign generate-key-pair   # blank password
   cp /tmp/cosign.pub ./cosign.pub && git add cosign.pub && git commit -m "Add cosign key" && git push
   gh secret set SIGNING_SECRET < /tmp/cosign.key && rm /tmp/cosign.key
   ```
4. The **Build image** workflow publishes `ghcr.io/<you>/kestrel:latest`. Make the package public under your GitHub profile → Packages.
5. Run **Build ISO** (Actions tab → workflow_dispatch) to get an installer ISO as a workflow artifact.

## Secure Boot (driver signing key)

Kestrel's own drivers (currently `xpad`) are signed in CI with a key only you hold. One-time setup:

1. Create the key pair (any Linux machine with `openssl`):
   ```sh
   openssl req -new -x509 -newkey rsa:4096 -sha256 -nodes -days 36500 \
     -subj "/CN=Kestrel kernel module signing key/" \
     -addext "basicConstraints=critical,CA:FALSE" -addext "keyUsage=digitalSignature" \
     -addext "extendedKeyUsage=codeSigning,1.3.6.1.4.1.2312.16.1.2" \
     -keyout kestrel-kmod.key -out kestrel-kmod.pem
   ```
2. Repo **Settings → Secrets and variables → Actions → New repository secret**: name `KMOD_SIGNING_KEY`, value = the full contents of `kestrel-kmod.key`. Keep that file private (or delete it; CI has it now).
3. Commit the **public** certificate as `files/system/usr/share/kestrel/secureboot/kestrel-kmod.pem`.
4. After installing Kestrel with Secure Boot on: run `kestrel secureboot`, set a one-time password, reboot, and in the blue MOK screen choose *Enroll MOK → Continue → Yes*, enter the password, reboot.

Without the key, `xpad` is built unsigned and only loads with Secure Boot off.

## Installing

- **Fresh install:** boot the ISO and follow the installer.
- **From an existing AlmaLinux Atomic install:** `sudo bootc switch ghcr.io/<you>/kestrel:latest` and reboot.

On first boot, LibreWolf and Bazaar install in the background (you'll get a notification); install the rest of your apps from Bazaar. Once Steam is installed, the MangoHud and gamescope layers are added within a day (or run `sudo systemctl start kestrel-flatpak-extras`). Homebrew is unpacked for the first user account created in the installer, then the terminal tools install (needs network).

## Using it

- Claude Code (needs a Pro/Max/Team account): `curl -fsSL https://claude.ai/install.sh | bash` — installs to `~/.local/bin/claude` in your home folder and keeps itself updated, so it works on this image-based system
- `kestrel status` shows the booted/staged image and background services; `kestrel help` lists the rest
- MangoHud in a Steam game: launch options `MANGOHUD=1 %command%`
- gamescope: `gamescope -W 1920 -H 1080 -f -- %command%`
- GameMode: `gamemoderun %command%`
- Proton-GE: install **ProtonUp-Qt** from Bazaar, then add GE-Proton for Steam
- Extra game drives: mount under `/run/media` or `/mnt`; Steam and Heroic can already see them.

## Credits

`kestrel-bling.sh` and `fastfetch.jsonc` are adapted from [Bazzite](https://github.com/ublue-os/bazzite); Homebrew integration comes from [ublue-os/brew](https://github.com/ublue-os/brew). Both are Apache-2.0 (copy in `/usr/share/licenses/kestrel/bazzite-LICENSE`).

## Local build

```sh
make image      # podman build → localhost/kestrel
make iso        # bootc-image-builder ISO in ./output
make run-qemu-iso
```

## Updating

The image rebuilds every Sunday and on every push to `main`. Installed systems download the newest image in the background once a day (`kestrel-os-update.timer`) and switch to it the next time you reboot — they never reboot on their own. `kestrel update` fetches it right away; `kestrel rollback` (or `sudo bootc rollback`) goes back to the previous image if an update misbehaves.

The package on ghcr.io must be **public** for installed machines to download updates. A **Keep scheduled workflows alive** workflow stops GitHub from switching off the weekly rebuild after 60 days of repo inactivity.
