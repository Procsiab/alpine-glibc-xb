# Alpine GlibC cross-arch. builder

## Requirements

- The binaries for `qemu-user-static` should be installed, possibly from your distro's package manager

- Your system is enabled to run builds through QEMU if the target architecture differs from the host's

- The container tools `buildah` and `podman`, but you may also change the build Bash script to use other tools instead

For the second point, in case you are using SELinux and Podman, run the following (thanks a lot user [nalid](https://github.com/nalind/fedora-qemu-user-static)):
```bash
sudo podman run --rm --privileged -v /usr/local/bin -e BINDIR=/usr/local/bin -e CHCON="-t bin_t" ghcr.io/nalind/fedora-qemu-user-static register
```

If not using SELinux or using Docker or Podman Machine, review the link above to find out more

## Create signing keys

The Containerfile involve the creation of a key pair to sign the generated APK packages:

- **Private Key**: `openssl genrsa -out private-key.pem 2048`

- **Public Key**: `openssl rsa -in private-key.pem -pubout -out public-key.rsa.pub`

While the private key should be passed as an argument to the build command, the public key should be installed on the target system at `/etc/apk/keys/`

## Building

To start the build process, review the contents of the file `build\_vars.env.sh` and after making any change to the declared version numbers, run that Bash file providing the target architecture as the argument:

```bash
bash build_command.sh aarch64
```

**NOTE**: I usually test this build procedure with armv7, aarch64 and amd64 targets, but you may as well just copy the `buildah` command and run it with the target of your choice

### It is taking long...

If your target architecture is different from your host's one, then you are running this build under an emulation layer, which is responsible for slowing down the process; to give you an idea about how much slower: take for reference a system with a 16 core CPU running at 4GHz

- target `amd64`, build time *3m7s*
- target `aarch64`, build time *27m33s*

### APK artefacts

The Bash build script will also take care of copying the generated APK packages inside the folder `apks` in the local directory.

Note that this operation does not clean up the container image created with `buildah` by the build script: to do that, use the commands `podman rmi ID` providing the ID of the image you want to clean up.

## Installing

Copy the public key PUB file to the folder `/etc/apk/keys` on the target Alpine system, to allow installing the packages you signed with the private key generated before.

If you prefer, allow the install of the untrusted package by adding the flag `--allow-untrusted` at the end of the install command below.

Transfer the APK files from `apks/architecture` to the target Alpine installation, then run the following command (e.g. to install the main APK):

```bash
sudo apk add --no-cache --force-overwrite glibc-2.36-r0.apk
```

The overwrite option will make sure that the `nsswitch.conf` and `ld-linux-armhf.so.3` files will be used instead of the system-bundled ones.

### Missing `libresolv`

At the moment the generated GlibC APKs do not include an Alpine version of `libresolv`: the binaries which relies on that will not work out of the box.

You can try to install and use the `libnsl` APK by [thkukuk](https://github.com/thkukuk/libnsl), which will almost replace this dependency:

```bash
sudo apk add --no-cache libnsl
```

**NOTE**: this package is found inside the `community` repository, on the `edge` branch.

---

### Credits

This repository is a fork of [Lauri-Nomme](https://github.com/Lauri-Nomme/alpine-glibc-xb)'s one, which is in turn inspired by the work done by [sgerrand](https://github.com/sgerrand/alpine-pkg-glibc) and [frezbo](https://github.com/sgerrand/docker-glibc-builder/issues/20#issue-295572838)
