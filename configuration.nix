{
  config,
  ...
}:
  let
    pkgs = import ./nixpkgs { config.allowUnfree = true; };
    options = import ./options.nix;
  in
    {

      # Bootloader
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.efiSysMountPoint = "/boot";
      boot.loader.efi.canTouchEfiVariables = false;

      # Kernel
      boot.kernelPackages = pkgs.linuxPackages_4_19;
      boot.kernelParams = [
        "zfs_force=1" # Make ZFS ignore the hostId and force import
      ];

      # Autoload kernel modules by scanning hardware
      boot.hardwareScan = true;

      # Kernel modules available for loading for stage 1 boot
      boot.initrd.supportedFilesystems = [ "zfs" ];
      boot.initrd.availableKernelModules = [
        "xhci_pci"
        "ehci_pci"
        "ahci"
        "usb_storage"
        "usbhid"
        "sd_mod"
        "sdhci_pci"
        "uas"
      ];

      # Kernel modules
      boot.kernelModules = [ "kvm-intel" "coretemp" ];
      boot.supportedFilesystems = [ "zfs" "nfs" "exfat" ];

      # CPU microcode
      hardware.cpu.intel.updateMicrocode = true;
      hardware.enableRedistributableFirmware = true;W

      # Power management
      powerManagement.cpuFreqGovernor = "ondemand";

      # Clean tmp directory on reboot
      boot.cleanTmpDir = true;

      boot.runSize = "50%"; # refers to /run (runtime files, could use some memory)
      boot.devShmSize = "50%"; # refers to /dev/shm (shared memory, useless if no applications use shared memory)
      boot.devSize = "5%"; # refers to /dev (this shouldn't much at all)

      fileSystems = {
        "/" = {
          device = "rpool";
          fsType = "zfs";
        };
        "/tmp" = {
          device = "rpool/tmp";
          fsType = "zfs";
        };
        "/boot" = {
          device = options.bootDevice;
          fsType = "vfat";
        };
      };

      swapDevices = builtins.map (p: { device = p; } ) options.swapDevices;

      # Video acceleration
      hardware.opengl.driSupport = true;
      hardware.opengl.driSupport32Bit = true;
      hardware.opengl.extraPackages = [ pkgs.vaapiVdpau ];

      # Audio
      sound.enable = true;
      sound.mediaKeys.enable = true;
      hardware.pulseaudio = {
        enable = true;
        support32Bit = true;
        package = pkgs.pulseaudioFull;
      };

      # Bluetooth
      hardware.bluetooth = {
        enable = true;
        powerOnBoot = true;
      };

      # Extra peripherals
      hardware.u2f.enable = true;
      hardware.sane.enable = true;

      # Networking
      networking = rec {
        hostName = options.systemName;
        hostId = builtins.substring 0 8 (builtins.hashString "sha256" hostName);
        enableIPv6 = true;
        useNetworkd = false;
        networkmanager = {
          enable = true;
          dns = "dnsmasq";
          insertNameservers = import ./nameservers.nix;
        };
        firewall = {
          enable = true;
          allowPing = true;
          pingLimit = "--limit 3/second --limit-burst 5";
          allowedTCPPorts = [
            22    # ssh
            55555 # five 5s for custom TCP
          ];
          allowedUDPPorts = [
            53 # dnsmasq dns
            67 # dnsmasq dhcp
            22 # ssh
            55555 # five 5s for custom UDP
          ];
          rejectPackets = false;
          logRefusedConnections = true;
          logRefusedPackets = false;
          logRefusedUnicastsOnly = false;
        };
      };

      time.timeZone = "Australia/Sydney";

      i18n = {
        consoleKeyMap = "us";
        defaultLocale = "en_AU.UTF-8";
      };

      nix.nixPath = [
        "nixpkgs=/etc/nixos/nixpkgs"
        "nixos-config=/etc/nixos/configuration.nix"
      ];
      nix.maxJobs = 8;

      nix.buildCores = 0;
      nix.useSandbox = true;
      nix.readOnlyStore = true;
      nix.autoOptimiseStore = true;
      nix.extraOptions = ''
        fsync-metadata = true
      '';
      nix.sandboxPaths = [ "/run/keys" ];

      nixpkgs.config.allowUnfree = true;

      # Base packages
      environment.systemPackages = with pkgs; [
        coreutils       # basic shell utilities
        gnused          # sed
        gnugrep         # grep
        gawk            # awk
        ncurses         # tput (terminal control)
        iw              # wireless configuration
        iproute         # ip, tc
        nettools        # hostname, ifconfig
        dmidecode       # dmidecode
        lshw            # lshw
        pciutils        # lspci, setpci
        usbutils        # lsusb
        utillinux       # linux system utilities
        cryptsetup      # luks
        mtools          # disk labelling
        smartmontools   # disk monitoring
        lm_sensors      # fan monitoring
        xorg.xbacklight # monitor brightness
        procps          # ps, top, pidof, vmstat, slabtop, skill, w
        psmisc          # fuser, killall, pstree, peekfd
        shadow          # passwd, su
        mkpasswd        # mkpasswd
        efibootmgr      # efi management
        openssh         # ssh
        gnupg           # encryption/decryption/signing
        hdparm          # disk info
        git             # needed for content addressed nixpkgs
        cmatrix
        vim
      ];

      fonts = {
        enableFontDir = true;
        enableDefaultFonts = true;
        enableGhostscriptFonts = true;
      };

      # Program configuration
      programs.zsh.enable = true;
      programs.zsh.enableCompletion = true;
      programs.zsh.interactiveShellInit = ''
        if [ -n "$PS1" ]; then
          . ${./motd.sh}
          [[ -o login ]] && matrix-motd
        fi
      '';
      programs.bash.enableCompletion = true;
      programs.gnupg.agent = { enable = true; enableSSHSupport = true; };
      programs.mtr.enable = true;
      programs.adb.enable = true;

      # Virtualisation
      virtualisation.libvirtd.enable = true;
      virtualisation.docker = {
        enable = true;
        enableNvidia = true;
      };

      # Services
      services = {
        printing = {
          enable = true;
          drivers = [ pkgs.gutenprint ];
        };
        mingetty.greetingLine = ''[[[ \l @ \n (\s \r \m) ]]]''; # getty message
        gpm.enable = true;
        avahi.enable = true;
        kmscon.enable = true;
        kmscon.hwRender = true;
        dbus.enable = true;
        haveged.enable = true;
        locate.enable = true;
        upower.enable = true;
        cron.enable = false;
        blueman.enable = true;
        openssh = {
          enable = true;
          startWhenNeeded = true;
          permitRootLogin = "no";
          passwordAuthentication = false;
          forwardX11 = true;
          allowSFTP = true;
          gatewayPorts = "clientspecified";
          ports = [ 22 ];
          extraConfig = ''
            PrintLastLog no
          '';
        };
        keybase = {
          enable = true;
        };
        kbfs = {
          enable = true;
        };
        xserver = {
          enable = true;
          autorun = true;
          exportConfiguration = true;
          videoDrivers = [ "nvidia" ];
          xrandrHeads = [ "DP-0" ];
          libinput = {
            enable = true;
          };
          displayManager = {
            gdm.enable = true;
            hiddenUsers = [ "root" "nobody" ]; # cannot login to root
          };
          desktopManager = {
            xterm.enable = true;
            gnome3.enable = true;
          };
        };
      };

      users = {
        defaultUserShell = "/run/current-system/sw/bin/zsh";
        enforceIdUniqueness = true;
        mutableUsers = true;
        groups = {
          operators = {
            gid = 1000;
          };
          plugdev = {
            gid = 1001;
          };
        };
      };

      # Security
      security.sudo.wheelNeedsPassword = true;
      security.sudo.extraConfig = ''
        Defaults umask = 0022
        Defaults umask_override
      '';
      security.polkit.enable = true;

      environment.etc."os-release".text = pkgs.lib.mkForce ''
        NAME="${options.systemDesc}"
        ID="${options.systemName}"
        HOME_URL="https://github.com/DrFacepalm"
      '';

      system.stateVersion = options.stateVersion;

    }
