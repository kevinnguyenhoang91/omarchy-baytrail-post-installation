# Contributing

Thanks for helping keep old Bay Trail hardware alive! 🐧 Every bug report, device report and fix helps the next person with a Pipo X9 or X205TA in a drawer.

## Ways to contribute

| You want to… | Do this |
|--------------|---------|
| Report that it **works** (or doesn't) on your device | Open a [💻 Device report](../../issues/new?template=device_report.yml) |
| Report something that **broke** | Open a [🐛 Bug report](../../issues/new?template=bug_report.yml) |
| Suggest an **improvement** | Open a [✨ Feature request](../../issues/new?template=feature_request.yml) |
| Fix the **script or docs** | Send a pull request (see below) |

> [!TIP]
> Not sure if it's a bug? Search [existing issues](../../issues?q=is%3Aissue) first. Someone may have hit the same thing.

## Reporting a problem

Bay Trail boot problems are hard to debug blind, so please include:

- **Device model** and **eMMC size**
- **Omarchy ISO version** and **Arch ISO date**
- Whether the install is **encrypted (LUKS)** or not
- The **exact step** that failed and the **full error**. A phone photo of the screen is fine.
- Output of these, run inside `arch-chroot`:
  ```bash
  lsblk -f
  grep CMDLINE /etc/default/grub
  ls -lh /boot /boot/EFI/BOOT
  ```

> [!WARNING]
> Don't paste passwords or Wi-Fi keys. UUIDs are fine to share.

## Pull requests

### 1. Branch from `main`

```bash
git clone https://github.com/kevinnguyenhoang91/omarchy-baytrail-post-installation.git
cd omarchy-baytrail-post-installation
git switch -c fix/short-description
```

### 2. Make your change

**For `omarchy-baytrail-postinstall.sh`:**

- Keep it **idempotent**: running it twice must be safe. Check before you create, append or remove anything.
- Keep `set -euo pipefail`, and handle commands that may legitimately fail (`|| true`).
- Number each step's output `==> [n/N] …` and update the step table in the README.
- **Test on real hardware** if you can, and say which device in the PR.

**For docs:**

- Keep the README and the script in sync. If the script changes, the manual steps and the "What the script does" table should match.

### 3. Run the checks locally

The same checks run in CI ([Script Check](.github/workflows/shellcheck.yml)):

```bash
bash -n omarchy-baytrail-postinstall.sh
shellcheck --severity=style omarchy-baytrail-postinstall.sh
```

Also make sure the script keeps **LF line endings** and stays **executable**.

### 4. Commit and open the PR

- Use [Conventional Commits](https://www.conventionalcommits.org/): `fix:`, `feat:`, `docs:`, `ci:`, `refactor:`
- **Sign your commits.** `main` requires verified signatures. See [GitHub's signing guide](https://docs.github.com/en/authentication/managing-commit-signature-verification/signing-commits).
- Fill in the pull request template. PRs are **squash-merged** once the **Script Check** passes and the PR has been reviewed.

## Adding a new device

Got Omarchy running on a Bay Trail device that isn't listed? Open a [Device report](../../issues/new?template=device_report.yml), or send a PR that adds a row to the **Tested devices** table in the README with:

- Model, CPU, screen, RAM / storage
- Firmware setup key (for disabling Secure Boot)
- Anything you had to do differently

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
