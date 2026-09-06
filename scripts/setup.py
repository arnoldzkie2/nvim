#!/usr/bin/env python3
"""Bootstrap this Neovim configuration on Ubuntu 24.04+ (standard library only)."""
import argparse
import configparser
import getpass
import hashlib
import os
from pathlib import Path
import platform
import shlex
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
NVIM_VERSION = '0.11.4'
NODE_VERSION = '24.12.0'
NVIM_SHA256 = {
    'x86_64': 'a74740047e73b2b380d63a474282814063d10650cd6cc95efa16d1713c7e616c',
    'arm64': '684e4262d2296e469cb43f0d05edbbb52b960b7f117bed6b22936fc768993cd9',
}
PACKAGES = ('git curl ca-certificates tar xz-utils unzip build-essential ripgrep '
            'fd-find python3-venv python3-pip golang-go rustfmt cargo clang-format '
            'openjdk-21-jre-headless php-cli php-xml php-mbstring fontconfig fonts-ubuntu xclip').split()
TOOLS = 'nvim node npm git cc rg python3 gofmt rustfmt clang-format java php'.split()


def run(*args, capture=False, **kwargs):
    return subprocess.run([str(a) for a in args], check=True, text=True,
                          stdout=subprocess.PIPE if capture else None, **kwargs)


def download(url, target):
    run('curl', '--fail', '--location', '--retry', '3', '--output', target, url)


def install_archive(base, filename, checksums, destination, binary):
    if (destination / binary).exists():
        return
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='nvim-download-') as tmp:
        tmp = Path(tmp)
        archive = tmp / filename
        download(base + '/' + filename, archive)
        if len(checksums) == 64 and all(c in '0123456789abcdef' for c in checksums):
            expected = checksums
        else:
            download(base + '/' + checksums, tmp / 'checksums')
            expected = next((line.split()[0] for line in (tmp / 'checksums').read_text().splitlines()
                             if line.split() and line.split()[-1].lstrip('*') == filename), None)
        if not expected or hashlib.sha256(archive.read_bytes()).hexdigest() != expected:
            raise RuntimeError(f'Checksum verification failed: {filename}')
        staging = tmp / 'unpacked'
        staging.mkdir()
        run('tar', '-xf', archive, '--strip-components=1', '-C', staging)
        if not (staging / binary).exists():
            raise RuntimeError(f'Download does not contain {binary}')
        # Move the complete tree, so an interrupted download is safe to retry.
        if destination.exists():
            raise RuntimeError(f'Incomplete installation at {destination}; move it aside and retry.')
        shutil.move(str(staging), destination)


def append_once(path, line):
    existing = path.read_text() if path.exists() else ''
    if line not in existing.splitlines():
        with path.open('a') as stream:
            stream.write('\n' + line + '\n')


def configure_wakapi(path, interactive):
    config = configparser.ConfigParser(interpolation=None)
    config.read(path)
    if not config.has_section('settings'):
        config.add_section('settings')
    settings = config['settings']
    if settings.get('api_key') and settings.get('api_url', '').rstrip('/') == 'https://wakapi.dev/api':
        path.chmod(0o600)
        print('Wakapi: existing configuration retained.')
        return True
    if not interactive:
        print('Wakapi: skipped; run ./setup.sh --wakapi-only in an interactive terminal to add your key.')
        return False
    key = getpass.getpass('Wakapi API key (hidden; Enter to skip): ').strip()
    if not key:
        print('Wakapi: skipped.')
        return False
    settings['api_url'] = 'https://wakapi.dev/api'
    settings['api_key'] = key
    # Atomic, owner-only write. Never place the credential in command arguments or the repo.
    fd, temporary = tempfile.mkstemp(prefix='.wakatime-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            config.write(stream)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    print('Wakapi: configured.')
    return True


def configure_terminal():
    if not shutil.which('gsettings') or not os.environ.get('DBUS_SESSION_BUS_ADDRESS'):
        print('Terminal font: skipped (no desktop session); set Ubuntu Sans Mono 11 in your terminal.')
        return
    schemas = run('gsettings', 'list-schemas', capture=True).stdout.splitlines()
    if 'org.gnome.Terminal.ProfilesList' not in schemas:
        print('Terminal font: set Ubuntu Sans Mono 11 in your terminal preferences.')
        return
    profile = run('gsettings', 'get', 'org.gnome.Terminal.ProfilesList', 'default', capture=True).stdout.strip().strip("'")
    schema = f'org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:{profile}/'
    run('gsettings', 'set', schema, 'use-system-font', 'false')
    run('gsettings', 'set', schema, 'font', 'Ubuntu Sans Mono 11')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='report tool availability without changing anything')
    parser.add_argument('--dry-run', action='store_true', help='show the setup plan without changing anything')
    parser.add_argument('--non-interactive', action='store_true', help='skip the Wakapi key prompt')
    parser.add_argument('--wakapi-only', action='store_true', help='configure only the private Wakapi credential')
    for name in ('system', 'fonts', 'terminal', 'wakapi'):
        parser.add_argument('--skip-' + name, action='store_true')
    args = parser.parse_args()
    home = Path.home()
    config_home = Path(os.environ.get('XDG_CONFIG_HOME', home / '.config'))
    data_home = Path(os.environ.get('XDG_DATA_HOME', home / '.local/share'))
    prefix = home / '.local/share/nvim-setup'
    config = config_home / 'nvim'
    if args.check:
        missing = []
        for name in TOOLS:
            location = shutil.which(name)
            print(f'{name}: {location or "MISSING"}')
            if not location:
                missing.append(name)
        print(f'Configuration: {config} -> {config.resolve()}')
        print('This checks executable availability; use :checkhealth inside Neovim for plugin health.')
        return int(bool(missing))
    if args.dry_run:
        print(f'Link this checkout at {config} if absent; refuse to replace another config.')
        if not args.wakapi_only:
            if not args.skip_system:
                print('Install Ubuntu packages with sudo apt: ' + ' '.join(PACKAGES))
            print(f'Install Neovim {NVIM_VERSION} and Node {NODE_VERSION} under {prefix}.')
            print('Add managed tool paths to ~/.profile, ~/.bashrc and ~/.zshrc.')
            print('Restore lazy-lock.json; install Mason tools and Treesitter parsers; verify completion.')
            if not args.skip_fonts:
                print('Install Symbols Nerd Font Mono and Ubuntu Sans Mono icon fallback.')
            if not args.skip_terminal:
                print('Set the default GNOME Terminal profile to Ubuntu Sans Mono 11 when available.')
        if not args.skip_wakapi:
            print('Retain existing Wakapi settings or privately prompt for a key (unless non-interactive).')
        return 0
    if os.geteuid() == 0:
        raise RuntimeError('Run as your normal user, without sudo. Only apt commands use sudo.')
    if args.wakapi_only:
        configure_wakapi(home / '.wakatime.cfg', not args.non_interactive and sys.stdin.isatty())
        return 0
    if os.environ.get('NVIM_APPNAME', 'nvim') != 'nvim':
        raise RuntimeError('Unset NVIM_APPNAME before running setup for this configuration.')
    release = platform.freedesktop_os_release()
    if platform.system() != 'Linux' or release.get('ID') != 'ubuntu' or int(release.get('VERSION_ID', '0').split('.')[0]) < 24:
        raise RuntimeError('This installer supports Ubuntu 24.04+; other platforms need manual dependency installation.')
    arch = {'x86_64': ('x86_64', 'x64'), 'aarch64': ('arm64', 'arm64')}.get(platform.machine())
    if not arch:
        raise RuntimeError('Supported architectures: x86_64 and aarch64.')
    if (config.exists() or config.is_symlink()) and config.resolve() != ROOT:
        raise RuntimeError(f'{config} already points to another config. Move it aside before retrying; nothing was replaced.')
    if not args.skip_system:
        run('sudo', 'apt-get', 'update')
        run('sudo', 'apt-get', 'install', '-y', *PACKAGES)
    for required in ('curl', 'tar', 'git'):
        if not shutil.which(required):
            raise RuntimeError(f'Missing {required}; rerun without --skip-system.')
    if not config.exists():
        config.parent.mkdir(parents=True, exist_ok=True)
        config.symlink_to(ROOT, target_is_directory=True)
    nvim = prefix / ('nvim-' + NVIM_VERSION)
    node = prefix / ('node-' + NODE_VERSION)
    install_archive(f'https://github.com/neovim/neovim/releases/download/v{NVIM_VERSION}',
                    f'nvim-linux-{arch[0]}.tar.gz', NVIM_SHA256[arch[0]], nvim, 'bin/nvim')
    install_archive(f'https://nodejs.org/dist/v{NODE_VERSION}',
                    f'node-v{NODE_VERSION}-linux-{arch[1]}.tar.xz', 'SHASUMS256.txt', node, 'bin/node')
    paths = f'{nvim}/bin:{node}/bin:{home}/.local/bin'
    env_file = prefix / 'env.sh'
    env_file.write_text('export PATH=' + shlex.quote(paths) + ':"$PATH"\n')
    source_line = '. ' + shlex.quote(str(env_file)) + ' # nvim-setup'
    for rc in ('.profile', '.bashrc', '.zshrc'):
        append_once(home / rc, source_line)
    os.environ['PATH'] = paths + ':' + os.environ.get('PATH', '')
    os.environ['NVIM_SETUP_ROOT'] = str(ROOT)
    # Isolate startup from editor autosave and activity tracking while bootstrapping.
    run(nvim / 'bin/nvim', '--headless', '-u', 'NONE', '-i', 'NONE',
        '-c', 'lua dofile(vim.env.NVIM_SETUP_ROOT .. "/scripts/bootstrap.lua")', cwd=ROOT, timeout=2400)
    if not args.skip_fonts:
        fonts = data_home / 'fonts/NerdFontsSymbols'
        fonts.mkdir(parents=True, exist_ok=True)
        font = fonts / 'SymbolsNerdFontMono-Regular.ttf'
        if not font.exists():
            with tempfile.TemporaryDirectory(prefix='nvim-font-') as tmp:
                staged = Path(tmp) / font.name
                download('https://raw.githubusercontent.com/ryanoasis/nerd-fonts/v3.4.0/patched-fonts/NerdFontsSymbolsOnly/' + font.name, staged)
                shutil.copyfile(staged, font)
        fallback = config_home / 'fontconfig/conf.d/99-neovim-icon-fallback.conf'
        fallback.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / 'scripts/99-neovim-icon-fallback.conf', fallback)
        run('fc-cache', '-f')
    if not args.skip_terminal:
        configure_terminal()
    if not args.skip_wakapi:
        configure_wakapi(home / '.wakatime.cfg', not args.non_interactive and sys.stdin.isatty())
    print('\nSetup complete. Restart your terminal, then run nvim.')
    print('Install dependencies in each project separately. Wakapi downloads its CLI on normal editor startup.')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except configparser.Error:
        print('Setup failed: malformed ~/.wakatime.cfg. Fix its INI syntax and retry.', file=sys.stderr)
        sys.exit(1)
    except (RuntimeError, OSError, ValueError, subprocess.SubprocessError) as error:
        print(f'Setup failed: {error}', file=sys.stderr)
        sys.exit(1)
