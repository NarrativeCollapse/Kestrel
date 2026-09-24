# Kestrel

An immutable (bootc) daily-driver desktop built on **AlmaLinux Atomic Desktop (KDE)**, tuned for gaming on **Intel integrated graphics**.

- **KDE Plasma 6**: the newest build EPEL 10 ships, pulled in by a weekly rebuild
- **LibreWolf** as the default browser (Flatpak; Firefox removed)
- **Bazaar** app store (Flatpak) in place of KDE Discover; system Flatpaks auto-update daily
- **Steam, Heroic, Lutris, ProtonUp-Qt, GOverlay** as Flatpaks, with MangoHud and gamescope Vulkan layers matched to Steam's runtime
- **Intel graphics stack**: Mesa Iris/ANV, VA-API media driver, firmware, GPU tools
- **Gaming tuning**: `vm.max_map_count`, split-lock mitigation off, zram swap, GameMode, tuned power profiles, controller udev rules (Steam, Sony, Nintendo, Xbox, 8BitDo…)
- **Claude Desktop** (Chat, Cowork, Code) from Anthropic's official Linux build, with QEMU/KVM for Cowork
- **Terminal bling** (after [Bazzite](https://github.com/ublue-os/bazzite)): Homebrew, starship prompt, Nerd Font icons, `eza`, `ugrep`, `atuin` history search (Ctrl+R), `zoxide`, fastfetch banner
- **Atomic updates and rollback** via `bootc`

## Design notes and limitations

| Topic | What to expect |
|---|---|
| Plasma version | EPEL rebuilds Fedora's Plasma for EL10 every couple of months, so Kestrel runs about one minor release behind upstream. |
| Steam / 32-bit | EL10 has **no i686 packages**, so native Steam RPMs are impossible. Steam runs as a Flatpak (its own 32-bit runtime). |
| Mesa for games | Flatpak games use the Flatpak runtime's Mesa, which is newer than EL10's. Host Mesa only drives the desktop and native apps. |
| Kernel | Stock EL10 kernel (6.12 + Red Hat backports). No `ntsync`; Proton falls back to fsync/esync. |
| Claude Desktop | Anthropic ships Linux builds only as a `.deb` for Ubuntu/Debian. `60-claude-desktop.sh` verifies the newest one against Anthropic's signed apt index and unpacks it into `/usr`; it updates with the weekly rebuild. Not officially supported on EL10 by Anthropic. Cowork's VM uses EL10's `qemu-kvm` through Debian-style path links; if Cowork reports a KVM permission error, run `sudo usermod -aG kvm $USER` and log in again. Computer Use and dictation aren't in the Linux beta. Before making your image public, check that Anthropic's terms allow redistributing the app. |
| Homebrew | From [ublue-os/brew](https://github.com/ublue-os/brew). Unpacked to `/var/home/linuxbrew` on first boot and owned by the **first user account (UID 1000)**; other accounts can use but not install. Brew updates every 6h and upgrades every 8h in the background. Brew's `bin` comes *after* the system's in `PATH`, so it never overrides system tools. |
| Terminal bling | `kestrel-brew-bling.service` installs the tools in `/usr/share/kestrel/Brewfile` on first boot (needs network; retries each boot until it succeeds). Starship is on for everyone in bash; opt out with `touch ~/.config/kestrel/no-bling`. Atuin takes over Ctrl+R only, not the Up arrow. |
| Optional packages | Nice-to-haves go through `install_optional` (`files/scripts/lib.sh`). If EPEL drops one, the build logs a warning and carries on. |

## Layout

```
Dockerfile                    FROM atomic-desktop-kde:10, runs build.sh, bootc lint
files/scripts/
  10-base.sh                  refresh repos, upgrade to newest EPEL Plasma
  20-intel-graphics.sh        Mesa, Vulkan, VA-API, firmware
  30-gaming.sh                tuned-ppd, zram, GameMode, enables services
  40-desktop.sh               KDE apps + CLI tools
  50-branding.sh              name in os-release / About This System  ← rename here
  60-claude-desktop.sh        Claude Desktop from Anthropic's apt repo + Cowork's QEMU/KVM
  70-shell.sh                 Homebrew, Nerd Font symbols, enables bling services
  lib.sh                      install_optional helper
files/system/                 copied into / verbatim
  etc/flatpak/default-flatpaks/system/install   default Flatpak apps
  usr/bin/kestrel-flatpak-extras                Vulkan layers + drive access for Steam
  etc/profile.d/kestrel-bling.sh                starship, eza, ugrep, atuin, zoxide
  usr/share/kestrel/Brewfile                    CLI tools installed with Homebrew
  usr/share/kestrel/fastfetch.jsonc             fastfetch banner
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

## Installing

- **Fresh install:** boot the ISO and follow the installer.
- **From an existing AlmaLinux Atomic install:** `sudo bootc switch ghcr.io/<you>/kestrel:latest` and reboot.

On first boot, Flatpaks install in the background (you'll get a notification). About 10 minutes later the MangoHud and gamescope layers are added.

## Using it

- MangoHud in a Steam game: launch options `MANGOHUD=1 %command%`
- gamescope: `gamescope -W 1920 -H 1080 -f -- %command%`
- GameMode: `gamemoderun %command%`
- Proton-GE: open **ProtonUp-Qt**, add GE-Proton for Steam
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

The image rebuilds every Sunday. Installed systems check for updates automatically; apply them with `sudo bootc upgrade` and a reboot. Use `sudo bootc rollback` if an update misbehaves.
