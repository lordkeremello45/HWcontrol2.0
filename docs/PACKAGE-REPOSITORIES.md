# HWcontrol2.0 package repositories

The product/display name is **HWcontrol2.0**. The package/terminal name is **`hwcontrol`**.

## APT (Debian/Ubuntu x64)

The Pages pipeline can publish a signed static APT repository from the latest stable Linux DEB release when the repository signing secret is configured.

Required GitHub Actions repository secret:
- `APT_GPG_PRIVATE_KEY`: an ASCII-armored, dedicated APT repository signing key. Never commit this key or paste it into issues/chat. Use a dedicated key that is not used for code signing.

After configuring the secret and running **Build and Deploy Astro Website**, the repository files are served below:

`https://lordkeremello45.github.io/HWcontrol2.0/apt/`

Before users configure APT, publish and verify the signing-key fingerprint through an independent trusted channel. The website-served key alone is not an independent trust anchor. The repository workflow validates that the selected stable release contains a DEB with package name `hwcontrol` and architecture `amd64`; it fails the repository-generation step if no matching release exists.

Once the signed repository is published and its fingerprint is independently verified, client setup is:

```sh
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://lordkeremello45.github.io/HWcontrol2.0/apt/hwcontrol-archive-keyring.gpg \
  | sudo tee /etc/apt/keyrings/hwcontrol-archive-keyring.gpg >/dev/null
sudo chmod 0644 /etc/apt/keyrings/hwcontrol-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/hwcontrol-archive-keyring.gpg] https://lordkeremello45.github.io/HWcontrol2.0/apt stable main" \
  | sudo tee /etc/apt/sources.list.d/hwcontrol.list
sudo apt update
sudo apt install hwcontrol
```

**Do not run the commands above until the repository is published and the key fingerprint is independently verified.** They are setup instructions, not evidence that the live endpoint already works.

## FreeBSD pkg

See [FreeBSD pkg repository status](./FREEBSD-PKG.md). The Debian package is not compatible with FreeBSD. The FreeBSD repository remains blocked until a native `.pkg` artifact and FreeBSD install/runtime tests exist; do not advertise `pkg install hwcontrol` as working yet.
